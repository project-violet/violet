package main

import (
	"math"
	"sort"
	"strings"
)

type relatedWorksOptions struct {
	mode           string
	query          string
	keywords       []string
	match          string
	expand         string
	depth          int
	topN           int
	minScore       float64
	minCooccur     int
	autoMinCooccur bool
	minKeywordDF   int
	maxNodes       int
	limit          int
}

type relatedWorksResponse struct {
	Query      string        `json:"query"`
	Mode       string        `json:"mode"`
	Match      string        `json:"match"`
	QueryTerms []string      `json:"query_terms"`
	Works      []relatedWork `json:"works"`
}

type relatedWork struct {
	ArticleID       string               `json:"article_id"`
	Score           float64              `json:"score"`
	MatchedCount    int                  `json:"matched_count"`
	MatchedKeywords []relatedWorkKeyword `json:"matched_keywords"`
	TopKeywords     []relatedWorkKeyword `json:"top_keywords"`
	TotalPages      int                  `json:"total_pages"`
	DialogueCount   int                  `json:"dialogue_count"`
	CharacterCount  int                  `json:"char_count"`
}

type relatedWorkKeyword struct {
	Keyword string  `json:"keyword"`
	Score   float64 `json:"score"`
	Rank    int     `json:"rank"`
	TF      int     `json:"tf"`
}

type relatedWorkAccumulator struct {
	articleID       string
	rawScore        float64
	matchedKeywords []relatedWorkKeyword
}

func findRelatedWorksFromIndex(index keywordIndex, opts relatedWorksOptions) relatedWorksResponse {
	opts = normalizeRelatedWorksOptions(opts)
	queryWeights, queryTerms := relatedWorkQueryWeights(index, opts)
	response := relatedWorksResponse{
		Query:      opts.query,
		Mode:       opts.mode,
		Match:      opts.match,
		QueryTerms: queryTerms,
		Works:      []relatedWork{},
	}
	if len(queryWeights) == 0 {
		return response
	}

	accumulators := make(map[string]*relatedWorkAccumulator)
	for keyword, queryWeight := range queryWeights {
		for articleID, row := range index.keywordWorks[keyword] {
			acc := accumulators[articleID]
			if acc == nil {
				acc = &relatedWorkAccumulator{articleID: articleID}
				accumulators[articleID] = acc
			}
			acc.rawScore += queryWeight * keywordWeight(row)
			acc.matchedKeywords = append(acc.matchedKeywords, relatedWorkKeywordFromRow(row))
		}
	}

	works := make([]relatedWork, 0, len(accumulators))
	for articleID, acc := range accumulators {
		if opts.match == "all" && len(acc.matchedKeywords) < len(queryWeights) {
			continue
		}
		workRows := index.works[articleID]
		score := relatedWorkScore(acc.rawScore, len(acc.matchedKeywords), len(queryWeights), opts.mode)
		sortRelatedWorkKeywords(acc.matchedKeywords)
		pages, dialogues, chars := relatedWorkStats(workRows)
		works = append(works, relatedWork{
			ArticleID:       articleID,
			Score:           score,
			MatchedCount:    len(acc.matchedKeywords),
			MatchedKeywords: acc.matchedKeywords,
			TopKeywords:     topRelatedWorkKeywords(workRows, 8),
			TotalPages:      pages,
			DialogueCount:   dialogues,
			CharacterCount:  chars,
		})
	}

	sort.Slice(works, func(i, j int) bool {
		if works[i].Score != works[j].Score {
			return works[i].Score > works[j].Score
		}
		if works[i].MatchedCount != works[j].MatchedCount {
			return works[i].MatchedCount > works[j].MatchedCount
		}
		return works[i].ArticleID < works[j].ArticleID
	})
	if len(works) > opts.limit {
		works = works[:opts.limit]
	}
	response.Works = works
	return response
}

func findWorkFromIndex(index keywordIndex, articleID string) (relatedWork, bool) {
	workRows := index.works[articleID]
	if len(workRows) == 0 {
		return relatedWork{}, false
	}
	pages, dialogues, chars := relatedWorkStats(workRows)
	return relatedWork{
		ArticleID:       articleID,
		MatchedKeywords: []relatedWorkKeyword{},
		TopKeywords:     topRelatedWorkKeywords(workRows, 0),
		TotalPages:      pages,
		DialogueCount:   dialogues,
		CharacterCount:  chars,
	}, true
}

