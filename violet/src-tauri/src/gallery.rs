use crate::db::Result;
use reqwest::blocking::Client;
use rquickjs::{Context, Runtime};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::Mutex,
    time::{Duration, Instant},
};

const GG_URL: &str = "https://ltn.gold-usergeneratedcontent.net/gg.js";
const MODEL_URL: &str = "https://raw.githubusercontent.com/project-violet/scripts/main/hitomi_get_image_list_v4_model.js";
const FALLBACK: &str =
    include_str!("../../../violet-web/packages/backend/scripts/hitomi_get_image_list_v3_model.js");

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Images {
    pub urls: Vec<String>,
    pub big_thumbnails: Vec<String>,
    pub small_thumbnails: Vec<String>,
}

#[derive(Default)]
pub struct GalleryCache {
    script: Option<(Instant, String)>,
    images: HashMap<u64, (Instant, Images)>,
}

// Remote resolver scripts run in a separate JS engine without filesystem,
// networking, DOM or Tauri bindings. Bound both execution time and memory.
pub fn evaluate(source: &str, expression: &str) -> Result<String> {
    let runtime = Runtime::new().map_err(|e| e.to_string())?;
    runtime.set_memory_limit(32 * 1024 * 1024);
    runtime.set_max_stack_size(512 * 1024);
    let deadline = Instant::now() + Duration::from_secs(2);
    runtime.set_interrupt_handler(Some(Box::new(move || Instant::now() > deadline)));
    let context = Context::full(&runtime).map_err(|e| e.to_string())?;
    context.with(|ctx| {
        ctx.eval::<(), _>("var document={title:''}; var window={innerWidth:1};")
            .map_err(|e| e.to_string())?;
        // Upstream browser scripts assign globals (gg/galleryinfo) without var.
        // QuickJS eval defaults to strict mode, unlike a browser script tag.
        let mut options = rquickjs::context::EvalOptions::default();
        options.strict = false;
        ctx.eval_with_options::<(), _>(source, options)
            .map_err(|e| {
                format!(
                    "Resolver script: {}",
                    rquickjs::CaughtError::from_error(&ctx, e)
                )
            })?;
        ctx.eval::<String, _>(expression).map_err(|e| {
            format!(
                "Resolver result: {}",
                rquickjs::CaughtError::from_error(&ctx, e)
            )
        })
    })
}

fn text(client: &Client, url: &str) -> Result<String> {
    client
        .get(url)
        .header("Referer", "https://hitomi.la/")
        .send()
        .and_then(|r| r.error_for_status())
        .and_then(|r| r.text())
        .map_err(|e| e.to_string())
}

pub fn resolve(client: &Client, cache_store: &Mutex<GalleryCache>, id: u64) -> Result<Images> {
    if id == 0 {
        return Err("Invalid gallery id".into());
    }
    let ttl = Duration::from_secs(1800);
    // Refresh the script once; release the lock before individual gallery I/O.
    let mut cache = cache_store.lock().map_err(|e| e.to_string())?;
    if let Some((at, images)) = cache.images.get(&id) {
        if at.elapsed() < ttl {
            return Ok(images.clone());
        }
    }
    if cache
        .script
        .as_ref()
        .is_none_or(|(at, _)| at.elapsed() >= ttl)
    {
        let gg = text(client, GG_URL)?;
        let values = evaluate(&gg.replace("'use strict';", ""),
            "JSON.stringify({m:Array.from({length:4096},(_,i)=>gg.m(i)).join(',')+',',b:gg.b,s:gg.s.toString()})")?;
        let values: serde_json::Value = serde_json::from_str(&values).map_err(|e| e.to_string())?;
        let model = text(client, MODEL_URL).unwrap_or_else(|_| FALLBACK.into());
        let script = model
            .replace("%%gg.m%", values["m"].as_str().unwrap_or_default())
            .replace("%%gg.b%", values["b"].as_str().unwrap_or_default())
            .replace("%%gg.s%", values["s"].as_str().unwrap_or_default());
        cache.script = Some((Instant::now(), script));
    }
    let script = cache.script.as_ref().unwrap().1.clone();
    drop(cache);
    let url = evaluate(&script, &format!("create_download_url('{id}')"))?;
    let info = text(client, &url)?;
    let source = format!("{script}\n{info}");
    let result = evaluate(&source, "hitomi_get_image_list()")?;
    #[derive(Deserialize)]
    struct Raw {
        result: Vec<String>,
        btresult: Vec<String>,
        stresult: Vec<String>,
    }
    let result: Raw = serde_json::from_str(&result).map_err(|e| e.to_string())?;
    let images = Images {
        urls: result.result,
        big_thumbnails: result.btresult,
        small_thumbnails: result.stresult,
    };
    let mut cache = cache_store.lock().map_err(|e| e.to_string())?;
    cache.images.retain(|_, (at, _)| at.elapsed() < ttl);
    if cache.images.len() >= 256 {
        cache.images.clear();
    }
    cache.images.insert(id, (Instant::now(), images.clone()));
    Ok(images)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    #[ignore = "requires network and VIOLET_TEST_GALLERY; fetches metadata only"]
    fn resolve_live_metadata() {
        let id = std::env::var("VIOLET_TEST_GALLERY")
            .unwrap()
            .parse()
            .unwrap();
        let client = Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .unwrap();
        let images = resolve(&client, &Mutex::new(GalleryCache::default()), id).unwrap();
        assert!(!images.urls.is_empty());
        assert!(!images.big_thumbnails.is_empty());
    }
    #[test]
    fn resolver_has_no_native_bindings_and_times_out() {
        assert_eq!(evaluate("gg = {b: 'test'};", "gg.b").unwrap(), "test");
        assert_eq!(
            evaluate(
                "",
                "typeof fetch + ',' + typeof process + ',' + typeof __TAURI_INTERNALS__"
            )
            .unwrap(),
            "undefined,undefined,undefined"
        );
        assert!(evaluate("while(true) {}", "''").is_err());
    }
}
