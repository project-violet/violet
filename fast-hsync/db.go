package main

import (
	"database/sql"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

func openDB(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	db.SetConnMaxLifetime(0)

	// Keep a single connection hot so connection-level pragmas stay applied.
	db.Exec("PRAGMA journal_mode=WAL")
	db.Exec("PRAGMA synchronous=NORMAL")
	db.Exec("PRAGMA busy_timeout=5000")
	db.Exec("PRAGMA cache_size=-20000")
	db.Exec("PRAGMA mmap_size=1073741824")
	return db, nil
}

func createTable(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS HitomiColumnModel (
			Id INTEGER PRIMARY KEY,
			Title TEXT,
			EHash TEXT,
			Type TEXT,
			Artists TEXT,
			Characters TEXT,
			"Groups" TEXT,
			Language TEXT,
			Series TEXT,
			Tags TEXT,
			Uploader TEXT,
			Published DATETIME,
			Files INTEGER DEFAULT 0,
			Class TEXT,
			ExistOnHitomi INTEGER DEFAULT 0,
			Thumbnail TEXT
		)
	`)
	return err
}

func ensureBTreeIndexes(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_language ON HitomiColumnModel(Language);
		CREATE INDEX IF NOT EXISTS idx_type ON HitomiColumnModel(Type);
		CREATE INDEX IF NOT EXISTS idx_class ON HitomiColumnModel(Class);
		CREATE INDEX IF NOT EXISTS idx_uploader ON HitomiColumnModel(Uploader COLLATE NOCASE);
		CREATE INDEX IF NOT EXISTS idx_exist_id ON HitomiColumnModel(ExistOnHitomi, Id DESC);
	`)
	return err
}

func isFtsReady(db *sql.DB) (bool, error) {
	var count int
	err := db.QueryRow(`
		SELECT COUNT(*)
		FROM sqlite_master
		WHERE type='table' AND name IN ('FtsTitle', 'FtsTags')
	`).Scan(&count)
	return count == 2, err
}

func rebuildFts(db *sql.DB) error {
	start := time.Now()

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`DROP TABLE IF EXISTS FtsTitle`); err != nil {
		return err
	}
	if _, err := tx.Exec(`DROP TABLE IF EXISTS FtsTags`); err != nil {
		return err
	}

	if _, err := tx.Exec(`CREATE VIRTUAL TABLE FtsTitle USING fts5(Title, tokenize='trigram')`); err != nil {
		return err
	}
	if _, err := tx.Exec(`
		CREATE VIRTUAL TABLE FtsTags USING fts5(
			Tags, Artists, Groups_, Series, Characters,
			tokenize="unicode61 tokenchars ':_'"
		)
	`); err != nil {
		return err
	}

	if _, err := tx.Exec(`
		INSERT INTO FtsTitle(rowid, Title)
		SELECT Id, COALESCE(Title, '')
		FROM HitomiColumnModel
		WHERE ExistOnHitomi = 1
	`); err != nil {
		return err
	}

	if _, err := tx.Exec(`
		INSERT INTO FtsTags(rowid, Tags, Artists, Groups_, Series, Characters)
		SELECT
			Id,
			TRIM(REPLACE(REPLACE(COALESCE(Tags, ''), ' ', '_'), '|', ' ')),
			TRIM(REPLACE(REPLACE(COALESCE(Artists, ''), ' ', '_'), '|', ' ')),
			TRIM(REPLACE(REPLACE(COALESCE("Groups", ''), ' ', '_'), '|', ' ')),
			TRIM(REPLACE(REPLACE(COALESCE(Series, ''), ' ', '_'), '|', ' ')),
			TRIM(REPLACE(REPLACE(COALESCE(Characters, ''), ' ', '_'), '|', ' '))
		FROM HitomiColumnModel
		WHERE ExistOnHitomi = 1
	`); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	fmt.Printf("[fast-hsync] FTS full build completed in %.1fs\n", time.Since(start).Seconds())
	return nil
}

func updateFtsRows(db *sql.DB, ids []int) error {
	if len(ids) == 0 {
		return nil
	}

	start := time.Now()

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for i := 0; i < len(ids); i += 500 {
		end := i + 500
		if end > len(ids) {
			end = len(ids)
		}

		batch := ids[i:end]
		placeholders := make([]string, len(batch))
		args := make([]interface{}, len(batch))
		for j, id := range batch {
			placeholders[j] = "?"
			args[j] = id
		}

		inClause := joinStrings(placeholders, ",")

		if _, err := tx.Exec(
			fmt.Sprintf(`DELETE FROM FtsTitle WHERE rowid IN (%s)`, inClause),
			args...,
		); err != nil {
			return err
		}
		if _, err := tx.Exec(
			fmt.Sprintf(`DELETE FROM FtsTags WHERE rowid IN (%s)`, inClause),
			args...,
		); err != nil {
			return err
		}

		insertArgs := append([]interface{}{}, args...)
		if _, err := tx.Exec(
			fmt.Sprintf(`
				INSERT INTO FtsTitle(rowid, Title)
				SELECT Id, COALESCE(Title, '')
				FROM HitomiColumnModel
				WHERE ExistOnHitomi = 1 AND Id IN (%s)
			`, inClause),
			insertArgs...,
		); err != nil {
			return err
		}
		if _, err := tx.Exec(
			fmt.Sprintf(`
				INSERT INTO FtsTags(rowid, Tags, Artists, Groups_, Series, Characters)
				SELECT
					Id,
					TRIM(REPLACE(REPLACE(COALESCE(Tags, ''), ' ', '_'), '|', ' ')),
					TRIM(REPLACE(REPLACE(COALESCE(Artists, ''), ' ', '_'), '|', ' ')),
					TRIM(REPLACE(REPLACE(COALESCE("Groups", ''), ' ', '_'), '|', ' ')),
					TRIM(REPLACE(REPLACE(COALESCE(Series, ''), ' ', '_'), '|', ' ')),
					TRIM(REPLACE(REPLACE(COALESCE(Characters, ''), ' ', '_'), '|', ' '))
				FROM HitomiColumnModel
				WHERE ExistOnHitomi = 1 AND Id IN (%s)
			`, inClause),
			args...,
		); err != nil {
			return err
		}
	}

	if err := tx.Commit(); err != nil {
		return err
	}

	fmt.Printf("[fast-hsync] FTS incremental update completed for %d rows in %.1fs\n", len(ids), time.Since(start).Seconds())
	return nil
}

