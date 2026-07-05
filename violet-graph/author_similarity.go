package main

import (
	"bufio"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type authorWorkRow struct {
	AuthorKey          string
	AuthorName         string
	ArticleID          string
	ArticleArtistCount int
	ContributionWeight float64
}

type authorSimilarityOptions struct {
	inputPath           string
	authorWorkPath      string
	outputPath          string
	profileMode         string
	profileMinKeywordDF int
	topN                int
	topKeywords         int
	maxKeywordAuthors   int
	minSharedKeywords   int
	sharedKeywords      int
	minAuthorWorks      int
	workers             int
	progressInterval    int
}

type authorSimilarityParams struct {
	ProfileMode         string `json:"profile_mode"`
	ProfileMinKeywordDF int    `json:"profile_min_keyword_df"`
	TopN                int    `json:"top_n"`
	TopKeywords         int    `json:"top_keywords"`
	MaxKeywordAuthors   int    `json:"max_keyword_authors"`
	MinSharedKeywords   int    `json:"min_shared_keywords"`
	SharedKeywords      int    `json:"shared_keywords"`
	MinAuthorWorks      int    `json:"min_author_works"`
	Workers             int    `json:"workers"`
}

const (
	authorProfileModeCurrent   = "current"
	authorProfileModeWorkScore = "work-score"
)

type authorSimilarityResult struct {
	GeneratedAt  string                   `json:"generated_at,omitempty"`
	Params       authorSimilarityParams   `json:"params"`
	AuthorCount  int                      `json:"author_count"`
	KeywordCount int                      `json:"keyword_count"`
	Authors      []authorSimilarityAuthor `json:"authors"`
}

type authorSimilarityAuthor struct {
	AuthorKey        string                     `json:"author_key"`
	AuthorName       string                     `json:"author_name"`
	WorkCount        int                        `json:"work_count"`
	MatchedWorkCount int                        `json:"matched_work_count"`
	KeywordCount     int                        `json:"keyword_count"`
	SimilarAuthors   []authorSimilarityNeighbor `json:"similar_authors"`
}

type authorSimilarityNeighbor struct {
	AuthorKey          string                `json:"author_key"`
	AuthorName         string                `json:"author_name"`
	WorkCount          int                   `json:"work_count"`
	Score              float64               `json:"score"`
	SharedKeywordCount int                   `json:"shared_keyword_count"`
	SharedKeywords     []authorSharedKeyword `json:"shared_keywords,omitempty"`
}

type authorSharedKeyword struct {
	Keyword string  `json:"keyword"`
	Score   float64 `json:"score"`
}

type authorProfile struct {
	key              string
	name             string
	workCount        int
	matchedWorkCount int
	seenWorks        map[string]struct{}
	rawTerms         map[string]*authorTermAccumulator
	terms            []authorTerm
	termByKeyword    map[string]authorTerm
	norm             float64
}

type authorTermAccumulator struct {
	rawScore float64
	workHits int
	tf       int
}

type authorTerm struct {
	keyword  string
	weight   float64
	rawScore float64
	workHits int
	tf       int
}

type authorPosting struct {
	authorIndex int
	weight      float64
}

type authorCandidateAccumulator struct {
	dot    float64
	shared int
}

type authorNeighborCandidate struct {
	authorIndex int
	score       float64
	shared      int
}

func runAuthorSimilarity(args []string) error {
	opts := parseAuthorSimilarityFlags(args)
	start := time.Now()

	graphStart := time.Now()
	rows, err := readKeywordCSV(opts.inputPath)
	if err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "[author-similarity] graph_rows=%d elapsed=%.2fs\n", len(rows), time.Since(graphStart).Seconds())

	authorStart := time.Now()
	authorWorks, err := readAuthorWorkCSV(opts.authorWorkPath)
	if err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "[author-similarity] author_work_rows=%d elapsed=%.2fs\n", len(authorWorks), time.Since(authorStart).Seconds())

	buildStart := time.Now()
	result := buildAuthorSimilarity(rows, authorWorks, opts)
	result.GeneratedAt = time.Now().UTC().Format(time.RFC3339)
	fmt.Fprintf(os.Stderr, "[author-similarity] authors=%d keywords=%d build_elapsed=%.2fs\n", result.AuthorCount, result.KeywordCount, time.Since(buildStart).Seconds())

	writeStart := time.Now()
	if err := writeAuthorSimilarityJSON(result, opts.outputPath); err != nil {
		return err
	}
	fmt.Fprintf(os.Stderr, "[author-similarity] write_elapsed=%.2fs\n", time.Since(writeStart).Seconds())
	fmt.Printf("authors=%d output=%s elapsed=%.2fs\n", result.AuthorCount, opts.outputPath, time.Since(start).Seconds())
	return nil
}

