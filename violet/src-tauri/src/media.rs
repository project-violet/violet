use crate::{db, gallery, NativeState};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{fs, io::Read, path::Path, sync::Arc};

fn image_type(bytes: &[u8]) -> &'static str {
    if bytes.starts_with(b"\x89PNG") {
        "image/png"
    } else if bytes.starts_with(b"GIF8") {
        "image/gif"
    } else if bytes.starts_with(b"RIFF") {
        "image/webp"
    } else if bytes.get(4..8) == Some(b"ftyp") {
        "image/avif"
    } else {
        "image/jpeg"
    }
}

pub fn fetch_image(state: &NativeState, url: &str, referer: Option<&str>) -> db::Result<Vec<u8>> {
    let parsed = url::Url::parse(url).map_err(|e| e.to_string())?;
    if !matches!(parsed.scheme(), "https" | "http") {
        return Err("Unsupported image URL".into());
    }
    let response = state
        .client
        .get(url)
        .header("Referer", referer.unwrap_or("https://hitomi.la/"))
        .send()
        .and_then(|r| r.error_for_status())
        .map_err(|e| e.to_string())?;
    let mut bytes = Vec::new();
    response
        .take(64 * 1024 * 1024 + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| e.to_string())?;
    if bytes.len() > 64 * 1024 * 1024 {
        return Err("Image exceeds 64 MB".into());
    }
    Ok(bytes)
}

pub fn read(state: &NativeState, uri: &str) -> db::Result<(Vec<u8>, &'static str)> {
    let url = url::Url::parse(uri).map_err(|e| e.to_string())?;
    let params: std::collections::HashMap<_, _> = url.query_pairs().into_owned().collect();
    let bytes = if let (Some(article), Some(page)) = (params.get("article"), params.get("page")) {
        let article: u64 = article.parse().map_err(|_| "Invalid article")?;
        let page: u32 = page.parse().map_err(|_| "Invalid page")?;
        fs::read(
            state
                .root
                .join("downloads")
                .join(article.to_string())
                .join(format!("{page}.image")),
        )
        .map_err(|e| e.to_string())?
    } else {
        let remote = params.get("url").ok_or("Image URL is required")?;
        let referer = params.get("referer").map(String::as_str);
        let key = format!(
            "{:x}",
            Sha256::digest(format!("{remote}\n{}", referer.unwrap_or_default()).as_bytes())
        );
        let directory = state.root.join("image-cache");
        let file = directory.join(key);
        if let Ok(bytes) = fs::read(&file) {
            bytes
        } else {
            let bytes = fetch_image(state, remote, referer)?;
            fs::create_dir_all(&directory).map_err(|e| e.to_string())?;
            // Cache maintenance and writes are serialized; requests remain parallel.
            let _guard = state.media_lock.lock().map_err(|e| e.to_string())?;
            prune_cache(&directory, 512 * 1024 * 1024 - bytes.len() as u64);
            fs::write(&file, &bytes).map_err(|e| e.to_string())?;
            bytes
        }
    };
    let mime = image_type(&bytes);
    Ok((bytes, mime))
}

fn prune_cache(directory: &Path, budget: u64) {
    let mut files: Vec<_> = fs::read_dir(directory)
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|entry| {
            let meta = entry.metadata().ok()?;
            Some((entry.path(), meta.len(), meta.modified().ok()?))
        })
        .collect();
    let mut size: u64 = files.iter().map(|f| f.1).sum();
    files.sort_by_key(|f| f.2);
    for (path, length, _) in files {
        if size <= budget {
            break;
        }
        if fs::remove_file(path).is_ok() {
            size = size.saturating_sub(length);
        }
    }
}

pub fn start_download(state: Arc<NativeState>, article: u64) -> db::Result<Value> {
    if article == 0 {
        return Err("Invalid article id".into());
    }
    let mut active = state.downloads.lock().map_err(|e| e.to_string())?;
    if !active.insert(article) {
        return Err("Already downloading".into());
    }
    let result = (|| {
        let db = db::open_user(&state.root)?;
        let old = db::query(
            &db,
            "SELECT * FROM Download WHERE Article=? ORDER BY Id DESC LIMIT 1",
            &[json!(article.to_string())],
        )?;
        let id = if let Some(row) = old.first() {
            let id = row["Id"].as_i64().ok_or("Invalid download id")?;
            db.execute(
                "UPDATE Download SET Status='downloading', ErrorMessage=NULL WHERE Id=?",
                [id],
            )
            .map_err(|e| e.to_string())?;
            id
        } else {
            db.execute(
                "INSERT INTO Download (Article, Status, DateTime) VALUES (?, 'downloading', ?)",
                [article.to_string(), chrono::Utc::now().to_rfc3339()],
            )
            .map_err(|e| e.to_string())?;
            db.last_insert_rowid()
        };
        let row = db::query(&db, "SELECT * FROM Download WHERE Id=?", &[json!(id)])?.remove(0);
        Ok((id, row))
    })();
    let (id, row) = match result {
        Ok(v) => v,
        Err(e) => {
            active.remove(&article);
            return Err(e);
        }
    };
    drop(active);
    tauri::async_runtime::spawn_blocking(move || {
        let result = download(&state, article, id);
        if let Ok(db) = db::open_user(&state.root) {
            match result {
                Ok(()) => {
                    let _ = db.execute(
                        "UPDATE Download SET Status='completed', ErrorMessage=NULL WHERE Id=?",
                        [id],
                    );
                }
                Err(error) => {
                    let _ = db.execute(
                        "UPDATE Download SET Status='failed', ErrorMessage=? WHERE Id=?",
                        rusqlite::params![error, id],
                    );
                }
            }
        }
        state.downloads.lock().unwrap().remove(&article);
    });
    Ok(row)
}

fn download(state: &NativeState, article: u64, id: i64) -> db::Result<()> {
    let images = gallery::resolve(&state.client, &state.galleries, article)?;
    let root = state.root.join("downloads").join(article.to_string());
    fs::create_dir_all(&root).map_err(|e| e.to_string())?;
    let db = db::open_user(&state.root)?;
    db.execute(
        "UPDATE Download SET TotalPages=?, DownloadedPages=0 WHERE Id=?",
        rusqlite::params![images.urls.len(), id],
    )
    .map_err(|e| e.to_string())?;
    for (index, url) in images.urls.iter().enumerate() {
        let file = root.join(format!("{index}.image"));
        if !file.exists() {
            let bytes = fetch_image(state, url, None)?;
            let temp = root.join(format!("{index}.incoming"));
            fs::write(&temp, bytes).map_err(|e| e.to_string())?;
            fs::rename(temp, file).map_err(|e| e.to_string())?;
        }
        db.execute(
            "UPDATE Download SET DownloadedPages=? WHERE Id=?",
            rusqlite::params![index + 1, id],
        )
        .map_err(|e| e.to_string())?;
    }
    Ok(())
}