func getLatestID(db *sql.DB) (int, error) {
	var id sql.NullInt64
	err := db.QueryRow("SELECT MAX(Id) FROM HitomiColumnModel").Scan(&id)
	if err != nil {
		return 0, err
	}
	if !id.Valid {
		return 0, nil
	}
	return int(id.Int64), nil
}

func getExistingIDs(db *sql.DB) (map[int]bool, error) {
	rows, err := db.Query("SELECT Id FROM HitomiColumnModel")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	ids := make(map[int]bool)
	var id int
	for rows.Next() {
		if err := rows.Scan(&id); err != nil {
			continue
		}
		ids[id] = true
	}
	return ids, rows.Err()
}

func getExistingByIDs(db *sql.DB, ids []int) (map[int]*HitomiColumnModel, error) {
	if len(ids) == 0 {
		return make(map[int]*HitomiColumnModel), nil
	}

	result := make(map[int]*HitomiColumnModel)

	// Query in batches of 500 to avoid SQL variable limits
	for i := 0; i < len(ids); i += 500 {
		end := i + 500
		if end > len(ids) {
			end = len(ids)
		}
		batch := ids[i:end]

		placeholders := make([]string, len(batch))
		args := make([]interface{}, len(batch))
		for j, id := range batch {
			placeholders[j] = "?"
			args[j] = id
		}

		query := fmt.Sprintf(
			`SELECT Id, Title, EHash, Type, Artists, Characters, "Groups", Language,
			        Series, Tags, Uploader, Published, Files, Class, ExistOnHitomi, Thumbnail
			 FROM HitomiColumnModel WHERE Id IN (%s)`,
			joinStrings(placeholders, ","),
		)

		rows, err := db.Query(query, args...)
		if err != nil {
			return nil, err
		}

		for rows.Next() {
			m := &HitomiColumnModel{}
			var (
				ehash, typ, artists, chars, groups sql.NullString
				lang, series, tags, uploader       sql.NullString
				class, thumbnail, title, published sql.NullString
			)
			err := rows.Scan(
				&m.ID, &title, &ehash, &typ, &artists, &chars, &groups,
				&lang, &series, &tags, &uploader, &published,
				&m.Files, &class, &m.ExistOnHitomi, &thumbnail,
			)
			if err != nil {
				continue
			}
			m.Title = title.String
			m.EHash = ehash.String
			m.Type = typ.String
			m.Artists = artists.String
			m.Characters = chars.String
			m.Groups = groups.String
			m.Language = lang.String
			m.Series = series.String
			m.Tags = tags.String
			m.Uploader = uploader.String
			m.Class = class.String
			m.Thumbnail = thumbnail.String
			result[m.ID] = m
		}
		rows.Close()
	}

	return result, nil
}

func upsertArticles(db *sql.DB, articles []*HitomiColumnModel) error {
	if len(articles) == 0 {
		return nil
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`
		INSERT OR REPLACE INTO HitomiColumnModel
		(Id, Title, EHash, Type, Artists, Characters, "Groups", Language, Series, Tags,
		 Uploader, Published, Files, Class, ExistOnHitomi, Thumbnail)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, a := range articles {
		var published interface{}
		if a.Published != nil {
			published = a.Published.Format("2006-01-02 15:04:05")
		}

		_, err := stmt.Exec(
			a.ID, nilIfEmpty(a.Title), nilIfEmpty(a.EHash), nilIfEmpty(a.Type),
			nilIfEmpty(a.Artists), nilIfEmpty(a.Characters), nilIfEmpty(a.Groups),
			nilIfEmpty(a.Language), nilIfEmpty(a.Series), nilIfEmpty(a.Tags),
			nilIfEmpty(a.Uploader), published, a.Files, nilIfEmpty(a.Class),
			a.ExistOnHitomi, nilIfEmpty(a.Thumbnail),
		)
		if err != nil {
			return fmt.Errorf("insert id=%d: %w", a.ID, err)
		}
	}

	return tx.Commit()
}

func nilIfEmpty(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

func joinStrings(ss []string, sep string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += sep
		}
		result += s
	}
	return result
}

// isDiff checks if two models differ in their core fields (matching C# isDiff)
func isDiff(a, b *HitomiColumnModel) bool {
	return a.Artists != b.Artists ||
		a.Groups != b.Groups ||
		a.Uploader != b.Uploader ||
		a.Tags != b.Tags ||
		a.Characters != b.Characters ||
		a.Series != b.Series ||
		a.Language != b.Language ||
		a.Type != b.Type ||
		a.Files != b.Files
}