func parseAuthorSimilarityFlags(args []string) authorSimilarityOptions {
	var opts authorSimilarityOptions
	flags := flag.NewFlagSet("author-similarity", flag.ExitOnError)
	flags.StringVar(&opts.inputPath, "input", "graph.csv", "Keyword CSV from extract.")
	flags.StringVar(&opts.authorWorkPath, "author-work", "author_work.csv", "Author-to-work CSV from scripts/export_author_work_map.py.")
	flags.StringVar(&opts.outputPath, "output", "author_similarity.json", "JSON output path.")
	flags.StringVar(&opts.profileMode, "profile-mode", authorProfileModeCurrent, "Author profile mode: current or work-score.")
	flags.IntVar(&opts.profileMinKeywordDF, "profile-min-keyword-df", 5, "Minimum global keyword DF for work-score profile keywords.")
	flags.IntVar(&opts.topN, "top-n", 20, "Similar authors to keep per author.")
	flags.IntVar(&opts.topKeywords, "top-keywords", 100, "Profile keywords to keep per author.")
	flags.IntVar(&opts.maxKeywordAuthors, "max-keyword-authors", 500, "Drop profile keywords that appear for more than this many authors. Use 0 to disable.")
	flags.IntVar(&opts.minSharedKeywords, "min-shared-keywords", 2, "Minimum shared profile keywords for an author pair.")
	flags.IntVar(&opts.sharedKeywords, "shared-keywords", 5, "Shared keywords to include for each neighbor.")
	flags.IntVar(&opts.minAuthorWorks, "min-author-works", 1, "Drop authors with fewer than this many works.")
	flags.IntVar(&opts.workers, "workers", runtime.NumCPU(), "Parallel similarity workers.")
	flags.IntVar(&opts.progressInterval, "progress-interval", 5000, "Print progress every N authors; 0 disables.")
	flags.Parse(args)
	return normalizeAuthorSimilarityOptions(opts)
}

func normalizeAuthorSimilarityOptions(opts authorSimilarityOptions) authorSimilarityOptions {
	opts.profileMode = normalizeAuthorProfileMode(opts.profileMode)
	if opts.profileMinKeywordDF < 1 {
		opts.profileMinKeywordDF = 5
	}
	if opts.topN < 1 {
		opts.topN = 20
	}
	if opts.topKeywords < 1 {
		opts.topKeywords = 100
	}
	if opts.maxKeywordAuthors < 0 {
		opts.maxKeywordAuthors = 0
	}
	if opts.minSharedKeywords < 1 {
		opts.minSharedKeywords = 1
	}
	if opts.sharedKeywords < 0 {
		opts.sharedKeywords = 0
	}
	if opts.minAuthorWorks < 1 {
		opts.minAuthorWorks = 1
	}
	if opts.workers < 1 {
		opts.workers = 1
	}
	return opts
}

func normalizeAuthorProfileMode(value string) string {
	switch strings.TrimSpace(strings.ToLower(value)) {
	case authorProfileModeWorkScore, "work_score", "workscore":
		return authorProfileModeWorkScore
	default:
		return authorProfileModeCurrent
	}
}

