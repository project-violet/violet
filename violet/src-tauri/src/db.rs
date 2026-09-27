use rusqlite::{params_from_iter, types::Value as SqlValue, Connection, OpenFlags};
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};
use std::{path::Path, time::Duration};

pub type Result<T> = std::result::Result<T, String>;

#[derive(Deserialize)]
pub struct Statement {
    pub sql: String,
    #[serde(default)]
    pub params: Vec<Value>,
}

pub fn open_user(root: &Path) -> Result<Connection> {
    let db = Connection::open(root.join("user.db")).map_err(|e| e.to_string())?;
    db.busy_timeout(Duration::from_secs(10))
        .map_err(|e| e.to_string())?;
    Ok(db)
}

pub fn initialize(root: &Path) -> Result<()> {
    std::fs::create_dir_all(root).map_err(|e| e.to_string())?;
    let db = open_user(root)?;
    db.execute_batch("PRAGMA journal_mode=WAL;")
        .map_err(|e| e.to_string())?;
    db.execute_batch(include_str!("user-schema.sql"))
        .map_err(|e| e.to_string())?;
    db.execute("UPDATE Download SET Status='failed', ErrorMessage='Download interrupted; retry to resume' WHERE Status IN ('pending', 'downloading')", [])
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub fn content(root: &Path) -> Result<Connection> {
    let db = Connection::open_with_flags(root.join("data.db"), OpenFlags::SQLITE_OPEN_READ_ONLY)
        .map_err(|e| format!("Content database is not ready: {e}"))?;
    db.busy_timeout(Duration::from_secs(10))
        .map_err(|e| e.to_string())?;
    Ok(db)
}

fn parameters(values: &[Value]) -> Result<Vec<SqlValue>> {
    values
        .iter()
        .map(|v| match v {
            Value::Null => Ok(SqlValue::Null),
            Value::Bool(b) => Ok(SqlValue::Integer(i64::from(*b))),
            Value::Number(n) => n
                .as_i64()
                .map(SqlValue::Integer)
                .or_else(|| n.as_f64().map(SqlValue::Real))
                .ok_or_else(|| "Invalid number".into()),
            Value::String(s) => Ok(SqlValue::Text(s.clone())),
            _ => Err("SQL parameters must be scalar values".into()),
        })
        .collect()
}

pub fn query(db: &Connection, sql: &str, params: &[Value]) -> Result<Vec<Value>> {
    let first = sql.split_whitespace().next().unwrap_or("").to_uppercase();
    if !matches!(first.as_str(), "SELECT" | "WITH" | "EXPLAIN") {
        return Err("Only read queries are permitted".into());
    }
    let mut stmt = db.prepare(sql).map_err(|e| e.to_string())?;
    if !stmt.readonly() {
        return Err("Only read queries are permitted".into());
    }
    let names: Vec<String> = stmt.column_names().iter().map(|s| s.to_string()).collect();
    let params = parameters(params)?;
    let rows = stmt
        .query_map(params_from_iter(params), |row| {
            let mut object = Map::new();
            for (i, name) in names.iter().enumerate() {
                let value: SqlValue = row.get(i)?;
                object.insert(
                    name.clone(),
                    match value {
                        SqlValue::Null => Value::Null,
                        SqlValue::Integer(n) => json!(n),
                        SqlValue::Real(n) => json!(n),
                        SqlValue::Text(s) => json!(s),
                        SqlValue::Blob(_) => Value::Null,
                    },
                );
            }
            Ok(Value::Object(object))
        })
        .map_err(|e| e.to_string())?;
    // Bound data transferred across IPC. Content lists are paginated in the adapter.
    let mut result = Vec::new();
    for row in rows {
        if result.len() >= 50_000 {
            return Err("Query result exceeds 50,000 rows".into());
        }
        result.push(row.map_err(|e| e.to_string())?);
    }
    Ok(result)
}

pub fn execute(root: &Path, statements: Vec<Statement>) -> Result<Value> {
    let mut db = open_user(root)?;
    let transaction = db.transaction().map_err(|e| e.to_string())?;
    let mut changes = 0;
    for statement in statements {
        let first = statement
            .sql
            .split_whitespace()
            .next()
            .unwrap_or("")
            .to_uppercase();
        if !matches!(first.as_str(), "INSERT" | "UPDATE" | "DELETE") {
            return Err("Only user-data mutations are permitted".into());
        }
        changes += transaction
            .execute(
                &statement.sql,
                params_from_iter(parameters(&statement.params)?),
            )
            .map_err(|e| e.to_string())?;
    }
    let id = transaction.last_insert_rowid();
    transaction.commit().map_err(|e| e.to_string())?;
    Ok(json!({"Id": id, "changes": changes, "ok": true}))
}

pub fn validate_content(path: &Path) -> Result<()> {
    let db = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY)
        .map_err(|e| e.to_string())?;
    db.prepare("SELECT Id, Title, Artists, Tags, Groups, Series, Characters, Language, Type, Files, Published, ExistOnHitomi, Uploader, Class FROM HitomiColumnModel LIMIT 0")
        .map_err(|e| format!("Not a Violet content database: {e}"))?;
    let check: String = db
        .query_row("PRAGMA quick_check", [], |row| row.get(0))
        .map_err(|e| e.to_string())?;
    if check != "ok" {
        return Err(format!("Database integrity check failed: {check}"));
    }
    Ok(())
}

