package main

import (
	"math"
	"sort"
	"strings"
)

type relatedLinksOptions struct {
	query        string
	keywords     []string
	minKeywordDF int
	minCooccur   int
	limit        int
}

type relatedLinksResponse struct {
	Query      string        `json:"query"`
	QueryTerms []string      `json:"query_terms"`
	Links      []relatedLink `json:"links"`
}

type relatedLink struct {
	Keyword   string  `json:"keyword"`
	Score     float64 `json:"score"`
	Cooccur   int     `json:"cooccur"`
	KeywordDF int     `json:"keyword_df"`
}

type relatedLinkAccumulator struct {
	rawScore float64
	cooccur  int
}

func findRelatedLinksFromIndex(index keywordIndex, opts relatedLinksOptions) relatedLinksResponse {
	opts = normalizeRelatedLinksOptions(opts)
	queryTerms := opts.keywords
	response := relatedLinksResponse{
		Query:      opts.query,
		QueryTerms: queryTerms,
		Links:      []relatedLink{},
	}
	if len(queryTerms) == 0 {
		return response
	}

	works := intersectKeywordWorks(index, queryTerms)
	if len(works) == 0 {
		return response
	}

	queryTermSet := make(map[string]struct{}, len(queryTerms))
	for _, keyword := range queryTerms {
		queryTermSet[keyword] = struct{}{}
	}

	accumulators := make(map[string]*relatedLinkAccumulator)
	for articleID := range works {
		for keyword, row := range index.works[articleID] {
			if _, isQueryTerm := queryTermSet[keyword]; isQueryTerm {
				continue
			}
			if index.actualDF[keyword] < opts.minKeywordDF {
				continue
			}
			acc := accumulators[keyword]
			if acc == nil {
				acc = &relatedLinkAccumulator{}
				accumulators[keyword] = acc
			}
			acc.cooccur++
			acc.rawScore += keywordWeight(row)
		}
	}

	links := make([]relatedLink, 0, len(accumulators))
	for keyword, acc := range accumulators {
		if acc.cooccur < opts.minCooccur {
			continue
		}
		links = append(links, relatedLink{
			Keyword:   keyword,
			Score:     relatedLinkScore(acc.rawScore, acc.cooccur),
			Cooccur:   acc.cooccur,
			KeywordDF: index.actualDF[keyword],
		})
	}

	sort.Slice(links, func(i, j int) bool {
		if links[i].Cooccur != links[j].Cooccur {
			return links[i].Cooccur > links[j].Cooccur
		}
		if links[i].Score != links[j].Score {
			return links[i].Score > links[j].Score
		}
		if links[i].KeywordDF != links[j].KeywordDF {
			return links[i].KeywordDF < links[j].KeywordDF
		}
		return links[i].Keyword < links[j].Keyword
	})
	if len(links) > opts.limit {
		links = links[:opts.limit]
	}
	response.Links = links
	return response
}

func normalizeRelatedLinksOptions(opts relatedLinksOptions) relatedLinksOptions {
	opts.query = strings.TrimSpace(opts.query)
	opts.keywords = splitQueryKeywords(opts.keywords)
	if len(opts.keywords) == 0 && opts.query != "" {
		opts.keywords = splitQueryKeywords([]string{opts.query})
	}
	if opts.query == "" && len(opts.keywords) > 0 {
		opts.query = strings.Join(opts.keywords, ", ")
	}
	if opts.minKeywordDF < 1 {
		opts.minKeywordDF = 1
	}
	if opts.minCooccur < 1 {
		opts.minCooccur = 1
	}
	if opts.limit < 1 {
		opts.limit = 50
	}
	if opts.limit > 200 {
		opts.limit = 200
	}
	return opts
}

func intersectKeywordWorks(index keywordIndex, keywords []string) map[string]struct{} {
	var intersection map[string]struct{}
	for _, keyword := range keywords {
		rowsByWork := index.keywordWorks[keyword]
		if len(rowsByWork) == 0 {
			return nil
		}
		if intersection == nil {
			intersection = make(map[string]struct{}, len(rowsByWork))
			for articleID := range rowsByWork {
				intersection[articleID] = struct{}{}
			}
			continue
		}
		for articleID := range intersection {
			if _, exists := rowsByWork[articleID]; !exists {
				delete(intersection, articleID)
			}
		}
	}
	return intersection
}

func relatedLinkScore(rawScore float64, cooccur int) float64 {
	return rawScore * (1 + math.Log1p(float64(cooccur))*0.25)
}