func readAuthorWorkCSV(inputPath string) ([]authorWorkRow, error) {
	file, err := os.Open(inputPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader := csv.NewReader(bufio.NewReaderSize(file, 1<<20))
	reader.FieldsPerRecord = -1
	header, err := reader.Read()
	if err != nil {
		return nil, err
	}
	index := make(map[string]int, len(header))
	for i, name := range header {
		index[strings.TrimPrefix(name, "\ufeff")] = i
	}

	rows := make([]authorWorkRow, 0, 1024)
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		row := authorWorkRow{
			AuthorKey:          getCSVField(record, index, "author_key"),
			AuthorName:         getCSVField(record, index, "author_name"),
			ArticleID:          getCSVField(record, index, "article_id"),
			ArticleArtistCount: parseCSVInt(record, index, "article_artist_count"),
			ContributionWeight: parseCSVFloat(record, index, "contribution_weight"),
		}
		if row.AuthorKey == "" || row.ArticleID == "" {
			continue
		}
		if row.ContributionWeight <= 0 {
			row.ContributionWeight = 1
		}
		rows = append(rows, row)
	}
	return rows, nil
}

func buildAuthorSimilarity(rows []keywordRow, authorWorks []authorWorkRow, opts authorSimilarityOptions) authorSimilarityResult {
	opts = normalizeAuthorSimilarityOptions(opts)
	var profiles []*authorProfile
	if opts.profileMode == authorProfileModeWorkScore {
		profiles = buildAuthorProfilesFromWorkScores(newKeywordIndex(rows), authorWorks, opts)
	} else {
		articleRows := keywordRowsByArticle(rows)
		profiles = buildAuthorProfiles(articleRows, authorWorks, opts)
	}
	keywordCount := finalizeAuthorProfiles(profiles, opts)
	postings := buildAuthorPostings(profiles)
	authors := computeAuthorSimilarities(profiles, postings, opts)
	return authorSimilarityResult{
		Params:       authorSimilarityParamsFromOptions(opts),
		AuthorCount:  len(authors),
		KeywordCount: keywordCount,
		Authors:      authors,
	}
}

func authorSimilarityParamsFromOptions(opts authorSimilarityOptions) authorSimilarityParams {
	return authorSimilarityParams{
		ProfileMode:         opts.profileMode,
		ProfileMinKeywordDF: opts.profileMinKeywordDF,
		TopN:                opts.topN,
		TopKeywords:         opts.topKeywords,
		MaxKeywordAuthors:   opts.maxKeywordAuthors,
		MinSharedKeywords:   opts.minSharedKeywords,
		SharedKeywords:      opts.sharedKeywords,
		MinAuthorWorks:      opts.minAuthorWorks,
		Workers:             opts.workers,
	}
}

func keywordRowsByArticle(rows []keywordRow) map[string][]keywordRow {
	articleRows := make(map[string][]keywordRow)
	for _, row := range rows {
		if row.ArticleID == "" || row.Keyword == "" {
			continue
		}
		articleRows[row.ArticleID] = append(articleRows[row.ArticleID], row)
	}
	return articleRows
}

func buildAuthorProfiles(articleRows map[string][]keywordRow, authorWorks []authorWorkRow, opts authorSimilarityOptions) []*authorProfile {
	profileByKey := make(map[string]*authorProfile)
	for _, authorWork := range authorWorks {
		if authorWork.AuthorKey == "" || authorWork.ArticleID == "" {
			continue
		}
		profile := profileByKey[authorWork.AuthorKey]
		if profile == nil {
			profile = &authorProfile{
				key:       authorWork.AuthorKey,
				name:      authorWork.AuthorName,
				seenWorks: make(map[string]struct{}),
				rawTerms:  make(map[string]*authorTermAccumulator),
			}
			profileByKey[authorWork.AuthorKey] = profile
		}
		if profile.name == "" && authorWork.AuthorName != "" {
			profile.name = authorWork.AuthorName
		}
		if _, exists := profile.seenWorks[authorWork.ArticleID]; exists {
			continue
		}
		profile.seenWorks[authorWork.ArticleID] = struct{}{}
		profile.workCount++

		workRows := articleRows[authorWork.ArticleID]
		if len(workRows) == 0 {
			continue
		}
		profile.matchedWorkCount++
		weight := authorWork.ContributionWeight
		if weight <= 0 {
			weight = 1
		}
		for _, row := range workRows {
			term := profile.rawTerms[row.Keyword]
			if term == nil {
				term = &authorTermAccumulator{}
				profile.rawTerms[row.Keyword] = term
			}
			term.rawScore += keywordWeight(row) * weight
			term.workHits++
			term.tf += row.TF
		}
	}

	profiles := make([]*authorProfile, 0, len(profileByKey))
	for _, profile := range profileByKey {
		if profile.workCount < opts.minAuthorWorks || len(profile.rawTerms) == 0 {
			continue
		}
		profiles = append(profiles, profile)
	}
	sort.Slice(profiles, func(i, j int) bool {
		return profiles[i].key < profiles[j].key
	})
	return profiles
}

