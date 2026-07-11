package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	lookupRange    = 10000
	maxConcurrency = 1024
	defaultDBPath  = "data.db"
)

type syncEntry struct {
	idx     int // index into galleryURLs/jsURLs
	article *HitomiArticle
	id      int
}

type options struct {
	dbPath       string
	forceAll     bool
	withExH      bool
	quiet        bool
	seedLatestID int
	startID      int
	endID        int
}

func main() {
	log.SetFlags(log.Ltime | log.Lmsgprefix)
	log.SetPrefix("[fast-hsync] ")

	opts, err := parseOptions(os.Args[1:])
	if err != nil {
		log.Fatal(err)
	}
	opts.quiet = resolveQuiet(opts.quiet, os.Getenv("FAST_HSYNC_QUIET"))

	db, latestID := initDB(opts)
	defer db.Close()

	// Phase 1: Download gallery blocks (skip existing unless --force)
	var existingIDs map[int]bool
	if !opts.forceAll {
		var err error
		existingIDs, err = getExistingIDs(db)
		if err != nil {
			log.Fatalf("Failed to get existing IDs: %v", err)
		}
	}
	_, blockHTMLs := downloadGalleryBlocks(latestID, existingIDs, opts.startID, opts.endID, opts.quiet)

	// Phase 2: Parse blocks → prepare gallery JS URLs
	entries, jsURLs := parseBlocks(blockHTMLs)
	log.Printf("Found %d valid galleries, downloading gallery info...", len(entries))

	// Phase 3: Download gallery JS (file counts + groups + characters)
	jsResults := downloadStrings(jsURLs, maxConcurrency, "gallery-js", opts.quiet)

	// Phase 4: Merge downloaded data → build column models
	newModels, newIDs := buildModels(entries, jsResults)

	// Phase 5 (optional): ExHentai sync + merge
	if opts.withExH {
		newModels, newIDs = mergeExHentai(db, latestID, newModels, newIDs)
	}

	// Phase 6: Diff with existing DB, keep only new/changed
	toUpsert := diffWithExisting(db, newModels, newIDs)

	// Phase 7: Upsert
	if err := upsertArticles(db, toUpsert); err != nil {
		log.Fatalf("Failed to upsert: %v", err)
	}

	// Phase 8: Update search indexes
	if err := maintainSearchIndexes(db, toUpsert); err != nil {
		log.Fatalf("Failed to maintain search indexes: %v", err)
	}

	// Phase 9: Save chunk output
	saveChunk(toUpsert)
	log.Printf("Sync complete! Upserted %d records.", len(toUpsert))
}

func resolveQuiet(flag bool, envValue string) bool {
	envQuiet := strings.EqualFold(strings.TrimSpace(envValue), "true") || strings.TrimSpace(envValue) == "1"
	return flag || envQuiet
}

