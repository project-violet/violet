package main

import (
	"bufio"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"
)

var stopwords = map[string]struct{}{
	"그거": {}, "그게": {}, "그건": {}, "그냥": {}, "그런": {}, "그럼": {}, "그래": {}, "그렇게": {},
	"나는": {}, "내가": {}, "있는": {}, "네가": {}, "이거": {}, "이게": {}, "이건": {},
	"저거": {}, "저게": {}, "저건": {}, "정말": {}, "진짜": {}, "아니": {}, "아직": {},
	"지금": {}, "여기": {}, "저기": {}, "이제": {}, "오늘": {}, "계속": {}, "대체": {},
	"역자": {}, "식자": {}, "번역": {}, "편집": {}, "식질": {}, "스캔": {}, "출처": {},
}

var koreanSuffixes = []string{
	"에게서", "에게", "에서", "으로", "부터", "까지", "처럼", "보다",
	"라고", "하고", "이나", "거나", "이랑", "랑",
	"은", "는", "이", "가", "을", "를", "에", "의", "도", "과", "와", "만", "로",
}

type rawArticle struct {
	Pages []rawPage `json:"pages"`
}

type rawPage struct {
	Dialogues []rawDialogue `json:"dialogues"`
}

type rawDialogue struct {
	Text       string  `json:"text"`
	Confidence float64 `json:"confidence"`
}

type workDocument struct {
	ArticleID      string
	TotalPages     int
	DialogueCount  int
	CharacterCount int
	TermCounts     map[string]int
}

type keywordRow struct {
	ArticleID      string  `json:"article_id"`
	Rank           int     `json:"rank"`
	Keyword        string  `json:"keyword"`
	Score          float64 `json:"score"`
	TF             int     `json:"tf"`
	DF             int     `json:"df"`
	TotalPages     int     `json:"total_pages"`
	DialogueCount  int     `json:"dialogue_count"`
	CharacterCount int     `json:"char_count"`
}

type options struct {
	rawDir           string
	outputPath       string
	jsonOutputPath   string
	topK             int
	minConfidence    float64
	minTokenLen      int
	minDF            int
	minTF            int
	keepLatin        bool
	maxDFRatio       float64
	limit            int
	loadWorkers      int
	progressInterval int
}

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "extract":
			if err := runExtract(parseFlags("extract", os.Args[2:])); err != nil {
				fatal(err)
			}
			return
		case "similar":
			if err := runSimilar(os.Args[2:]); err != nil {
				fatal(err)
			}
			return
		case "serve":
			if err := runServe(os.Args[2:]); err != nil {
				fatal(err)
			}
			return
		default:
			if !strings.HasPrefix(os.Args[1], "-") {
				fatal(fmt.Errorf("unknown command %q; use extract, similar, or serve", os.Args[1]))
			}
		}
	}

	if err := runExtract(parseFlags("extract", os.Args[1:])); err != nil {
		fatal(err)
	}
}

func runExtract(opts options) error {
	start := time.Now()

	docs, err := loadDocuments(opts)
	if err != nil {
		return err
	}
	rows := rankWorkKeywords(docs, opts.topK, opts.minDF, opts.minTF, opts.maxDFRatio)
	if err := writeKeywordCSV(rows, opts.outputPath); err != nil {
		return err
	}
	if opts.jsonOutputPath != "" {
		if err := writeKeywordJSON(rows, opts.jsonOutputPath); err != nil {
			return err
		}
	}
	fmt.Printf("documents=%d keyword_rows=%d output=%s elapsed=%.2fs\n", len(docs), len(rows), opts.outputPath, time.Since(start).Seconds())
	return nil
}

func parseFlags(name string, args []string) options {
	var opts options
	flags := flag.NewFlagSet(name, flag.ExitOnError)
	flags.StringVar(&opts.rawDir, "raw", filepath.Join("..", "raw"), "Directory containing raw/*.json OCR files.")
	flags.StringVar(&opts.outputPath, "output", filepath.Join("..", "..", "artifacts", "dialogue-explore", "work-keywords-go.csv"), "CSV output path.")
	flags.StringVar(&opts.jsonOutputPath, "json-output", "", "Optional grouped JSON output path.")
	flags.IntVar(&opts.topK, "top-k", 30, "Keywords per work.")
	flags.Float64Var(&opts.minConfidence, "min-confidence", 0.5, "Minimum OCR confidence to include.")
	flags.IntVar(&opts.minTokenLen, "min-token-len", 2, "Minimum token length.")
	flags.IntVar(&opts.minDF, "min-df", 1, "Minimum document frequency for a keyword.")
	flags.IntVar(&opts.minTF, "min-tf", 2, "Minimum term frequency within a work.")
	flags.BoolVar(&opts.keepLatin, "keep-latin", false, "Keep non-Korean latin tokens.")
	flags.Float64Var(&opts.maxDFRatio, "max-df-ratio", 0.4, "Drop terms appearing in more than this ratio of works. Use 1.0 to disable.")
	flags.IntVar(&opts.limit, "limit", 0, "Read only the first N raw files for quick experiments.")
	flags.IntVar(&opts.loadWorkers, "load-workers", 16, "Parallel raw JSON loading workers.")
	flags.IntVar(&opts.progressInterval, "progress-interval", 5000, "Print progress every N files; 0 disables.")
	flags.Parse(args)

	if opts.topK < 1 {
		fatal(fmt.Errorf("--top-k must be >= 1"))
	}
	if opts.minTokenLen < 1 {
		fatal(fmt.Errorf("--min-token-len must be >= 1"))
	}
	if opts.minDF < 1 {
		fatal(fmt.Errorf("--min-df must be >= 1"))
	}
	if opts.minTF < 1 {
		fatal(fmt.Errorf("--min-tf must be >= 1"))
	}
	if opts.loadWorkers < 1 {
		opts.loadWorkers = 1
	}
	return opts
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "ERROR:", err)
	os.Exit(1)
}