func buildAuthorProfilesFromWorkScores(index keywordIndex, authorWorks []authorWorkRow, opts authorSimilarityOptions) []*authorProfile {
	profileByKey := make(map[string]*authorProfile)
	for _, authorWork := range authorWorks {
		if authorWork.AuthorKey == "" || authorWork.ArticleID == "" {
			continue
		}
		profile := profileByKey[authorWork.AuthorKey]
		if profile == nil {
			profile = &authorProfile{
				key:       authorWork.AuthorKey,
				name:      authorWork.AuthorName,
				seenWorks: make(map[string]struct{}),
				rawTerms:  make(map[string]*authorTermAccumulator),
			}
			profileByKey[authorWork.AuthorKey] = profile
		}
		if profile.name == "" && authorWork.AuthorName != "" {
			profile.name = authorWork.AuthorName
		}
		if _, exists := profile.seenWorks[authorWork.ArticleID]; exists {
			continue
		}
		profile.seenWorks[authorWork.ArticleID] = struct{}{}
		profile.workCount++

		workRows := index.works[authorWork.ArticleID]
		if len(workRows) == 0 {
			continue
		}
		profile.matchedWorkCount++
		for _, row := range workRows {
			keywordDF := index.actualDF[row.Keyword]
			if keywordDF < opts.profileMinKeywordDF {
				continue
			}
			term := profile.rawTerms[row.Keyword]
			if term == nil {
				term = &authorTermAccumulator{}
				profile.rawTerms[row.Keyword] = term
			}
			term.rawScore += row.Score
			term.workHits++
			term.tf += row.TF
		}
	}

	profiles := make([]*authorProfile, 0, len(profileByKey))
	for _, profile := range profileByKey {
		if profile.workCount < opts.minAuthorWorks || len(profile.rawTerms) == 0 {
			continue
		}
		profiles = append(profiles, profile)
	}
	sort.Slice(profiles, func(i, j int) bool {
		return profiles[i].key < profiles[j].key
	})
	return profiles
}

func finalizeAuthorProfiles(profiles []*authorProfile, opts authorSimilarityOptions) int {
	authorDF := make(map[string]int)
	for _, profile := range profiles {
		for keyword := range profile.rawTerms {
			authorDF[keyword]++
		}
	}

	authorCount := float64(len(profiles))
	for _, profile := range profiles {
		profile.terms = profile.terms[:0]
		for keyword, acc := range profile.rawTerms {
			df := authorDF[keyword]
			if df == 0 {
				continue
			}
			idf := math.Log((authorCount+1.0)/(float64(df)+1.0)) + 1.0
			coverage := 1.0
			if profile.matchedWorkCount > 0 {
				coverage = float64(acc.workHits) / float64(profile.matchedWorkCount)
			}
			weight := acc.rawScore * idf * math.Sqrt(coverage)
			if weight <= 0 {
				continue
			}
			profile.terms = append(profile.terms, authorTerm{
				keyword:  keyword,
				weight:   weight,
				rawScore: acc.rawScore,
				workHits: acc.workHits,
				tf:       acc.tf,
			})
		}
		if opts.profileMode == authorProfileModeWorkScore {
			sortAuthorTermsByWorkScore(profile.terms)
		} else {
			sortAuthorTerms(profile.terms)
		}
		if len(profile.terms) > opts.topKeywords {
			profile.terms = profile.terms[:opts.topKeywords]
		}
	}

	termAuthorCount := make(map[string]int)
	for _, profile := range profiles {
		for _, term := range profile.terms {
			termAuthorCount[term.keyword]++
		}
	}

	keptKeywords := make(map[string]struct{})
	for keyword, count := range termAuthorCount {
		if opts.maxKeywordAuthors > 0 && count > opts.maxKeywordAuthors {
			continue
		}
		keptKeywords[keyword] = struct{}{}
	}

	for _, profile := range profiles {
		filtered := profile.terms[:0]
		profile.termByKeyword = make(map[string]authorTerm)
		profile.norm = 0
		for _, term := range profile.terms {
			if _, ok := keptKeywords[term.keyword]; !ok {
				continue
			}
			filtered = append(filtered, term)
			profile.termByKeyword[term.keyword] = term
			profile.norm += term.weight * term.weight
		}
		profile.terms = filtered
		profile.norm = math.Sqrt(profile.norm)
	}
	return len(keptKeywords)
}