func parseOptions(args []string) (options, error) {
	opts := options{dbPath: defaultDBPath}
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "-f" || arg == "--force":
			opts.forceAll = true
		case arg == "--with-exh":
			opts.withExH = true
		case arg == "-q" || arg == "--quiet":
			opts.quiet = true
		case arg == "--latest-id":
			if i+1 >= len(args) {
				return opts, errors.New("--latest-id requires a numeric value")
			}
			i++
			id, err := strconv.Atoi(args[i])
			if err != nil || id <= 0 {
				return opts, fmt.Errorf("invalid --latest-id value: %s", args[i])
			}
			opts.seedLatestID = id
		case strings.HasPrefix(arg, "--latest-id="):
			value := strings.TrimPrefix(arg, "--latest-id=")
			id, err := strconv.Atoi(value)
			if err != nil || id <= 0 {
				return opts, fmt.Errorf("invalid --latest-id value: %s", value)
			}
			opts.seedLatestID = id
		case arg == "--start-id":
			if i+1 >= len(args) {
				return opts, errors.New("--start-id requires a numeric value")
			}
			i++
			id, err := strconv.Atoi(args[i])
			if err != nil || id < 0 {
				return opts, fmt.Errorf("invalid --start-id value: %s", args[i])
			}
			opts.startID = id
		case strings.HasPrefix(arg, "--start-id="):
			value := strings.TrimPrefix(arg, "--start-id=")
			id, err := strconv.Atoi(value)
			if err != nil || id < 0 {
				return opts, fmt.Errorf("invalid --start-id value: %s", value)
			}
			opts.startID = id
		case arg == "--end-id":
			if i+1 >= len(args) {
				return opts, errors.New("--end-id requires a numeric value")
			}
			i++
			id, err := strconv.Atoi(args[i])
			if err != nil || id <= 0 {
				return opts, fmt.Errorf("invalid --end-id value: %s", args[i])
			}
			opts.endID = id
		case strings.HasPrefix(arg, "--end-id="):
			value := strings.TrimPrefix(arg, "--end-id=")
			id, err := strconv.Atoi(value)
			if err != nil || id <= 0 {
				return opts, fmt.Errorf("invalid --end-id value: %s", value)
			}
			opts.endID = id
		case strings.HasPrefix(arg, "-"):
			return opts, fmt.Errorf("unknown option: %s", arg)
		default:
			opts.dbPath = arg
		}
	}
	if opts.endID > 0 && opts.startID >= opts.endID {
		return opts, errors.New("--start-id must be smaller than --end-id")
	}
	return opts, nil
}

func hasFlag(flags ...string) bool {
	for _, arg := range os.Args[1:] {
		for _, f := range flags {
			if arg == f {
				return true
			}
		}
	}
	return false
}

func articleIDs(articles []*HitomiColumnModel) []int {
	ids := make([]int, 0, len(articles))
	for _, article := range articles {
		ids = append(ids, article.ID)
	}
	return ids
}

func maintainSearchIndexes(db *sql.DB, articles []*HitomiColumnModel) error {
	if err := ensureBTreeIndexes(db); err != nil {
		return err
	}

	ftsReady, err := isFtsReady(db)
	if err != nil {
		return err
	}

	if !ftsReady {
		log.Printf("FTS not found, running full build...")
		return rebuildFts(db)
	}

	if len(articles) == 0 {
		log.Printf("FTS found, no changed rows to update.")
		return nil
	}

	log.Printf("FTS found, updating %d changed rows...", len(articles))
	return updateFtsRows(db, articleIDs(articles))
}

// initDB opens (or creates) the database and returns it with the latest ID.
func initDB(opts options) (*sql.DB, int) {
	db, err := openDB(opts.dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}

	if err := createTable(db); err != nil {
		log.Fatalf("Failed to create table: %v", err)
	}

	latestID, err := getLatestID(db)
	if err != nil {
		log.Fatalf("Failed to get latest ID: %v", err)
	}
	latestID, err = resolveLatestID(latestID, opts.seedLatestID, opts.endID > 0)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("latest_id: %d", latestID)

	return db, latestID
}

func resolveLatestID(dbLatestID, seedLatestID int, hasExplicitRange bool) (int, error) {
	if dbLatestID > 0 {
		return dbLatestID, nil
	}
	if seedLatestID > 0 {
		return seedLatestID, nil
	}
	if hasExplicitRange {
		return 0, nil
	}
	return 0, errors.New("database is empty. Run with --latest-id=N or --start-id=N --end-id=N for the first sync, or provide an existing data.db")
}

// downloadGalleryBlocks generates gallery block URLs for [latestID-range, latestID+range)
// and downloads them concurrently. If existingIDs is non-nil, already-known IDs are skipped.
func downloadGalleryBlocks(latestID int, existingIDs map[int]bool, explicitStartID, explicitEndID int, quiet bool) (ids []int, htmls []string) {
	ids = buildGalleryBlockIDs(latestID, existingIDs, explicitStartID, explicitEndID)

	startID, endID := defaultGalleryBlockRange(latestID)
	if explicitEndID > 0 {
		startID = explicitStartID
		endID = explicitEndID
	}

	urls := make([]string, len(ids))
	for i, id := range ids {
		urls[i] = fmt.Sprintf("https://ltn.gold-usergeneratedcontent.net/galleryblock/%d.html", id)
	}

	log.Printf("Downloading %d gallery blocks [%d ~ %d]...", len(ids), startID, endID-1)
	htmls = downloadStrings(urls, maxConcurrency, "galleryblock", quiet)
	return
}

