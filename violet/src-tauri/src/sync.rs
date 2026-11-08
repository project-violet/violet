use crate::{db, NativeState};
use serde_json::{json, Value};
use std::{
    fs,
    io::{Read, Write},
    sync::Arc,
};

// Public snapshot supplied by the maintainer. Update this file ID for a new snapshot.
const DATABASE_ARCHIVE: &str = "https://drive.usercontent.google.com/download?id=1r5edntKy2qStwsGQuKAZ82_paEksPodt&export=download&confirm=t";

pub fn status(state: &NativeState) -> Value {
    let mut status = state.sync.lock().unwrap().clone();
    status["dbExists"] = json!(state.root.join("data.db").exists());
    status
}

pub fn begin(state: Arc<NativeState>, import: Option<String>) -> db::Result<()> {
    {
        let mut status = state.sync.lock().map_err(|e| e.to_string())?;
        if matches!(
            status["status"].as_str(),
            Some("checking" | "downloading_full" | "building_cache")
        ) {
            return Err("Database update already in progress".into());
        }
        status["status"] = json!("checking");
        status["error"] = Value::Null;
        status["stage"] = Value::Null;
    }
    tauri::async_runtime::spawn_blocking(move || {
        let result = replace(&state, import.as_deref());
        let _ = fs::remove_file(state.root.join("data.zip.incoming"));
        let mut status = state.sync.lock().unwrap();
        status["progress"] = Value::Null;
        status["stage"] = Value::Null;
        match result {
            Ok(()) => {
                let now = chrono::Utc::now().to_rfc3339();
                status["status"] = json!("idle");
                status["lastSync"] = json!(now);
                status["lastSyncDb"] = json!(now);
                status["error"] = Value::Null;
                if let Err(error) =
                    fs::write(state.root.join("sync-state.json"), status.to_string())
                {
                    status["error"] = json!(format!(
                        "Database updated, but status could not be saved: {error}"
                    ));
                }
            }
            Err(error) => {
                status["status"] = json!("error");
                status["error"] = json!(error);
                let _ = fs::remove_file(state.root.join("data.db.incoming"));
            }
        }
    });
    Ok(())
}

fn extract_database(archive: &std::path::Path, destination: &std::path::Path) -> db::Result<()> {
    let file = fs::File::open(archive).map_err(|e| e.to_string())?;
    let mut zip = zip::ZipArchive::new(file).map_err(|e| {
        format!(
            "Not a database ZIP archive. If Drive is unavailable, import a downloaded file: {e}"
        )
    })?;
    // Select one data.db; never extract arbitrary archive paths.
    let candidates: Vec<usize> = (0..zip.len())
        .filter(|&index| {
            zip.by_index(index).is_ok_and(|entry| {
                !entry.is_dir()
                    && entry
                        .enclosed_name()
                        .and_then(|p| p.file_name().map(|s| s == "data.db"))
                        .unwrap_or(false)
            })
        })
        .collect();
    if candidates.len() != 1 {
        return Err("ZIP must contain exactly one data.db".into());
    }
    let mut entry = zip.by_index(candidates[0]).map_err(|e| e.to_string())?;
    if entry.size() > 10 * 1024 * 1024 * 1024 {
        return Err("Database exceeds the 10 GB import limit".into());
    }
    let mut output = fs::File::create(destination).map_err(|e| e.to_string())?;
    std::io::copy(&mut entry, &mut output).map_err(|e| e.to_string())?;
    output.sync_all().map_err(|e| e.to_string())?;
    Ok(())
}

