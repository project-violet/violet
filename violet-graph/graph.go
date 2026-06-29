package main

import (
	"fmt"
	"sort"
	"strings"
)

type graphOptions struct {
	inputPath      string
	query          string
	queries        []string
	expand         string
	depth          int
	topN           int
	minScore       float64
	minCooccur     int
	autoMinCooccur bool
	minKeywordDF   int
	maxNodes       int
}

type keywordGraph struct {
	Query   string             `json:"query"`
	Queries []string           `json:"queries,omitempty"`
	Params  graphParams        `json:"params"`
	Nodes   []keywordGraphNode `json:"nodes"`
	Edges   []keywordGraphEdge `json:"edges"`
}

type graphParams struct {
	Expand         string  `json:"expand"`
	Depth          int     `json:"depth"`
	TopN           int     `json:"top_n"`
	MinScore       float64 `json:"min_score"`
	MinCooccur     int     `json:"min_cooccur"`
	AutoMinCooccur bool    `json:"auto_min_cooccur"`
	MinKeywordDF   int     `json:"min_keyword_df"`
	MaxNodes       int     `json:"max_nodes"`
}

type keywordGraphNode struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Depth int    `json:"depth"`
	DF    int    `json:"df"`
}

type keywordGraphEdge struct {
	ID        string  `json:"id"`
	From      string  `json:"from"`
	To        string  `json:"to"`
	Score     float64 `json:"score"`
	Cooccur   int     `json:"cooccur"`
	QueryDF   int     `json:"query_df"`
	KeywordDF int     `json:"keyword_df"`
}

type graphQueueItem struct {
	keyword string
	depth   int
}

func buildKeywordGraph(rows []keywordRow, opts graphOptions) keywordGraph {
	return buildKeywordGraphFromIndex(newKeywordIndex(rows), opts)
}

func buildKeywordGraphFromIndex(index keywordIndex, opts graphOptions) keywordGraph {
	opts = normalizeGraphOptions(opts)
	graph := keywordGraph{
		Query:   opts.query,
		Queries: opts.queries,
		Params:  graphParamsFromOptions(opts),
	}
	nodeIndex := make(map[string]int)
	edgeSeen := make(map[string]struct{})
	expanded := make(map[string]struct{})

	addNode := func(keyword string, depth int) bool {
		if keyword == "" {
			return false
		}
		if index, exists := nodeIndex[keyword]; exists {
			if depth < graph.Nodes[index].Depth {
				graph.Nodes[index].Depth = depth
			}
			return true
		}
		if len(graph.Nodes) >= opts.maxNodes {
			return false
		}
		nodeIndex[keyword] = len(graph.Nodes)
		graph.Nodes = append(graph.Nodes, keywordGraphNode{
			ID:    keyword,
			Label: keyword,
			Depth: depth,
			DF:    index.actualDF[keyword],
		})
		return true
	}

	queue := make([]graphQueueItem, 0, len(opts.queries))
	for _, query := range opts.queries {
		if addNode(query, 0) {
			queue = append(queue, graphQueueItem{keyword: query, depth: 0})
		}
	}
	for len(queue) > 0 {
		item := queue[0]
		queue = queue[1:]
		if item.depth >= opts.depth {
			continue
		}
		if _, done := expanded[item.keyword]; done {
			continue
		}
		expanded[item.keyword] = struct{}{}

		results := findSimilarKeywordsFromIndex(index, similarOptions{
			query:          item.keyword,
			expand:         opts.expand,
			topN:           opts.topN,
			minCooccur:     opts.minCooccur,
			autoMinCooccur: opts.autoMinCooccur,
			minKeywordDF:   opts.minKeywordDF,
		})
		for _, result := range results {
			if result.Score < opts.minScore {
				continue
			}
			if !addNode(result.Keyword, item.depth+1) {
				continue
			}
			edgeKey := unorderedGraphEdgeKey(item.keyword, result.Keyword)
			if _, exists := edgeSeen[edgeKey]; !exists {
				edgeSeen[edgeKey] = struct{}{}
				graph.Edges = append(graph.Edges, keywordGraphEdge{
					ID:        fmt.Sprintf("%s->%s", item.keyword, result.Keyword),
					From:      item.keyword,
					To:        result.Keyword,
					Score:     result.Score,
					Cooccur:   result.Cooccur,
					QueryDF:   result.QueryDF,
					KeywordDF: result.KeywordDF,
				})
			}
			if item.depth+1 < opts.depth {
				queue = append(queue, graphQueueItem{keyword: result.Keyword, depth: item.depth + 1})
			}
		}
	}
	return graph
}

func normalizeGraphOptions(opts graphOptions) graphOptions {
	opts.query = strings.TrimSpace(opts.query)
	opts.queries = splitQueryKeywords(opts.queries)
	if len(opts.queries) == 0 && opts.query != "" {
		opts.queries = splitQueryKeywords([]string{opts.query})
	}
	if opts.query == "" && len(opts.queries) > 0 {
		opts.query = strings.Join(opts.queries, ", ")
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
	return opts
}

func graphParamsFromOptions(opts graphOptions) graphParams {
	return graphParams{
		Expand:         opts.expand,
		Depth:          opts.depth,
		TopN:           opts.topN,
		MinScore:       opts.minScore,
		MinCooccur:     opts.minCooccur,
		AutoMinCooccur: opts.autoMinCooccur,
		MinKeywordDF:   opts.minKeywordDF,
		MaxNodes:       opts.maxNodes,
	}
}

func unorderedGraphEdgeKey(left string, right string) string {
	parts := []string{left, right}
	sort.Strings(parts)
	return parts[0] + "\x00" + parts[1]
}
