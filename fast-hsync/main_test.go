package main

import (
	"database/sql"
	"os"
	"strings"
	"testing"
	"time"
)

func TestProjectBrandingUsesFastHsync(t *testing.T) {
	files := []string{"go.mod", "main.go", "db.go"}
	for _, file := range files {
		content, err := os.ReadFile(file)
		if err != nil {
			t.Fatalf("read %s: %v", file, err)
		}
		if strings.Contains(string(content), "hsync-go") {
			t.Fatalf("%s still references hsync-go", file)
		}
	}

	mod, err := os.ReadFile("go.mod")
	if err != nil {
		t.Fatalf("read go.mod: %v", err)
	}
	if !strings.Contains(string(mod), "module fast-hsync") {
		t.Fatalf("go.mod module should be fast-hsync")
	}
}

func TestParseOptions(t *testing.T) {
	opts, err := parseOptions([]string{"custom.db", "--force", "--with-exh", "--latest-id=12345", "--start-id=0", "--end-id=4000000"})
	if err != nil {
		t.Fatalf("parseOptions: %v", err)
	}
	if opts.dbPath != "custom.db" {
		t.Fatalf("dbPath = %q, want custom.db", opts.dbPath)
	}
	if !opts.forceAll {
		t.Fatal("forceAll should be true")
	}
	if !opts.withExH {
		t.Fatal("withExH should be true")
	}
	if opts.seedLatestID != 12345 {
		t.Fatalf("seedLatestID = %d, want 12345", opts.seedLatestID)
	}
	if opts.startID != 0 {
		t.Fatalf("startID = %d, want 0", opts.startID)
	}
	if opts.endID != 4000000 {
		t.Fatalf("endID = %d, want 4000000", opts.endID)
	}
}

func TestParseOptionsLatestIDValueForm(t *testing.T) {
	opts, err := parseOptions([]string{"--latest-id", "23456", "custom.db"})
	if err != nil {
		t.Fatalf("parseOptions: %v", err)
	}
	if opts.seedLatestID != 23456 {
		t.Fatalf("seedLatestID = %d, want 23456", opts.seedLatestID)
	}
	if opts.dbPath != "custom.db" {
		t.Fatalf("dbPath = %q, want custom.db", opts.dbPath)
	}
}

func TestResolveLatestIDUsesSeedForEmptyDB(t *testing.T) {
	latestID, err := resolveLatestID(0, 34567, false)
	if err != nil {
		t.Fatalf("resolveLatestID: %v", err)
	}
	if latestID != 34567 {
		t.Fatalf("latestID = %d, want 34567", latestID)
	}
}

func TestResolveLatestIDRejectsEmptyDBWithoutSeed(t *testing.T) {
	_, err := resolveLatestID(0, 0, false)
	if err == nil {
		t.Fatal("expected error for empty DB without seed")
	}
	if !strings.Contains(err.Error(), "--latest-id") {
		t.Fatalf("error should mention --latest-id, got %q", err)
	}
}

func TestResolveLatestIDAllowsEmptyDBWithExplicitRange(t *testing.T) {
	latestID, err := resolveLatestID(0, 0, true)
	if err != nil {
		t.Fatalf("resolveLatestID: %v", err)
	}
	if latestID != 0 {
		t.Fatalf("latestID = %d, want 0", latestID)
	}
}

func TestBuildGalleryBlockIDsUsesExplicitRange(t *testing.T) {
	ids := buildGalleryBlockIDs(12345, nil, 0, 5)
	want := []int{0, 1, 2, 3, 4}
	if len(ids) != len(want) {
		t.Fatalf("len(ids) = %d, want %d: %v", len(ids), len(want), ids)
	}
	for i := range want {
		if ids[i] != want[i] {
			t.Fatalf("ids[%d] = %d, want %d", i, ids[i], want[i])
		}
	}
}

func TestBuildGalleryBlockIDsExplicitRangeSkipsExisting(t *testing.T) {
	ids := buildGalleryBlockIDs(12345, map[int]bool{1: true, 3: true}, 0, 5)
	want := []int{0, 2, 4}
	if len(ids) != len(want) {
		t.Fatalf("len(ids) = %d, want %d: %v", len(ids), len(want), ids)
	}
	for i := range want {
		if ids[i] != want[i] {
			t.Fatalf("ids[%d] = %d, want %d", i, ids[i], want[i])
		}
	}
}

// --- Model tests ---