func iterRawFiles(rawDir string, limit int) ([]string, error) {
	entries, err := os.ReadDir(rawDir)
	if err != nil {
		return nil, err
	}
	files := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasSuffix(strings.ToLower(name), ".json") {
			files = append(files, filepath.Join(rawDir, name))
		}
	}
	sort.Strings(files)
	if limit > 0 && limit < len(files) {
		files = files[:limit]
	}
	return files, nil
}

func loadDocuments(opts options) ([]workDocument, error) {
	files, err := iterRawFiles(opts.rawDir, opts.limit)
	if err != nil {
		return nil, err
	}

	jobs := make(chan string, opts.loadWorkers*2)
	results := make(chan loadResult, opts.loadWorkers*2)
	var wg sync.WaitGroup
	for i := 0; i < opts.loadWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for path := range jobs {
				doc, err := loadWorkDocument(path, opts.minConfidence, opts.minTokenLen, opts.keepLatin)
				results <- loadResult{document: doc, err: err}
			}
		}()
	}

	go func() {
		for _, path := range files {
			jobs <- path
		}
		close(jobs)
		wg.Wait()
		close(results)
	}()

	completed := 0
	docs := make([]workDocument, 0, len(files))
	for result := range results {
		completed++
		if result.err != nil {
			return nil, result.err
		}
		if result.document != nil && len(result.document.TermCounts) > 0 {
			docs = append(docs, *result.document)
		}
		if opts.progressInterval > 0 && completed%opts.progressInterval == 0 {
			fmt.Printf("[load] %d/%d files, usable=%d\n", completed, len(files), len(docs))
		}
	}
	sort.Slice(docs, func(i, j int) bool {
		return numericLess(docs[i].ArticleID, docs[j].ArticleID)
	})
	return docs, nil
}

type loadResult struct {
	document *workDocument
	err      error
}

func loadWorkDocument(path string, minConfidence float64, minTokenLen int, keepLatin bool) (*workDocument, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var article rawArticle
	if err := json.Unmarshal(data, &article); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	doc := &workDocument{
		ArticleID:  strings.TrimSuffix(filepath.Base(path), filepath.Ext(path)),
		TotalPages: len(article.Pages),
		TermCounts: make(map[string]int),
	}
	for _, page := range article.Pages {
		for _, dialogue := range page.Dialogues {
			if dialogue.Confidence < minConfidence {
				continue
			}
			text := strings.TrimSpace(dialogue.Text)
			if text == "" {
				continue
			}
			doc.DialogueCount++
			doc.CharacterCount += utf8.RuneCountInString(text)
			for _, token := range tokenizeText(text, minTokenLen, keepLatin) {
				doc.TermCounts[token]++
			}
		}
	}
	return doc, nil
}

func tokenizeText(text string, minTokenLen int, keepLatin bool) []string {
	tokens := make([]string, 0, 4)
	runes := []rune(strings.ToLower(text))
	for i := 0; i < len(runes); {
		r := runes[i]
		switch {
		case isHangul(r):
			start := i
			for i < len(runes) && isHangul(runes[i]) {
				i++
			}
			token := normalizeToken(string(runes[start:i]))
			if validToken(token, minTokenLen, keepLatin) {
				tokens = append(tokens, token)
			}
		case isASCIILetter(r):
			start := i
			for i < len(runes) && (isASCIILetter(runes[i]) || isASCIIDigit(runes[i]) || runes[i] == '_') {
				i++
			}
			token := string(runes[start:i])
			if validToken(token, minTokenLen, keepLatin) {
				tokens = append(tokens, token)
			}
		case isASCIIDigit(r):
			start := i
			i++
			if i < len(runes) && isASCIILetter(runes[i]) {
				for i < len(runes) && (isASCIILetter(runes[i]) || isASCIIDigit(runes[i]) || runes[i] == '_') {
					i++
				}
				token := string(runes[start:i])
				if validToken(token, minTokenLen, keepLatin) {
					tokens = append(tokens, token)
				}
			}
		default:
			i++
		}
	}
	return tokens
}

