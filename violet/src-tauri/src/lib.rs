mod db;
mod gallery;
mod media;
mod sync;
#[cfg(target_os = "ios")]
mod ios;

use serde_json::{json, Value};
use std::{
    collections::HashSet,
    path::PathBuf,
    sync::{Arc, Mutex},
    time::Duration,
};
use tauri::Manager;

pub struct NativeState {
    root: PathBuf,
    client: reqwest::blocking::Client,
    sync: Mutex<Value>,
    content_lock: Mutex<()>,
    media_lock: Mutex<()>,
    tags: Mutex<Option<Vec<db::Tag>>>,
    galleries: Mutex<gallery::GalleryCache>,
    downloads: Mutex<HashSet<u64>>,
}

#[tauri::command]
async fn native_viewer_fullscreen(window: tauri::WebviewWindow, enabled: bool, dark: bool) -> db::Result<bool> {
    #[cfg(target_os = "ios")]
    {
        let (sender, receiver) = tokio::sync::oneshot::channel();
        window.with_webview(move |webview| {
            let _ = sender.send(ios::viewer_fullscreen(webview, enabled, dark));
        }).map_err(|e| e.to_string())?;
        receiver.await.map_err(|e| e.to_string())??;
        Ok(true)
    }
    #[cfg(not(target_os = "ios"))]
    {
        let _ = (window, enabled, dark);
        Ok(false)
    }
}

async fn blocking<T: Send + 'static>(
    f: impl FnOnce() -> db::Result<T> + Send + 'static,
) -> db::Result<T> {
    tauri::async_runtime::spawn_blocking(f)
        .await
        .map_err(|e| e.to_string())?
}

// The configured FSCM server is contacted natively so a WKWebView origin does
// not require browser CORS support from the user's search server.
#[tauri::command]
async fn native_message_request(
    state: tauri::State<'_, Arc<NativeState>>,
    url: String,
    body: Option<Value>,
    timeout_ms: u64,
) -> db::Result<Value> {
    let url = url::Url::parse(&url).map_err(|e| e.to_string())?;
    if !matches!(url.scheme(), "http" | "https") || url.host_str().is_none() {
        return Err("Invalid message search server URL".into());
    }
    let client = state.client.clone();
    blocking(move || {
        let request = if let Some(body) = body { client.post(url).json(&body) } else { client.get(url) };
        let response = request.timeout(Duration::from_millis(timeout_ms.clamp(1, 30_000)))
            .send().map_err(|e| e.to_string())?;
        let status = response.status().as_u16();
        // Legacy servers may return an HTML 404 for /mobile/status.
        let body = response.json::<Value>().map_err(|e| {
            format!("Message search server returned {status}: {e}")
        });
        if status == 404 { return Ok(json!({"status": status, "body": null})); }
        Ok(json!({"status": status, "body": body?}))
    }).await
}

#[tauri::command]
async fn native_query(
    state: tauri::State<'_, Arc<NativeState>>,
    database: String,
    sql: String,
    params: Vec<Value>,
) -> db::Result<Vec<Value>> {
    let state = state.inner().clone();
    blocking(move || match database.as_str() {
        "content" => {
            let _guard = state.content_lock.lock().map_err(|e| e.to_string())?;
            db::query(&db::content(&state.root)?, &sql, &params)
        }
        "user" => db::query(&db::open_user(&state.root)?, &sql, &params),
        _ => Err("Unknown database".into()),
    })
    .await
}

#[tauri::command]
async fn native_execute(
    state: tauri::State<'_, Arc<NativeState>>,
    statements: Vec<db::Statement>,
) -> db::Result<Value> {
    let state = state.inner().clone();
    blocking(move || db::execute(&state.root, statements)).await
}

#[tauri::command]
fn native_status(state: tauri::State<'_, Arc<NativeState>>) -> Value {
    sync::status(&state)
}

#[tauri::command]
fn native_sync(state: tauri::State<'_, Arc<NativeState>>) -> db::Result<()> {
    sync::begin(state.inner().clone(), None)
}

#[tauri::command]
fn native_import(state: tauri::State<'_, Arc<NativeState>>, path: String) -> db::Result<()> {
    sync::begin(state.inner().clone(), Some(path))
}

