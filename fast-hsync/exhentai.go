package main

import (
	"database/sql"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
)

const (
	defaultEHCookie     = "ipb_member_id=2742770; ipb_pass_hash=622fcc2be82c922135bb0516e0ee497d; sk=t8inbzaqn45ttyn9f78eanzuqizh; igneous=tzcmxvx0yhrlli1q7; sl=dm_2"
	ehLookupPages       = 200
	ehRequestDelay      = 100 * time.Millisecond
	ehLongDelay         = 120 * time.Second
	ehLongDelayInterval = 100
)

// EHArticle represents a parsed exhentai gallery entry.
type EHArticle struct {
	URL       string
	Thumbnail string
	Title     string
	Uploader  string
	Published string
	Files     string
	Type      string
	Descripts map[string][]string
}

func getEHID(art *EHArticle) int {
	parts := strings.Split(art.URL, "/")
	if len(parts) > 4 {
		id, _ := strconv.Atoi(parts[4])
		return id
	}
	return 0
}

func getEHHash(art *EHArticle) string {
	parts := strings.Split(art.URL, "/")
	if len(parts) > 5 {
		return parts[5]
	}
	return ""
}

// syncExHentai crawls exhentai pages (normal + expunged) and returns all articles.
func syncExHentai(cookie string, latestID int) []*EHArticle {
	log.Println("Starting ExHentai sync...")

	articles := crawlExHentai(cookie, latestID, false)
	articles = append(articles, crawlExHentai(cookie, latestID, true)...)

	// Deduplicate by URL
	seen := make(map[string]bool)
	deduped := make([]*EHArticle, 0, len(articles))
	for _, a := range articles {
		if !seen[a.URL] {
			seen[a.URL] = true
			deduped = append(deduped, a)
		}
	}

	log.Printf("ExHentai sync done: %d total, %d after dedup", len(articles), len(deduped))
	return deduped
}

func crawlExHentai(cookie string, latestID int, includeExpunged bool) []*EHArticle {
	var articles []*EHArticle
	next := 0

	label := "exhentai"
	if includeExpunged {
		label = "exhentai-expunged"
	}

	client := &http.Client{Timeout: 30 * time.Second}

	for page := 0; ; page++ {
		var url string
		if includeExpunged {
			url = fmt.Sprintf("https://exhentai.org/?next=%d&f_doujinshi=on&f_manga=on&f_artistcg=on&f_gamecg=on&f_cats=0&f_sname=on&f_stags=on&f_sh=on&advsearch=1&f_sname=on&f_stags=on&f_sdesc=on&f_sh=on", next)
		} else {
			url = fmt.Sprintf("https://exhentai.org/?next=%d&f_doujinshi=on&f_manga=on&f_artistcg=on&f_gamecg=on&f_cats=0&f_sname=on&f_stags=on&advsearch=1&f_sname=on&f_stags=on&f_sdesc=on", next)
		}

		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			log.Printf("[%s] page %d: request error: %v", label, page, err)
			break
		}
		req.Header.Set("Cookie", cookie)
		req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
		req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

		resp, err := client.Do(req)
		if err != nil {
			log.Printf("[%s] page %d: fetch error: %v", label, page, err)
			time.Sleep(ehRequestDelay)
			continue
		}

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			log.Printf("[%s] page %d: read error: %v", label, page, err)
			continue
		}

		parsed := parseExHentaiExtendedList(string(body))
		if len(parsed) == 0 {
			log.Printf("[%s] page %d: no results, stopping", label, page)
			break
		}

		articles = append(articles, parsed...)

		if len(parsed) != 25 {
			log.Printf("[%s] page %d: got %d (expected 25)", label, page, len(parsed))
		}

		// Find min ID for stop condition
		minID := 0
		for _, a := range parsed {
			if id := getEHID(a); minID == 0 || (id > 0 && id < minID) {
				minID = id
			}
		}

		next = getEHID(parsed[len(parsed)-1])
		log.Printf("[%s] page %d, total: %d, next: %d", label, page, len(articles), next)

		if page > ehLookupPages && minID > 0 && minID < latestID {
			log.Printf("[%s] reached latestID boundary, stopping", label)
			break
		}

		// Rate limiting
		time.Sleep(ehRequestDelay)
		if (page+1)%ehLongDelayInterval == 0 {
			log.Printf("[%s] rate limit pause (120s)...", label)
			time.Sleep(ehLongDelay)
		}
	}

	return articles
}