func defaultGalleryBlockRange(latestID int) (int, int) {
	startID := latestID - lookupRange
	if startID < 1 {
		startID = 1
	}
	endID := startID + lookupRange*2
	return startID, endID
}

func buildGalleryBlockIDs(latestID int, existingIDs map[int]bool, explicitStartID, explicitEndID int) []int {
	startID, endID := defaultGalleryBlockRange(latestID)
	if explicitEndID > 0 {
		startID = explicitStartID
		endID = explicitEndID
	}

	// Build ID list, optionally filtering out existing
	ids := make([]int, 0, endID-startID)
	for i := startID; i < endID; i++ {
		if existingIDs != nil && existingIDs[i] {
			continue
		}
		ids = append(ids, i)
	}

	skipped := (endID - startID) - len(ids)
	if skipped > 0 {
		log.Printf("Skipped %d existing IDs (use -f to force re-download)", skipped)
	}

	return ids
}

// parseBlocks parses downloaded gallery block HTMLs and prepares
// gallery JS URLs (for file counts, groups, and characters).
func parseBlocks(blockHTMLs []string) (entries []syncEntry, jsURLs []string) {
	for _, html := range blockHTMLs {
		if html == "" {
			continue
		}
		art, err := parseGalleryBlock(html)
		if err != nil {
			continue
		}
		artID, err := extractID(art.Magic)
		if err != nil {
			continue
		}

		jsURL := fmt.Sprintf("https://ltn.gold-usergeneratedcontent.net/galleries/%d.js", artID)

		entries = append(entries, syncEntry{idx: len(jsURLs), article: art, id: artID})
		jsURLs = append(jsURLs, jsURL)
	}
	return
}

// buildModels merges gallery JS data (file count, groups, characters)
// into each parsed article, then converts them to HitomiColumnModels.
func buildModels(entries []syncEntry, jsResults []string) ([]*HitomiColumnModel, []int) {
	models := make([]*HitomiColumnModel, 0, len(entries))
	ids := make([]int, 0, len(entries))

	for _, e := range entries {
		art := e.article

		if e.idx < len(jsResults) && jsResults[e.idx] != "" {
			info := parseGalleryJS(jsResults[e.idx])
			if info.Files > 0 {
				art.Files = strconv.Itoa(info.Files)
			}
			if len(info.Groups) > 0 {
				art.Groups = info.Groups
			}
			if len(info.Characters) > 0 {
				art.Characters = info.Characters
			}
		}

		models = append(models, articleToColumnModel(art, e.id))
		ids = append(ids, e.id)
	}
	return models, ids
}

// diffWithExisting queries existing DB records and returns only new or changed models.
func diffWithExisting(db *sql.DB, models []*HitomiColumnModel, ids []int) []*HitomiColumnModel {
	existing, err := getExistingByIDs(db, ids)
	if err != nil {
		log.Fatalf("Failed to query existing records: %v", err)
	}

	var toUpsert []*HitomiColumnModel
	for _, m := range models {
		if ex, ok := existing[m.ID]; ok {
			if isDiff(m, ex) {
				toUpsert = append(toUpsert, m)
			}
		} else {
			toUpsert = append(toUpsert, m)
		}
	}

	log.Printf("Total parsed: %d, New/Updated: %d, Unchanged: %d",
		len(models), len(toUpsert), len(models)-len(toUpsert))
	return toUpsert
}

// --- Download infrastructure ---

type downloadStats struct {
	success int64
	missing int64
	errors  int64
	status  map[int]int64
	mu      sync.Mutex
}

func (s *downloadStats) recordStatus(code int) {
	s.mu.Lock()
	s.status[code]++
	s.mu.Unlock()
}