func TestLegalizeLanguage(t *testing.T) {
	tests := []struct{ input, want string }{
		{"한국어", "korean"},
		{"English", "english"},
		{"日本語", "japanese"},
		{"中文", "chinese"},
		{"unknown", "unknown"},
		{"", ""},
	}
	for _, tc := range tests {
		got := legalizeLanguage(tc.input)
		if got != tc.want {
			t.Errorf("legalizeLanguage(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestLegalizeTag(t *testing.T) {
	tests := []struct{ input, want string }{
		{"loli ♀", "female:loli"},
		{"yaoi ♂", "male:yaoi"},
		{"glasses", "glasses"},
		{"  spaced  ", "spaced"},
	}
	for _, tc := range tests {
		got := legalizeTag(tc.input)
		if got != tc.want {
			t.Errorf("legalizeTag(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestExtractID(t *testing.T) {
	tests := []struct {
		input string
		want  int
	}{
		{"/gamecg/some-name-123456.html", 123456},
		{"/doujinshi/title-789.html", 789},
		{"/galleries/555.html", 555},
		{"999", 999},
	}
	for _, tc := range tests {
		got, err := extractID(tc.input)
		if err != nil {
			t.Errorf("extractID(%q) error: %v", tc.input, err)
			continue
		}
		if got != tc.want {
			t.Errorf("extractID(%q) = %d, want %d", tc.input, got, tc.want)
		}
	}
}

func TestArticleToColumnModel(t *testing.T) {
	art := &HitomiArticle{
		Artists:    []string{"artist1", "artist2"},
		Characters: []string{"char1"},
		Groups:     []string{"group1"},
		Series:     []string{"series1"},
		Tags:       []string{"female:loli", "male:yaoi"},
		Language:   "korean",
		Type:       "doujinshi",
		Title:      "Test Title",
		Files:      "25",
		DateTime:   "2024-01-15 12:30:00-05",
	}

	m := articleToColumnModel(art, 12345)

	if m.ID != 12345 {
		t.Errorf("ID = %d, want 12345", m.ID)
	}
	if m.Artists != "|artist1|artist2|" {
		t.Errorf("Artists = %q", m.Artists)
	}
	if m.Characters != "|char1|" {
		t.Errorf("Characters = %q", m.Characters)
	}
	if m.Groups != "|group1|" {
		t.Errorf("Groups = %q", m.Groups)
	}
	if m.Series != "|series1|" {
		t.Errorf("Series = %q", m.Series)
	}
	if m.Tags != "|female:loli|male:yaoi|" {
		t.Errorf("Tags = %q", m.Tags)
	}
	if m.Files != 25 {
		t.Errorf("Files = %d, want 25", m.Files)
	}
	if m.ExistOnHitomi != 1 {
		t.Errorf("ExistOnHitomi = %d, want 1", m.ExistOnHitomi)
	}
	if m.Published == nil {
		t.Error("Published is nil")
	}
}

// --- Parser tests ---

func TestParseGalleryBlock(t *testing.T) {
	html := `<div>
		<a href="/doujinshi/cool-title-99999.html">
			<img data-src="//tn.hitomi.la/smallbig/1/ab/abc123.jpg" />
		</a>
		<h1>Cool Title</h1>
		<div class="artist-list">
			<ul>
				<li><a>ArtistA</a></li>
				<li><a>ArtistB</a></li>
			</ul>
		</div>
		<div>
			<table>
				<tr><td>Series</td><td><ul><li><a>SeriesX</a></li></ul></td></tr>
				<tr><td>Type</td><td><a>doujinshi</a></td></tr>
				<tr><td>Language</td><td><a>한국어</a></td></tr>
				<tr><td>Tags</td><td><ul>
					<li><a>loli ♀</a></li>
					<li><a>glasses</a></li>
				</ul></td></tr>
			</table>
			<p>2024-03-20 10:00:00-05</p>
		</div>
	</div>`

	art, err := parseGalleryBlock(html)
	if err != nil {
		t.Fatalf("parseGalleryBlock error: %v", err)
	}

	if art.Magic != "/doujinshi/cool-title-99999.html" {
		t.Errorf("Magic = %q", art.Magic)
	}
	if art.Title != "Cool Title" {
		t.Errorf("Title = %q", art.Title)
	}
	if len(art.Artists) != 2 || art.Artists[0] != "ArtistA" || art.Artists[1] != "ArtistB" {
		t.Errorf("Artists = %v", art.Artists)
	}
	if len(art.Series) != 1 || art.Series[0] != "SeriesX" {
		t.Errorf("Series = %v", art.Series)
	}
	if art.Type != "doujinshi" {
		t.Errorf("Type = %q", art.Type)
	}
	if art.Language != "korean" {
		t.Errorf("Language = %q", art.Language)
	}
	if len(art.Tags) != 2 || art.Tags[0] != "female:loli" || art.Tags[1] != "glasses" {
		t.Errorf("Tags = %v", art.Tags)
	}
	if art.Thumbnail != "big/1/ab/abc123.jpg" {
		t.Errorf("Thumbnail = %q", art.Thumbnail)
	}
	if art.DateTime != "2024-03-20 10:00:00-05" {
		t.Errorf("DateTime = %q", art.DateTime)
	}

	// ID extraction
	id, err := extractID(art.Magic)
	if err != nil || id != 99999 {
		t.Errorf("extractID = %d, err=%v", id, err)
	}
}

func TestParseGallery(t *testing.T) {
	html := `<html><head><title>Gallery</title></head><body>
		<div class="gallery-info">
			<table>
				<tr><td>Group</td><td><a>GroupA</a><a>GroupB</a></td></tr>
				<tr><td>Characters</td><td><a>CharX</a></td></tr>
				<tr><td>Type</td><td><a>doujinshi</a></td></tr>
			</table>
		</div>
	</body></html>`

	groups, chars := parseGallery(html)

	if len(groups) != 2 || groups[0] != "GroupA" || groups[1] != "GroupB" {
		t.Errorf("groups = %v", groups)
	}
	if len(chars) != 1 || chars[0] != "CharX" {
		t.Errorf("characters = %v", chars)
	}
}

func TestParseGalleryRedirect(t *testing.T) {
	html := `<html><head><title>Redirect</title></head><body></body></html>`
	groups, chars := parseGallery(html)
	if len(groups) != 0 || len(chars) != 0 {
		t.Error("expected empty for redirect page")
	}
}

func TestParseGalleryJS(t *testing.T) {
	js := `var galleryinfo = {"id": 123, "files": [{"name":"001.jpg"},{"name":"002.jpg"},{"name":"003.jpg"}], "groups": [{"group":"grpA","url":"/g/a"}], "characters": [{"character":"charX","url":"/c/x"},{"character":"charY","url":"/c/y"}]};`
	info := parseGalleryJS(js)
	if info.Files != 3 {
		t.Errorf("Files = %d, want 3", info.Files)
	}
	if len(info.Groups) != 1 || info.Groups[0] != "grpA" {
		t.Errorf("Groups = %v", info.Groups)
	}
	if len(info.Characters) != 2 || info.Characters[0] != "charX" || info.Characters[1] != "charY" {
		t.Errorf("Characters = %v", info.Characters)
	}
}

func TestParseGalleryJSNullFields(t *testing.T) {
	js := `var galleryinfo = {"files": [{"name":"001.jpg"}], "groups": null, "characters": null};`
	info := parseGalleryJS(js)
	if info.Files != 1 {
		t.Errorf("Files = %d, want 1", info.Files)
	}
	if len(info.Groups) != 0 {
		t.Errorf("Groups should be empty, got %v", info.Groups)
	}
	if len(info.Characters) != 0 {
		t.Errorf("Characters should be empty, got %v", info.Characters)
	}
}

func TestParseGalleryJSEmpty(t *testing.T) {
	info := parseGalleryJS("")
	if info.Files != 0 {
		t.Error("expected 0 for empty")
	}
	info = parseGalleryJS("some random text")
	if info.Files != 0 {
		t.Error("expected 0 for random text")
	}
}

// --- DB tests ---

func TestDBOperations(t *testing.T) {
	tmpFile := t.TempDir() + "/test.db"
	defer os.Remove(tmpFile)

	db, err := openDB(tmpFile)
	if err != nil {
		t.Fatalf("openDB: %v", err)
	}
	defer db.Close()

	// Create table
	if err := createTable(db); err != nil {
		t.Fatalf("createTable: %v", err)
	}

	// Empty DB should return 0
	latestID, err := getLatestID(db)
	if err != nil {
		t.Fatalf("getLatestID: %v", err)
	}
	if latestID != 0 {
		t.Errorf("latestID = %d, want 0", latestID)
	}

	// Insert some records
	now := time.Now().UTC().Truncate(time.Second)
	articles := []*HitomiColumnModel{
		{
			ID: 100, Title: "Test 100", Artists: "|artist1|",
			Language: "korean", Type: "doujinshi", ExistOnHitomi: 1,
			Files: 10, Published: &now,
		},
		{
			ID: 200, Title: "Test 200", Artists: "|artist2|",
			Language: "english", Type: "manga", ExistOnHitomi: 1,
			Files: 20, Tags: "|female:loli|",
		},
		{
			ID: 150, Title: "Test 150", Artists: "|N/A|",
			Language: "japanese", Type: "gamecg", ExistOnHitomi: 1,
			Groups: "|group1|", Characters: "|char1|",
		},
	}

	if err := upsertArticles(db, articles); err != nil {
		t.Fatalf("upsertArticles: %v", err)
	}

	// Check latest ID
	latestID, err = getLatestID(db)
	if err != nil {
		t.Fatalf("getLatestID: %v", err)
	}
	if latestID != 200 {
		t.Errorf("latestID = %d, want 200", latestID)
	}

	// Check existing IDs
	existIDs, err := getExistingIDs(db)
	if err != nil {
		t.Fatalf("getExistingIDs: %v", err)
	}
	if len(existIDs) != 3 {
		t.Errorf("existIDs count = %d, want 3", len(existIDs))
	}
	if !existIDs[100] || !existIDs[150] || !existIDs[200] {
		t.Error("missing expected IDs")
	}

	// Check getExistingByIDs
	existing, err := getExistingByIDs(db, []int{100, 200, 999})
	if err != nil {
		t.Fatalf("getExistingByIDs: %v", err)
	}
	if len(existing) != 2 {
		t.Errorf("existing count = %d, want 2", len(existing))
	}
	if existing[100].Title != "Test 100" {
		t.Errorf("existing[100].Title = %q", existing[100].Title)
	}
	if existing[200].Tags != "|female:loli|" {
		t.Errorf("existing[200].Tags = %q", existing[200].Tags)
	}

	// Test upsert (update existing record)
	updated := []*HitomiColumnModel{
		{
			ID: 100, Title: "Updated 100", Artists: "|artist1|artist3|",
			Language: "korean", Type: "doujinshi", ExistOnHitomi: 1,
			Files: 15,
		},
	}
	if err := upsertArticles(db, updated); err != nil {
		t.Fatalf("upsert update: %v", err)
	}

	afterUpdate, err := getExistingByIDs(db, []int{100})
	if err != nil {
		t.Fatalf("getExistingByIDs after update: %v", err)
	}
	if afterUpdate[100].Title != "Updated 100" {
		t.Errorf("after update title = %q", afterUpdate[100].Title)
	}
	if afterUpdate[100].Files != 15 {
		t.Errorf("after update files = %d", afterUpdate[100].Files)
	}

	// Test isDiff
	a := &HitomiColumnModel{Artists: "|a|", Language: "ko", Files: 10}
	b := &HitomiColumnModel{Artists: "|a|", Language: "ko", Files: 10}
	if isDiff(a, b) {
		t.Error("isDiff should return false for identical")
	}
	b.Files = 20
	if !isDiff(a, b) {
		t.Error("isDiff should return true for different Files")
	}
}

func TestDBCount(t *testing.T) {
	tmpFile := t.TempDir() + "/count_test.db"
	defer os.Remove(tmpFile)

	db, err := openDB(tmpFile)
	if err != nil {
		t.Fatalf("openDB: %v", err)
	}
	defer db.Close()

	createTable(db)

	// Insert 100 records
	models := make([]*HitomiColumnModel, 100)
	for i := range models {
		models[i] = &HitomiColumnModel{
			ID: 1000 + i, Title: "bulk test",
			Artists: "|N/A|", Language: "n/a", ExistOnHitomi: 1,
		}
	}
	if err := upsertArticles(db, models); err != nil {
		t.Fatalf("bulk insert: %v", err)
	}

	var count int
	db.QueryRow("SELECT COUNT(*) FROM HitomiColumnModel").Scan(&count)
	if count != 100 {
		t.Errorf("count = %d, want 100", count)
	}

	// Verify latest ID
	latest, _ := getLatestID(db)
	if latest != 1099 {
		t.Errorf("latest = %d, want 1099", latest)
	}
}

func TestSearchIndexLifecycle(t *testing.T) {
	tmpFile := t.TempDir() + "/fts_test.db"
	defer os.Remove(tmpFile)

	db, err := openDB(tmpFile)
	if err != nil {
		t.Fatalf("openDB: %v", err)
	}
	defer db.Close()

	if err := createTable(db); err != nil {
		t.Fatalf("createTable: %v", err)
	}

	initial := []*HitomiColumnModel{
		{
			ID:            100,
			Title:         "Love Story",
			Artists:       "|artist1|",
			Language:      "english",
			Type:          "doujinshi",
			Tags:          "|female:big breasts|glasses|",
			ExistOnHitomi: 1,
		},
		{
			ID:            200,
			Title:         "Side Story",
			Artists:       "|artist2|",
			Language:      "korean",
			Type:          "manga",
			Tags:          "|male:yaoi|",
			ExistOnHitomi: 1,
		},
		{
			ID:            300,
			Title:         "ExH Only",
			Artists:       "|artist3|",
			Language:      "japanese",
			Type:          "manga",
			Tags:          "|female:loli|",
			ExistOnHitomi: 0,
		},
	}

	if err := upsertArticles(db, initial); err != nil {
		t.Fatalf("upsertArticles: %v", err)
	}
	if err := ensureBTreeIndexes(db); err != nil {
		t.Fatalf("ensureBTreeIndexes: %v", err)
	}

	ready, err := isFtsReady(db)
	if err != nil {
		t.Fatalf("isFtsReady before build: %v", err)
	}
	if ready {
		t.Fatal("FTS should not exist before rebuild")
	}

	if err := rebuildFts(db); err != nil {
		t.Fatalf("rebuildFts: %v", err)
	}

	ready, err = isFtsReady(db)
	if err != nil {
		t.Fatalf("isFtsReady after build: %v", err)
	}
	if !ready {
		t.Fatal("FTS should exist after rebuild")
	}

	var count int
	if err := db.QueryRow(`SELECT COUNT(*) FROM FtsTags WHERE Tags MATCH '"female:big_breasts"'`).Scan(&count); err != nil {
		t.Fatalf("tag match query: %v", err)
	}
	if count != 1 {
		t.Fatalf("female:big_breasts count = %d, want 1", count)
	}

	if err := db.QueryRow(`SELECT COUNT(*) FROM FtsTitle WHERE FtsTitle MATCH '"love"'`).Scan(&count); err != nil {
		t.Fatalf("title match query: %v", err)
	}
	if count != 1 {
		t.Fatalf("title love count = %d, want 1", count)
	}

	if err := db.QueryRow(`SELECT COUNT(*) FROM FtsTitle WHERE rowid = 300`).Scan(&count); err != nil {
		t.Fatalf("exh title presence query: %v", err)
	}
	if count != 0 {
		t.Fatalf("ExistOnHitomi=0 row should not be indexed, got %d", count)
	}

	updated := []*HitomiColumnModel{
		{
			ID:            100,
			Title:         "Space Story",
			Artists:       "|artist1|",
			Language:      "english",
			Type:          "doujinshi",
			Tags:          "|female:glasses|",
			ExistOnHitomi: 1,
		},
	}

	if err := upsertArticles(db, updated); err != nil {
		t.Fatalf("upsertArticles updated: %v", err)
	}
	if err := updateFtsRows(db, articleIDs(updated)); err != nil {
		t.Fatalf("updateFtsRows: %v", err)
	}

	if err := db.QueryRow(`SELECT COUNT(*) FROM FtsTags WHERE Tags MATCH '"female:big_breasts"'`).Scan(&count); err != nil {
		t.Fatalf("old tag query after update: %v", err)
	}
	if count != 0 {
		t.Fatalf("old tag should be removed, got %d", count)
	}

	if err := db.QueryRow(`SELECT COUNT(*) FROM FtsTags WHERE Tags MATCH '"female:glasses"'`).Scan(&count); err != nil {
		t.Fatalf("new tag query after update: %v", err)
	}
	if count != 1 {
		t.Fatalf("new tag count = %d, want 1", count)
	}

	if err := db.QueryRow(`SELECT COUNT(*) FROM FtsTitle WHERE FtsTitle MATCH '"space"'`).Scan(&count); err != nil {
		t.Fatalf("new title query after update: %v", err)
	}
	if count != 1 {
		t.Fatalf("new title count = %d, want 1", count)
	}
}

// Verify unused import doesn't cause issues
var _ = sql.ErrNoRows