// parseExHentaiExtendedList parses the exhentai extended list view HTML.
func parseExHentaiExtendedList(html string) []*EHArticle {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil
	}

	var articles []*EHArticle

	doc.Find("table.itg.glte tr").Each(func(_ int, row *goquery.Selection) {
		tds := row.Children().Filter("td")
		if tds.Length() < 2 {
			return
		}

		art := &EHArticle{Descripts: make(map[string][]string)}

		// URL and thumbnail from first link/image
		if a := row.Find("a").First(); a.Length() > 0 {
			art.URL, _ = a.Attr("href")
		}
		if art.URL == "" {
			return
		}
		if img := row.Find("img").First(); img.Length() > 0 {
			art.Thumbnail, _ = img.Attr("src")
		}

		// Second td > div > div = metadata section
		secondTd := tds.Eq(1)
		outerDiv := secondTd.Children().Filter("div").First()
		metaDiv := outerDiv.Children().Filter("div").First()
		metaDivs := metaDiv.Children().Filter("div")

		if metaDivs.Length() >= 5 {
			art.Type = strings.ToLower(strings.TrimSpace(metaDivs.Eq(0).Text()))
			art.Published = strings.TrimSpace(metaDivs.Eq(1).Text())
			art.Uploader = strings.TrimSpace(metaDivs.Eq(3).Text())
			art.Files = strings.TrimSpace(metaDivs.Eq(4).Text())
		}

		// Second td > div > a > div = content section
		contentDiv := outerDiv.Find("a > div").First()
		if contentDiv.Length() > 0 {
			art.Title = strings.TrimSpace(contentDiv.Children().Filter("div").First().Text())
		}

		// Tags from table rows inside content
		contentDiv.Find("tr").Each(func(_ int, tr *goquery.Selection) {
			tagTds := tr.Children().Filter("td")
			if tagTds.Length() < 2 {
				return
			}

			category := strings.TrimSpace(tagTds.First().Text())
			category = strings.TrimSuffix(category, ":")
			if category == "" {
				return
			}

			var tags []string
			tagTds.Eq(1).Find("div").Each(func(_ int, d *goquery.Selection) {
				if t := strings.TrimSpace(d.Text()); t != "" {
					tags = append(tags, t)
				}
			})

			if len(tags) > 0 {
				art.Descripts[category] = tags
			}
		})

		articles = append(articles, art)
	})

	return articles
}

// ehArticleToColumnModel converts an ExHentai-only article to a HitomiColumnModel.
func ehArticleToColumnModel(art *EHArticle) *HitomiColumnModel {
	m := &HitomiColumnModel{
		ID:            getEHID(art),
		Title:         art.Title,
		Type:          art.Type,
		ExistOnHitomi: 0,
		Uploader:      art.Uploader,
		EHash:         getEHHash(art),
		Thumbnail:     art.Thumbnail,
	}

	// Files: "25 pages" → 25
	if art.Files != "" {
		parts := strings.SplitN(art.Files, " ", 2)
		m.Files, _ = strconv.Atoi(parts[0])
	}

	// Published
	if art.Published != "" {
		for _, layout := range []string{"2006-01-02 15:04", "2006-01-02 15:04:05"} {
			if t, err := time.Parse(layout, strings.TrimSpace(art.Published)); err == nil {
				m.Published = &t
				break
			}
		}
	}

	// Class from title: "(C99) Title" → "C99"
	if strings.HasPrefix(art.Title, "(") {
		if idx := strings.Index(art.Title, ")"); idx > 1 {
			m.Class = art.Title[1:idx]
		}
	}

	// Artists
	if artists, ok := art.Descripts["artist"]; ok && len(artists) > 0 && artists[0] != "" {
		m.Artists = "|" + strings.Join(artists, "|") + "|"
	} else {
		m.Artists = "|N/A|"
	}

	// Groups
	if groups, ok := art.Descripts["group"]; ok && len(groups) > 0 && groups[0] != "" {
		m.Groups = "|" + strings.Join(groups, "|") + "|"
	}

	// Characters
	if chars, ok := art.Descripts["character"]; ok && len(chars) > 0 && chars[0] != "" {
		m.Characters = "|" + strings.Join(chars, "|") + "|"
	}

	// Series (parody)
	if parody, ok := art.Descripts["parody"]; ok && len(parody) > 0 && parody[0] != "" {
		m.Series = "|" + strings.Join(parody, "|") + "|"
	}

	// Language: pick first non-"translated" language
	m.Language = "n/a"
	if langs, ok := art.Descripts["language"]; ok {
		for _, l := range langs {
			if l != "translated" {
				m.Language = l
				break
			}
		}
	}

	// Tags: female→female:, male→male:, misc/other/mixed→plain
	var tags []string
	for _, category := range []string{"female", "male", "misc", "other", "mixed"} {
		if catTags, ok := art.Descripts[category]; ok {
			for _, tag := range catTags {
				tags = append(tags, normalizeEHTag(tag, category))
			}
		}
	}
	if len(tags) > 0 {
		m.Tags = "|" + strings.Join(tags, "|") + "|"
	}

	return m
}

