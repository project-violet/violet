import Database from 'better-sqlite3';

/**
 * Normalize pipe-delimited field for FTS5 token indexing.
 * |entry one||male:tag||dark skin| → entry_one male:tag dark_skin
 * Each pipe-delimited entry becomes a single FTS5 token
 * (with tokenchars ':_' in the FtsTags table).
 */
function normalizePipedField(value: string | null): string {
  if (!value) return '';
  return value
    .split('|')
    .filter((s) => s.length > 0)
    .map((s) => s.replace(/ /g, '_'))
    .join(' ');
}

/**
 * Build FTS5 full-text search indexes and B-tree indexes.
 * Must be called with a writable database connection.
 */
export function buildFtsIndex(db: Database.Database): void {
  const start = Date.now();
  console.log('[FTS] Building search indexes...');

  // B-tree indexes for exact-match columns
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_language ON HitomiColumnModel(Language);
    CREATE INDEX IF NOT EXISTS idx_type ON HitomiColumnModel(Type);
    CREATE INDEX IF NOT EXISTS idx_class ON HitomiColumnModel(Class);
    CREATE INDEX IF NOT EXISTS idx_uploader ON HitomiColumnModel(Uploader COLLATE NOCASE);
    CREATE INDEX IF NOT EXISTS idx_exist_id ON HitomiColumnModel(ExistOnHitomi, Id DESC)
  `);
  console.log('[FTS] B-tree indexes created');

  // Drop and recreate FTS tables
  db.exec('DROP TABLE IF EXISTS FtsTitle');
  db.exec('DROP TABLE IF EXISTS FtsTags');

  // Title: trigram tokenizer for true substring matching (like LIKE '%term%')
  db.exec(`CREATE VIRTUAL TABLE FtsTitle USING fts5(Title, content='', tokenize='trigram')`);

  // Tags: unicode61 with colon/underscore as token characters.
  // Each pipe-delimited entry (e.g. male:shotacon, dark_skin) becomes one token.
  db.exec(`
    CREATE VIRTUAL TABLE FtsTags USING fts5(
      Tags, Artists, Groups_, Series, Characters,
      content='',
      tokenize="unicode61 tokenchars ':_'"
    )
  `);

  // Populate FtsTitle directly from SQL
  db.exec(`
    INSERT INTO FtsTitle(rowid, Title)
    SELECT Id, COALESCE(Title, '') FROM HitomiColumnModel WHERE ExistOnHitomi = 1
  `);
  console.log(`[FTS] FtsTitle built in ${((Date.now() - start) / 1000).toFixed(1)}s`);

  // Populate FtsTags using custom function for pipe normalization
  const startTags = Date.now();
  db.function('_normalize_piped', (val: unknown) =>
    normalizePipedField(val as string | null),
  );

  db.exec(`
    INSERT INTO FtsTags(rowid, Tags, Artists, Groups_, Series, Characters)
    SELECT Id,
      _normalize_piped(Tags),
      _normalize_piped(Artists),
      _normalize_piped([Groups]),
      _normalize_piped(Series),
      _normalize_piped(Characters)
    FROM HitomiColumnModel WHERE ExistOnHitomi = 1
  `);

  const elapsed = ((Date.now() - start) / 1000).toFixed(1);
  console.log(`[FTS] FtsTags built in ${((Date.now() - startTags) / 1000).toFixed(1)}s`);
  console.log(`[FTS] Search indexes built in ${elapsed}s`);
}