pub fn build_search_indexes(path: &Path) -> Result<()> {
    use rusqlite::functions::FunctionFlags;
    let mut db = Connection::open(path).map_err(|e| e.to_string())?;
    db.create_scalar_function(
        "_normalize_piped",
        1,
        FunctionFlags::SQLITE_UTF8 | FunctionFlags::SQLITE_DETERMINISTIC,
        |ctx| {
            let raw: Option<String> = ctx.get(0)?;
            Ok(raw
                .unwrap_or_default()
                .split('|')
                .filter(|s| !s.is_empty())
                .map(|s| s.replace(' ', "_"))
                .collect::<Vec<_>>()
                .join(" "))
        },
    )
    .map_err(|e| e.to_string())?;
    let transaction = db.transaction().map_err(|e| e.to_string())?;
    // The indexes and tokenization match the shared TS query translator.
    transaction.execute_batch("
        CREATE INDEX IF NOT EXISTS idx_language_exist_id ON HitomiColumnModel(Language,ExistOnHitomi,Id DESC);
        CREATE INDEX IF NOT EXISTS idx_exist_id ON HitomiColumnModel(ExistOnHitomi,Id DESC);
        DROP TABLE IF EXISTS FtsTitle;
        DROP TABLE IF EXISTS FtsTags;
        CREATE VIRTUAL TABLE FtsTitle USING fts5(Title,content='',tokenize='trigram');
        CREATE VIRTUAL TABLE FtsTags USING fts5(Tags,Artists,Groups_,Series,Characters,content='',tokenize=\"unicode61 tokenchars ':_'\");
        INSERT INTO FtsTitle(rowid,Title) SELECT Id,COALESCE(Title,'') FROM HitomiColumnModel WHERE ExistOnHitomi=1;
        INSERT INTO FtsTags(rowid,Tags,Artists,Groups_,Series,Characters)
            SELECT Id,_normalize_piped(Tags),_normalize_piped(Artists),_normalize_piped(Groups),_normalize_piped(Series),_normalize_piped(Characters)
            FROM HitomiColumnModel WHERE ExistOnHitomi=1;
    ").map_err(|e| e.to_string())?;
    transaction.commit().map_err(|e| e.to_string())?;
    Ok(())
}

#[derive(Clone, Serialize)]
pub struct Tag {
    pub category: String,
    pub tag: String,
    pub display: String,
    pub count: u64,
}

pub fn tags(root: &Path, condition: &str) -> Result<Vec<Tag>> {
    let db = content(root)?;
    let mut stmt = db.prepare(&format!("SELECT Artists, Groups, Series, Characters, Tags, Language, Type, Uploader, Class FROM HitomiColumnModel WHERE {condition}"))
        .map_err(|e| e.to_string())?;
    if !stmt.readonly() {
        return Err("Invalid tag query".into());
    }
    let mut rows = stmt.query([]).map_err(|e| e.to_string())?;
    let categories = [
        "artist",
        "group",
        "series",
        "character",
        "tag",
        "lang",
        "type",
        "uploader",
        "class",
    ];
    let mut counts = std::collections::HashMap::<(String, String), u64>::new();
    while let Some(row) = rows.next().map_err(|e| e.to_string())? {
        for (index, category) in categories.iter().enumerate() {
            let raw: Option<String> = row.get(index).map_err(|e| e.to_string())?;
            if let Some(raw) = raw {
                for tag in raw.split('|').map(str::trim).filter(|s| !s.is_empty()) {
                    let (category, tag) = if index == 4 {
                        match tag.split_once(':') {
                            Some((ns @ ("male" | "female"), t)) => (ns, t),
                            Some((_, t)) => ("tag", t),
                            None => ("tag", tag),
                        }
                    } else {
                        (*category, tag)
                    };
                    *counts.entry((category.into(), tag.into())).or_default() += 1;
                }
            }
        }
    }
    let mut tags: Vec<Tag> = counts
        .into_iter()
        .map(|((category, tag), count)| Tag {
            display: format!("{}:{}", category, tag.replace(' ', "_")),
            category,
            tag,
            count,
        })
        .collect();
    tags.sort_by(|a, b| b.count.cmp(&a.count).then(a.display.cmp(&b.display)));
    Ok(tags)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn bundled_sqlite_supports_shared_fts_tokenization() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("data.db");
        let database = Connection::open(&path).unwrap();
        database.execute_batch("CREATE TABLE HitomiColumnModel(Id INTEGER,Title TEXT,Tags TEXT,Artists TEXT,Groups TEXT,Series TEXT,Characters TEXT,Language TEXT,ExistOnHitomi INTEGER);
            INSERT INTO HitomiColumnModel VALUES(1,'Violet landscape','|full color|','|alice|',NULL,NULL,NULL,'korean',1);").unwrap();
        drop(database);
        build_search_indexes(&path).unwrap();
        let database = content(dir.path()).unwrap();
        assert_eq!(
            query(
                &database,
                "SELECT rowid FROM FtsTitle WHERE FtsTitle MATCH '\"land\"'",
                &[]
            )
            .unwrap()
            .len(),
            1
        );
        assert_eq!(
            query(
                &database,
                "SELECT rowid FROM FtsTags WHERE Tags MATCH '\"full_color\"'",
                &[]
            )
            .unwrap()
            .len(),
            1
        );
    }
    #[test]
    fn user_data_persists_and_failed_batches_roll_back() {
        let dir = tempfile::tempdir().unwrap();
        initialize(dir.path()).unwrap();
        execute(
            dir.path(),
            vec![Statement {
                sql: "INSERT INTO BookmarkArticle (Article, GroupId) VALUES (?, 1)".into(),
                params: vec![json!("123")],
            }],
        )
        .unwrap();
        let result = execute(
            dir.path(),
            vec![
                Statement {
                    sql: "DELETE FROM BookmarkArticle".into(),
                    params: vec![],
                },
                Statement {
                    sql: "INSERT INTO Missing VALUES (1)".into(),
                    params: vec![],
                },
            ],
        );
        assert!(result.is_err());
        let db = open_user(dir.path()).unwrap();
        assert_eq!(
            query(&db, "SELECT Article FROM BookmarkArticle", &[]).unwrap()[0]["Article"],
            "123"
        );
        assert!(query(&db, "DELETE FROM BookmarkArticle RETURNING *", &[]).is_err());
        assert!(execute(
            dir.path(),
            vec![Statement {
                sql: "ATTACH DATABASE '/tmp/test.db' AS other".into(),
                params: vec![]
            }]
        )
        .is_err());
    }
}