func normalizeEHTag(tag, category string) string {
	t := strings.TrimSpace(tag)
	switch t {
	case "lolicon":
		t = "loli"
	case "shotacon":
		t = "shota"
	}
	switch category {
	case "female":
		return "female:" + t
	case "male":
		return "male:" + t
	default:
		return t
	}
}

// mergeEHIntoModel supplements a Hitomi-sourced model with ExHentai data.
func mergeEHIntoModel(model *HitomiColumnModel, eh *EHArticle) {
	model.EHash = getEHHash(eh)
	model.Uploader = eh.Uploader

	if eh.Published != "" {
		for _, layout := range []string{"2006-01-02 15:04", "2006-01-02 15:04:05"} {
			if t, err := time.Parse(layout, strings.TrimSpace(eh.Published)); err == nil {
				model.Published = &t
				break
			}
		}
	}

	if eh.Files != "" {
		parts := strings.SplitN(eh.Files, " ", 2)
		if f, err := strconv.Atoi(parts[0]); err == nil {
			model.Files = f
		}
	}

	if strings.HasPrefix(eh.Title, "(") {
		if idx := strings.Index(eh.Title, ")"); idx > 1 {
			model.Class = eh.Title[1:idx]
		}
	}
}

// getEHCookie returns the ExHentai cookie from env var or default.
func getEHCookie() string {
	if cookie := os.Getenv("COOKIE"); cookie != "" {
		return cookie
	}
	return defaultEHCookie
}

// mergeExHentai runs ExHentai sync and merges results into the model list.
// Three cases:
//   - Hitomi model exists in current batch + EH → supplement hitomi model
//   - Hitomi model exists in DB only + EH → read DB record, supplement
//   - EH only → create new model (ExistOnHitomi=0)
func mergeExHentai(db *sql.DB, latestID int, models []*HitomiColumnModel, ids []int) ([]*HitomiColumnModel, []int) {
	cookie := getEHCookie()
	ehArticles := syncExHentai(cookie, latestID)

	ehByID := make(map[int]*EHArticle, len(ehArticles))
	for _, a := range ehArticles {
		if id := getEHID(a); id > 0 {
			ehByID[id] = a
		}
	}

	// Supplement models from current hitomi batch
	hitomiIDs := make(map[int]bool, len(models))
	for _, m := range models {
		hitomiIDs[m.ID] = true
		if eh, ok := ehByID[m.ID]; ok {
			mergeEHIntoModel(m, eh)
		}
	}

	// Remaining EH IDs not in current hitomi batch
	var remainIDs []int
	for id := range ehByID {
		if !hitomiIDs[id] {
			remainIDs = append(remainIDs, id)
		}
	}

	// Check DB for existing hitomi records
	dbExisting, err := getExistingByIDs(db, remainIDs)
	if err != nil {
		log.Fatalf("Failed to query DB for EH merge: %v", err)
	}

	dbSupplemented, ehOnly := 0, 0
	for _, id := range remainIDs {
		eh := ehByID[id]
		if existing, ok := dbExisting[id]; ok {
			mergeEHIntoModel(existing, eh)
			models = append(models, existing)
			ids = append(ids, id)
			dbSupplemented++
		} else {
			m := ehArticleToColumnModel(eh)
			models = append(models, m)
			ids = append(ids, m.ID)
			ehOnly++
		}
	}

	log.Printf("EH merge: %d new-hitomi, %d db-hitomi, %d EH-only",
		len(ehByID)-len(remainIDs), dbSupplemented, ehOnly)

	return models, ids
}
