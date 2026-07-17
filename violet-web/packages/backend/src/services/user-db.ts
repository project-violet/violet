import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let db: Database.Database | null = null;

const SCHEMA = `
CREATE TABLE IF NOT EXISTS BookmarkGroup (
  Id          INTEGER PRIMARY KEY AUTOINCREMENT,
  Name        TEXT,
  DateTime    TEXT,
  Description TEXT,
  Color       INTEGER,
  Gorder      INTEGER
);

CREATE TABLE IF NOT EXISTS BookmarkArticle (
  Id       INTEGER PRIMARY KEY AUTOINCREMENT,
  Article  TEXT,
  DateTime TEXT,
  GroupId  INTEGER,
  FOREIGN KEY(GroupId) REFERENCES BookmarkGroup(Id)
);

CREATE TABLE IF NOT EXISTS BookmarkArtist (
  Id       INTEGER PRIMARY KEY AUTOINCREMENT,
  Artist   TEXT,
  IsGroup  INTEGER,
  DateTime TEXT,
  GroupId  INTEGER,
  FOREIGN KEY(GroupId) REFERENCES BookmarkGroup(Id)
);

CREATE TABLE IF NOT EXISTS ArticleReadLog (
  Id            INTEGER PRIMARY KEY AUTOINCREMENT,
  Article       TEXT,
  DateTimeStart TEXT,
  DateTimeEnd   TEXT,
  LastPage      INTEGER,
  Type          INTEGER
);

CREATE TABLE IF NOT EXISTS Download (
  Id              INTEGER PRIMARY KEY AUTOINCREMENT,
  Article         TEXT NOT NULL,
  Status          TEXT NOT NULL DEFAULT 'pending',
  TotalPages      INTEGER NOT NULL DEFAULT 0,
  DownloadedPages INTEGER NOT NULL DEFAULT 0,
  DateTime        TEXT NOT NULL,
  ErrorMessage    TEXT
);

CREATE TABLE IF NOT EXISTS BookmarkCropImage (
  Id          INTEGER PRIMARY KEY AUTOINCREMENT,
  Article     INTEGER NOT NULL,
  Page        INTEGER NOT NULL,
  Area        TEXT NOT NULL,
  AspectRatio REAL NOT NULL,
  DateTime    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS MessageSearchHistory (
  Query          TEXT PRIMARY KEY,
  SearchCount    INTEGER NOT NULL DEFAULT 1,
  LastSearchedAt TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS LlmSearchHistory (
  Query          TEXT PRIMARY KEY,
  TopK           INTEGER NOT NULL,
  CandidateK     INTEGER NOT NULL,
  SearchCount    INTEGER NOT NULL DEFAULT 1,
  LastSearchedAt TEXT NOT NULL
);
`;

const DEFAULT_GROUP_SQL = `
INSERT OR IGNORE INTO BookmarkGroup (Id, Name, DateTime, Description, Color, Gorder)
VALUES (1, 'violet_default', datetime('now'), 'Default bookmark group', NULL, 1);
`;

export function getUserDb(): Database.Database {
  if (db) return db;

  const dbPath =
    process.env.USER_DB_PATH || path.resolve(__dirname, '../../data/user.db');
  db = new Database(dbPath);
  db.pragma('journal_mode = WAL');

  // Create tables if not exist
  db.exec(SCHEMA);
  db.exec(DEFAULT_GROUP_SQL);

  return db;
}