func relatedWorkScore(rawScore float64, matchedCount int, queryCount int, mode string) float64 {
	score := rawScore * (1 + math.Log1p(float64(matchedCount))*0.25)
	if mode != "selected" || queryCount <= 1 {
		return score
	}
	coverage := float64(matchedCount) / float64(queryCount)
	return score * coverage * coverage * math.Pow(float64(matchedCount), 4)
}

func normalizeRelatedWorksOptions(opts relatedWorksOptions) relatedWorksOptions {
	opts.mode = strings.TrimSpace(opts.mode)
	if opts.mode == "" {
		opts.mode = "graph"
	}
	opts.match = strings.TrimSpace(opts.match)
	if opts.match == "" {
		opts.match = "soft"
	}
	if opts.expand == "" {
		opts.expand = "none"
	}
	if opts.depth < 0 {
		opts.depth = 0
	}
	if opts.topN < 1 {
		opts.topN = 20
	}
	if opts.autoMinCooccur {
		if opts.minCooccur < 0 {
			opts.minCooccur = 0
		}
	} else if opts.minCooccur < 1 {
		opts.minCooccur = 1
	}
	if opts.minKeywordDF < 1 {
		opts.minKeywordDF = 1
	}
	if opts.maxNodes < 1 {
		opts.maxNodes = 200
	}
	if opts.limit < 1 {
		opts.limit = 30
	}
	if opts.limit > 200 {
		opts.limit = 200
	}
	return opts
}

func relatedWorkQueryWeights(index keywordIndex, opts relatedWorksOptions) (map[string]float64, []string) {
	weights := make(map[string]float64)
	queryTerms := make([]string, 0)
	add := func(keyword string, weight float64) {
		keyword = strings.TrimSpace(keyword)
		if keyword == "" {
			return
		}
		if old, exists := weights[keyword]; exists && old >= weight {
			return
		}
		if _, exists := weights[keyword]; !exists {
			queryTerms = append(queryTerms, keyword)
		}
		weights[keyword] = weight
	}

	if opts.mode == "selected" {
		for _, keyword := range opts.keywords {
			add(keyword, 1)
		}
		return weights, queryTerms
	}

	graph := buildKeywordGraphFromIndex(index, graphOptions{
		query:          opts.query,
		expand:         opts.expand,
		depth:          opts.depth,
		topN:           opts.topN,
		minScore:       opts.minScore,
		minCooccur:     opts.minCooccur,
		autoMinCooccur: opts.autoMinCooccur,
		minKeywordDF:   opts.minKeywordDF,
		maxNodes:       opts.maxNodes,
	})
	for _, node := range graph.Nodes {
		add(node.ID, graphDepthWorkWeight(node.Depth))
	}
	return weights, queryTerms
}

func graphDepthWorkWeight(depth int) float64 {
	switch {
	case depth <= 0:
		return 1
	case depth == 1:
		return 0.7
	default:
		return 0.35
	}
}

func relatedWorkKeywordFromRow(row keywordRow) relatedWorkKeyword {
	return relatedWorkKeyword{
		Keyword: row.Keyword,
		Score:   row.Score,
		Rank:    row.Rank,
		TF:      row.TF,
	}
}

func topRelatedWorkKeywords(workRows map[string]keywordRow, limit int) []relatedWorkKeyword {
	keywords := make([]relatedWorkKeyword, 0, len(workRows))
	for _, row := range workRows {
		keywords = append(keywords, relatedWorkKeywordFromRow(row))
	}
	sortRelatedWorkKeywords(keywords)
	if limit > 0 && len(keywords) > limit {
		keywords = keywords[:limit]
	}
	return keywords
}

func sortRelatedWorkKeywords(keywords []relatedWorkKeyword) {
	sort.Slice(keywords, func(i, j int) bool {
		if keywords[i].Score != keywords[j].Score {
			return keywords[i].Score > keywords[j].Score
		}
		if keywords[i].Rank != keywords[j].Rank {
			return keywords[i].Rank < keywords[j].Rank
		}
		return keywords[i].Keyword < keywords[j].Keyword
	})
}

func relatedWorkStats(workRows map[string]keywordRow) (int, int, int) {
	for _, row := range workRows {
		return row.TotalPages, row.DialogueCount, row.CharacterCount
	}
	return 0, 0, 0
}