fn replace(state: &NativeState, import: Option<&str>) -> db::Result<()> {
    let incoming = state.root.join("data.db.incoming");
    if let Some(source) = import {
        let path = std::path::Path::new(source);
        if path
            .extension()
            .is_some_and(|e| e.eq_ignore_ascii_case("zip"))
        {
            state.sync.lock().unwrap()["status"] = json!("building_cache");
            state.sync.lock().unwrap()["stage"] = json!("extracting");
            extract_database(path, &incoming)?;
        } else {
            db::validate_content(path)?;
            // VACUUM INTO includes committed WAL content without changing the original.
            let source = rusqlite::Connection::open_with_flags(
                source,
                rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY,
            )
            .map_err(|e| e.to_string())?;
            let _ = fs::remove_file(&incoming);
            source
                .execute("VACUUM INTO ?", [incoming.to_string_lossy().as_ref()])
                .map_err(|e| e.to_string())?;
        }
    } else {
        let archive = state.root.join("data.zip.incoming");
        let mut response = state
            .client
            .get(DATABASE_ARCHIVE)
            .send()
            .and_then(|r| r.error_for_status())
            .map_err(|e| e.to_string())?;
        if response
            .headers()
            .get(reqwest::header::CONTENT_TYPE)
            .and_then(|h| h.to_str().ok())
            .is_some_and(|s| s.contains("text/html"))
        {
            return Err("Google Drive did not return the database. Download article-db.zip in your browser and import it.".into());
        }
        let total = response.content_length().unwrap_or(0);
        let mut file = fs::File::create(&archive).map_err(|e| e.to_string())?;
        let mut buffer = vec![0; 256 * 1024];
        let mut received = 0u64;
        loop {
            let count = response.read(&mut buffer).map_err(|e| e.to_string())?;
            if count == 0 {
                break;
            }
            file.write_all(&buffer[..count])
                .map_err(|e| e.to_string())?;
            received += count as u64;
            let mut status = state.sync.lock().unwrap();
            status["status"] = json!("downloading_full");
            status["progress"] = json!({"current": received, "total": total.max(received), "message": format!("{:.1} / {:.1} MB", received as f64 / 1e6, total as f64 / 1e6)});
        }
        file.sync_all().map_err(|e| e.to_string())?;
        drop(file);
        if total > 0 && received != total {
            return Err("Incomplete database download".into());
        }
        state.sync.lock().unwrap()["status"] = json!("building_cache");
        state.sync.lock().unwrap()["progress"] = Value::Null;
        state.sync.lock().unwrap()["stage"] = json!("extracting");
        extract_database(&archive, &incoming)?;
        fs::remove_file(archive).map_err(|e| e.to_string())?;
    }
    state.sync.lock().unwrap()["status"] = json!("building_cache");
    state.sync.lock().unwrap()["stage"] = json!("validating");
    db::validate_content(&incoming)?;
    state.sync.lock().unwrap()["stage"] = json!("indexing");
    db::build_search_indexes(&incoming)?;
    // Short lock only for file replacement. Existing queries finish first.
    let _guard = state.content_lock.lock().map_err(|e| e.to_string())?;
    let destination = state.root.join("data.db");
    let previous = state.root.join("data.db.previous");
    if previous.exists() {
        fs::remove_file(&previous).map_err(|e| e.to_string())?;
    }
    if destination.exists() {
        fs::rename(&destination, &previous).map_err(|e| e.to_string())?;
    }
    if let Err(error) = fs::rename(&incoming, &destination) {
        if previous.exists() {
            let _ = fs::rename(&previous, &destination);
        }
        return Err(error.to_string());
    }
    *state.tags.lock().unwrap() = None;
    let _ = fs::remove_file(previous);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;
    fn state(root: &std::path::Path) -> NativeState {
        db::initialize(root).unwrap();
        NativeState {
            root: root.to_owned(),
            client: reqwest::blocking::Client::new(),
            sync: Mutex::new(json!({})),
            content_lock: Mutex::new(()),
            media_lock: Mutex::new(()),
            tags: Mutex::new(None),
            galleries: Mutex::new(crate::gallery::GalleryCache::default()),
            downloads: Mutex::new(Default::default()),
        }
    }
    #[test]
    fn imports_wal_snapshot_and_zip_without_touching_original_or_user_data() {
        let temp = tempfile::tempdir().unwrap();
        let source = temp.path().join("source.db");
        let conn = rusqlite::Connection::open(&source).unwrap();
        conn.execute_batch("PRAGMA journal_mode=WAL;
            CREATE TABLE HitomiColumnModel(Id INTEGER PRIMARY KEY,Title TEXT,Artists TEXT,Tags TEXT,Groups TEXT,Series TEXT,Characters TEXT,Language TEXT,Type TEXT,Files INTEGER,Published TEXT,ExistOnHitomi INTEGER,Uploader TEXT,Class TEXT);
            INSERT INTO HitomiColumnModel(Id,Title,Artists,Language,ExistOnHitomi) VALUES(1,'Violet landscape','|alice|','korean',1);").unwrap();
        let state = state(&temp.path().join("app"));
        db::open_user(&state.root)
            .unwrap()
            .execute(
                "INSERT INTO BookmarkArticle(Article,GroupId) VALUES('1',1)",
                [],
            )
            .unwrap();
        replace(&state, source.to_str()).unwrap();
        assert_eq!(
            db::query(
                &db::content(&state.root).unwrap(),
                "SELECT rowid FROM FtsTitle WHERE FtsTitle MATCH 'land'",
                &[]
            )
            .unwrap()
            .len(),
            1
        );
        let indexed: i64 = conn
            .query_row(
                "SELECT count(*) FROM sqlite_master WHERE name='FtsTitle'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(indexed, 0);
        drop(conn);
        let archive = temp.path().join("article.zip");
        let mut zip = zip::ZipWriter::new(fs::File::create(&archive).unwrap());
        zip.start_file("nested/data.db", zip::write::SimpleFileOptions::default())
            .unwrap();
        zip.write_all(&fs::read(&source).unwrap()).unwrap();
        zip.finish().unwrap();
        replace(&state, archive.to_str()).unwrap();
        let invalid = temp.path().join("invalid.db");
        fs::write(&invalid, b"not a database").unwrap();
        assert!(replace(&state, invalid.to_str()).is_err());
        assert_eq!(
            db::query(
                &db::content(&state.root).unwrap(),
                "SELECT Id FROM HitomiColumnModel",
                &[]
            )
            .unwrap()
            .len(),
            1
        );
        assert_eq!(
            db::query(
                &db::open_user(&state.root).unwrap(),
                "SELECT Article FROM BookmarkArticle",
                &[]
            )
            .unwrap()[0]["Article"],
            "1"
        );
    }
    #[test]
    fn zip_rejects_traversal_and_ambiguous_databases() {
        let temp = tempfile::tempdir().unwrap();
        for names in [vec!["../data.db"], vec!["a/data.db", "b/data.db"]] {
            let archive = temp.path().join("bad.zip");
            let mut zip = zip::ZipWriter::new(fs::File::create(&archive).unwrap());
            for name in names {
                zip.start_file(name, zip::write::SimpleFileOptions::default())
                    .unwrap();
                zip.write_all(b"bad").unwrap();
            }
            zip.finish().unwrap();
            assert!(extract_database(&archive, &temp.path().join("incoming")).is_err());
        }
    }
    #[test]
    #[ignore = "requires a downloaded content archive; uses a temporary app directory"]
    fn import_real_archive() {
        let source = std::env::var("VIOLET_TEST_ARCHIVE").expect("VIOLET_TEST_ARCHIVE");
        let temp = tempfile::tempdir().unwrap();
        let state = state(temp.path());
        replace(&state, Some(&source)).unwrap();
        let rows = db::query(
            &db::content(&state.root).unwrap(),
            "SELECT COUNT(*) AS count FROM HitomiColumnModel",
            &[],
        )
        .unwrap();
        assert!(rows[0]["count"].as_i64().unwrap() > 0);
        eprintln!("Imported content rows: {}", rows[0]["count"]);
    }
}