#[tauri::command]
async fn native_tags(
    state: tauri::State<'_, Arc<NativeState>>,
    condition: Option<String>,
    refresh: bool,
) -> db::Result<Vec<db::Tag>> {
    let state = state.inner().clone();
    blocking(move || {
        let _guard = state.content_lock.lock().map_err(|e| e.to_string())?;
        if let Some(condition) = condition {
            return db::tags(&state.root, &condition);
        }
        let mut cache = state.tags.lock().map_err(|e| e.to_string())?;
        if refresh || cache.is_none() {
            *cache = Some(db::tags(&state.root, "ExistOnHitomi=1")?);
        }
        Ok(cache.as_ref().unwrap().clone())
    })
    .await
}

#[tauri::command]
async fn native_gallery(
    state: tauri::State<'_, Arc<NativeState>>,
    id: u64,
) -> db::Result<gallery::Images> {
    let state = state.inner().clone();
    blocking(move || gallery::resolve(&state.client, &state.galleries, id)).await
}

#[tauri::command]
async fn native_download(
    state: tauri::State<'_, Arc<NativeState>>,
    article: u64,
) -> db::Result<Value> {
    let state = state.inner().clone();
    blocking(move || media::start_download(state, article)).await
}

#[tauri::command]
async fn native_delete_download(
    state: tauri::State<'_, Arc<NativeState>>,
    id: i64,
) -> db::Result<()> {
    let state = state.inner().clone();
    blocking(move || {
        let db = db::open_user(&state.root)?;
        let rows = db::query(&db, "SELECT Article FROM Download WHERE Id=?", &[json!(id)])?;
        if let Some(row) = rows.first() {
            let article: u64 = row["Article"]
                .as_str()
                .unwrap_or_default()
                .parse()
                .map_err(|_| "Invalid article")?;
            let active = state.downloads.lock().map_err(|e| e.to_string())?;
            if active.contains(&article) {
                return Err("Wait for the download to finish before deleting it".into());
            }
            let path = state.root.join("downloads").join(article.to_string());
            if path.exists() {
                std::fs::remove_dir_all(path).map_err(|e| e.to_string())?;
            }
            db.execute(
                "DELETE FROM Download WHERE Article=?",
                [article.to_string()],
            )
            .map_err(|e| e.to_string())?;
        }
        Ok(())
    })
    .await
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let root = app.path().app_data_dir()?;
            db::initialize(&root).map_err(std::io::Error::other)?;
            let mut status = std::fs::read_to_string(root.join("sync-state.json")).ok()
                .and_then(|s| serde_json::from_str::<Value>(&s).ok())
                .unwrap_or(json!({"lastSync": null, "lastSyncDb": null}));
            status["status"] = json!("idle");
            status["error"] = Value::Null;
            status["progress"] = Value::Null;
            let client = reqwest::blocking::Client::builder()
                .user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36")
                .connect_timeout(Duration::from_secs(30))
                .timeout(Duration::from_secs(1800)).build()?;
            app.manage(Arc::new(NativeState {
                root, client, sync: Mutex::new(status), content_lock: Mutex::new(()),
                media_lock: Mutex::new(()), tags: Mutex::new(None),
                galleries: Mutex::new(gallery::GalleryCache::default()), downloads: Mutex::new(HashSet::new()),
            }));
            Ok(())
        })
        .register_asynchronous_uri_scheme_protocol("violet-media", |context, request, responder| {
            let state = context.app_handle().state::<Arc<NativeState>>().inner().clone();
            tauri::async_runtime::spawn_blocking(move || {
                let response = match media::read(&state, &request.uri().to_string()) {
                    Ok((bytes, mime)) => tauri::http::Response::builder().status(200)
                        .header("Content-Type", mime).header("Access-Control-Allow-Origin", "*")
                        .header("Cache-Control", "private, max-age=86400").body(bytes).unwrap(),
                    Err(error) => tauri::http::Response::builder().status(502)
                        .header("Content-Type", "text/plain").header("Access-Control-Allow-Origin", "*")
                        .body(error.into_bytes()).unwrap(),
                };
                responder.respond(response);
            });
        })
        .invoke_handler(tauri::generate_handler![native_query, native_execute, native_status, native_sync, native_import, native_tags, native_gallery, native_download, native_delete_download, native_viewer_fullscreen, native_message_request])
        .run(tauri::generate_context!())
        .expect("Unable to start Violet");
}