func formatDownloadProgress(quiet bool, label string, completed int64, total int, success int64, errors int64) string {
	if quiet {
		return ""
	}
	return fmt.Sprintf("\r  %s: %d/%d (ok: %d, errors: %d)", label, completed, total, success, errors)
}

func formatDownloadSummary(label string, total int, success int64, missing int64, errors int64, stats *downloadStats) string {
	stats.mu.Lock()
	codes := make([]int, 0, len(stats.status))
	for code := range stats.status {
		codes = append(codes, code)
	}
	sort.Ints(codes)
	statuses := make([]string, 0, len(codes))
	for _, code := range codes {
		statuses = append(statuses, fmt.Sprintf("%d:%d", code, stats.status[code]))
	}
	stats.mu.Unlock()

	summary := fmt.Sprintf("%s complete: total=%d, ok=%d, missing=%d, errors=%d", label, total, success, missing, errors)
	if len(statuses) == 0 {
		return summary
	}
	return summary + ", statuses=" + strings.Join(statuses, ",")
}

func downloadStrings(urls []string, concurrency int, label string, quiet bool) []string {
	if len(urls) == 0 {
		return nil
	}

	results := make([]string, len(urls))
	var wg sync.WaitGroup
	sem := make(chan struct{}, concurrency)
	stats := &downloadStats{status: make(map[int]int64)}

	client := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        concurrency,
			MaxIdleConnsPerHost: concurrency,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	for i, url := range urls {
		wg.Add(1)
		sem <- struct{}{}
		go func(idx int, u string) {
			defer wg.Done()
			defer func() { <-sem }()

			for retry := 0; retry < 3; retry++ {
				req, err := http.NewRequest("GET", u, nil)
				if err != nil {
					break
				}
				req.Header.Set("Referer", "https://hitomi.la/")
				req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
				req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

				resp, err := client.Do(req)
				if err != nil {
					if retry < 2 {
						time.Sleep(time.Duration(retry+1) * 500 * time.Millisecond)
						continue
					}
					break
				}

				stats.recordStatus(resp.StatusCode)

				if resp.StatusCode == 200 {
					body, err := io.ReadAll(resp.Body)
					resp.Body.Close()
					if err == nil {
						results[idx] = string(body)
						s := atomic.AddInt64(&stats.success, 1)
						e := atomic.LoadInt64(&stats.errors)
						fmt.Print(formatDownloadProgress(quiet, label, s+e, len(urls), s, e))
						return
					}
				} else {
					resp.Body.Close()
					if resp.StatusCode == 404 {
						atomic.AddInt64(&stats.missing, 1)
						return
					}
					if retry < 2 {
						time.Sleep(time.Duration(retry+1) * 500 * time.Millisecond)
						continue
					}
				}
				break
			}

			s := atomic.LoadInt64(&stats.success)
			e := atomic.AddInt64(&stats.errors, 1)
			fmt.Print(formatDownloadProgress(quiet, label, s+e, len(urls), s, e))
		}(i, url)
	}

	wg.Wait()
	if !quiet {
		fmt.Println()
	}
	s := atomic.LoadInt64(&stats.success)
	m := atomic.LoadInt64(&stats.missing)
	e := atomic.LoadInt64(&stats.errors)
	log.Print(formatDownloadSummary(label, len(urls), s, m, e, stats))
	return results
}

func saveChunk(articles []*HitomiColumnModel) {
	if len(articles) == 0 {
		return
	}

	os.MkdirAll("chunk", 0755)
	ts := time.Now().Format("2006-01-02_150405")
	filename := fmt.Sprintf("chunk/data-%s.json", ts)

	data, err := json.MarshalIndent(articles, "", "  ")
	if err != nil {
		log.Printf("Failed to marshal chunk: %v", err)
		return
	}

	if err := os.WriteFile(filename, data, 0644); err != nil {
		log.Printf("Failed to save chunk: %v", err)
		return
	}
	log.Printf("Saved chunk: %s (%d articles)", filename, len(articles))
}