func sortAuthorTerms(terms []authorTerm) {
	sort.Slice(terms, func(i, j int) bool {
		if terms[i].weight != terms[j].weight {
			return terms[i].weight > terms[j].weight
		}
		if terms[i].rawScore != terms[j].rawScore {
			return terms[i].rawScore > terms[j].rawScore
		}
		if terms[i].workHits != terms[j].workHits {
			return terms[i].workHits > terms[j].workHits
		}
		return terms[i].keyword < terms[j].keyword
	})
}

func sortAuthorTermsByWorkScore(terms []authorTerm) {
	sort.Slice(terms, func(i, j int) bool {
		if terms[i].rawScore != terms[j].rawScore {
			return terms[i].rawScore > terms[j].rawScore
		}
		if terms[i].tf != terms[j].tf {
			return terms[i].tf > terms[j].tf
		}
		if terms[i].workHits != terms[j].workHits {
			return terms[i].workHits > terms[j].workHits
		}
		return terms[i].keyword < terms[j].keyword
	})
}

func buildAuthorPostings(profiles []*authorProfile) map[string][]authorPosting {
	postings := make(map[string][]authorPosting)
	for authorIndex, profile := range profiles {
		if profile.norm <= 0 {
			continue
		}
		for _, term := range profile.terms {
			postings[term.keyword] = append(postings[term.keyword], authorPosting{
				authorIndex: authorIndex,
				weight:      term.weight,
			})
		}
	}
	for keyword, list := range postings {
		sort.Slice(list, func(i, j int) bool {
			if list[i].weight != list[j].weight {
				return list[i].weight > list[j].weight
			}
			return profiles[list[i].authorIndex].key < profiles[list[j].authorIndex].key
		})
		postings[keyword] = list
	}
	return postings
}

func computeAuthorSimilarities(
	profiles []*authorProfile,
	postings map[string][]authorPosting,
	opts authorSimilarityOptions,
) []authorSimilarityAuthor {
	authors := make([]authorSimilarityAuthor, len(profiles))
	jobs := make(chan int, opts.workers*2)
	var completed atomic.Int64
	var wg sync.WaitGroup
	for worker := 0; worker < opts.workers; worker++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for authorIndex := range jobs {
				authors[authorIndex] = buildAuthorSimilarityAuthor(authorIndex, profiles, postings, opts)
				if opts.progressInterval > 0 {
					done := completed.Add(1)
					if done%int64(opts.progressInterval) == 0 {
						fmt.Fprintf(os.Stderr, "[author-similarity] scored_authors=%d/%d\n", done, len(profiles))
					}
				}
			}
		}()
	}
	for authorIndex := range profiles {
		jobs <- authorIndex
	}
	close(jobs)
	wg.Wait()
	return authors
}