func normalizeToken(token string) string {
	if !isAllHangul(token) {
		return token
	}
	for _, suffix := range koreanSuffixes {
		if strings.HasSuffix(token, suffix) && utf8.RuneCountInString(token)-utf8.RuneCountInString(suffix) >= 2 {
			return strings.TrimSuffix(token, suffix)
		}
	}
	return token
}

func validToken(token string, minTokenLen int, keepLatin bool) bool {
	if utf8.RuneCountInString(token) < minTokenLen {
		return false
	}
	if _, ok := stopwords[token]; ok {
		return false
	}
	hasHangul := false
	for _, r := range token {
		if unicode.IsDigit(r) {
			return false
		}
		if isHangul(r) {
			hasHangul = true
		}
	}
	return keepLatin || hasHangul
}

func isAllHangul(token string) bool {
	for _, r := range token {
		if !isHangul(r) {
			return false
		}
	}
	return token != ""
}

func isHangul(r rune) bool {
	return r >= 0xAC00 && r <= 0xD7A3
}

func isASCIILetter(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
}

func isASCIIDigit(r rune) bool {
	return r >= '0' && r <= '9'
}

func rankWorkKeywords(docs []workDocument, topK int, minDF int, minTF int, maxDFRatio float64) []keywordRow {
	df := make(map[string]int)
	for _, doc := range docs {
		for term := range doc.TermCounts {
			df[term]++
		}
	}

	rows := make([]keywordRow, 0, len(docs)*topK)
	docCount := float64(len(docs))
	for _, doc := range docs {
		candidates := make([]keywordRow, 0, len(doc.TermCounts))
		for term, tf := range doc.TermCounts {
			termDF := df[term]
			if termDF < minDF || tf < minTF {
				continue
			}
			if maxDFRatio < 1.0 && docCount > 0 && float64(termDF)/docCount > maxDFRatio {
				continue
			}
			idf := math.Log((docCount+1.0)/(float64(termDF)+1.0)) + 1.0
			score := (1.0 + math.Log(float64(tf))) * idf
			candidates = append(candidates, keywordRow{
				ArticleID:      doc.ArticleID,
				Keyword:        term,
				Score:          score,
				TF:             tf,
				DF:             termDF,
				TotalPages:     doc.TotalPages,
				DialogueCount:  doc.DialogueCount,
				CharacterCount: doc.CharacterCount,
			})
		}
		sort.Slice(candidates, func(i, j int) bool {
			if candidates[i].Score != candidates[j].Score {
				return candidates[i].Score > candidates[j].Score
			}
			if candidates[i].TF != candidates[j].TF {
				return candidates[i].TF > candidates[j].TF
			}
			if candidates[i].DF != candidates[j].DF {
				return candidates[i].DF < candidates[j].DF
			}
			return candidates[i].Keyword < candidates[j].Keyword
		})
		if len(candidates) > topK {
			candidates = candidates[:topK]
		}
		for i := range candidates {
			candidates[i].Rank = i + 1
			rows = append(rows, candidates[i])
		}
	}
	return rows
}

func writeKeywordCSV(rows []keywordRow, outputPath string) error {
	if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
		return err
	}
	file, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer file.Close()

	buffered := bufio.NewWriterSize(file, 1<<20)
	writer := csv.NewWriter(buffered)
	if err := writer.Write([]string{"article_id", "rank", "keyword", "score", "tf", "df", "total_pages", "dialogue_count", "char_count"}); err != nil {
		return err
	}
	for _, row := range rows {
		record := []string{
			row.ArticleID,
			strconv.Itoa(row.Rank),
			row.Keyword,
			strconv.FormatFloat(row.Score, 'f', 6, 64),
			strconv.Itoa(row.TF),
			strconv.Itoa(row.DF),
			strconv.Itoa(row.TotalPages),
			strconv.Itoa(row.DialogueCount),
			strconv.Itoa(row.CharacterCount),
		}
		if err := writer.Write(record); err != nil {
			return err
		}
	}
	writer.Flush()
	if err := writer.Error(); err != nil {
		return err
	}
	return buffered.Flush()
}

func writeKeywordJSON(rows []keywordRow, outputPath string) error {
	if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
		return err
	}
	grouped := make(map[string][]keywordRow)
	for _, row := range rows {
		grouped[row.ArticleID] = append(grouped[row.ArticleID], row)
	}
	data, err := json.MarshalIndent(grouped, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(outputPath, data, 0o644)
}

func numericLess(left, right string) bool {
	leftInt, leftErr := strconv.Atoi(left)
	rightInt, rightErr := strconv.Atoi(right)
	if leftErr == nil && rightErr == nil {
		return leftInt < rightInt
	}
	return left < right
}