func buildAuthorSimilarityAuthor(
	authorIndex int,
	profiles []*authorProfile,
	postings map[string][]authorPosting,
	opts authorSimilarityOptions,
) authorSimilarityAuthor {
	profile := profiles[authorIndex]
	result := authorSimilarityAuthor{
		AuthorKey:        profile.key,
		AuthorName:       profile.name,
		WorkCount:        profile.workCount,
		MatchedWorkCount: profile.matchedWorkCount,
		KeywordCount:     len(profile.terms),
		SimilarAuthors:   []authorSimilarityNeighbor{},
	}
	if profile.norm <= 0 {
		return result
	}

	candidates := make(map[int]authorCandidateAccumulator)
	for _, term := range profile.terms {
		for _, posting := range postings[term.keyword] {
			if posting.authorIndex == authorIndex {
				continue
			}
			acc := candidates[posting.authorIndex]
			acc.dot += term.weight * posting.weight
			acc.shared++
			candidates[posting.authorIndex] = acc
		}
	}

	topCandidates := make([]authorNeighborCandidate, 0, opts.topN)
	for otherIndex, acc := range candidates {
		if acc.shared < opts.minSharedKeywords {
			continue
		}
		other := profiles[otherIndex]
		if other.norm <= 0 {
			continue
		}
		score := acc.dot / (profile.norm * other.norm)
		if score <= 0 {
			continue
		}
		topCandidates = keepTopAuthorCandidate(topCandidates, authorNeighborCandidate{
			authorIndex: otherIndex,
			score:       score,
			shared:      acc.shared,
		}, opts.topN, profiles)
	}
	sort.Slice(topCandidates, func(i, j int) bool {
		return authorCandidateBetter(topCandidates[i], topCandidates[j], profiles)
	})

	result.SimilarAuthors = make([]authorSimilarityNeighbor, 0, len(topCandidates))
	for _, candidate := range topCandidates {
		other := profiles[candidate.authorIndex]
		result.SimilarAuthors = append(result.SimilarAuthors, authorSimilarityNeighbor{
			AuthorKey:          other.key,
			AuthorName:         other.name,
			WorkCount:          other.workCount,
			Score:              roundAuthorSimilarityFloat(candidate.score),
			SharedKeywordCount: candidate.shared,
			SharedKeywords:     topSharedAuthorKeywords(profile, other, opts.sharedKeywords),
		})
	}
	return result
}

func keepTopAuthorCandidate(
	top []authorNeighborCandidate,
	candidate authorNeighborCandidate,
	limit int,
	profiles []*authorProfile,
) []authorNeighborCandidate {
	if limit < 1 {
		return top
	}
	if len(top) < limit {
		return append(top, candidate)
	}
	worstIndex := 0
	for i := 1; i < len(top); i++ {
		if authorCandidateBetter(top[worstIndex], top[i], profiles) {
			worstIndex = i
		}
	}
	if authorCandidateBetter(candidate, top[worstIndex], profiles) {
		top[worstIndex] = candidate
	}
	return top
}

func authorCandidateBetter(left, right authorNeighborCandidate, profiles []*authorProfile) bool {
	if left.score != right.score {
		return left.score > right.score
	}
	if left.shared != right.shared {
		return left.shared > right.shared
	}
	leftProfile := profiles[left.authorIndex]
	rightProfile := profiles[right.authorIndex]
	if leftProfile.workCount != rightProfile.workCount {
		return leftProfile.workCount > rightProfile.workCount
	}
	return leftProfile.key < rightProfile.key
}

func topSharedAuthorKeywords(left *authorProfile, right *authorProfile, limit int) []authorSharedKeyword {
	if limit < 1 || len(left.termByKeyword) == 0 || len(right.termByKeyword) == 0 {
		return nil
	}
	shared := make([]authorSharedKeyword, 0)
	iterate := left.termByKeyword
	lookup := right.termByKeyword
	if len(iterate) > len(lookup) {
		iterate, lookup = lookup, iterate
	}
	for keyword, leftTerm := range iterate {
		rightTerm, ok := lookup[keyword]
		if !ok {
			continue
		}
		shared = append(shared, authorSharedKeyword{
			Keyword: keyword,
			Score:   roundAuthorSimilarityFloat(leftTerm.weight * rightTerm.weight),
		})
	}
	sort.Slice(shared, func(i, j int) bool {
		if shared[i].Score != shared[j].Score {
			return shared[i].Score > shared[j].Score
		}
		return shared[i].Keyword < shared[j].Keyword
	})
	if len(shared) > limit {
		shared = shared[:limit]
	}
	return shared
}

func roundAuthorSimilarityFloat(value float64) float64 {
	return math.Round(value*1_000_000) / 1_000_000
}

func writeAuthorSimilarityJSON(result authorSimilarityResult, outputPath string) error {
	if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
		return err
	}
	file, err := os.Create(outputPath)
	if err != nil {
		return err
	}
	defer file.Close()

	buffered := bufio.NewWriterSize(file, 1<<20)
	encoder := json.NewEncoder(buffered)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(result); err != nil {
		return err
	}
	return buffered.Flush()
}
