package main

import "testing"

func TestBuildKeywordGraphExpandsByDepthAndScore(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "beta", Score: 7, TF: 3, DF: 2},
		{ArticleID: "3", Rank: 1, Keyword: "beta", Score: 9, TF: 5, DF: 2},
		{ArticleID: "3", Rank: 2, Keyword: "gamma", Score: 8, TF: 4, DF: 2},
	}

	graph := buildKeywordGraph(rows, graphOptions{
		query:        "alpha",
		depth:        2,
		topN:         3,
		minScore:     0.1,
		minCooccur:   1,
		minKeywordDF: 1,
		maxNodes:     20,
	})

	if len(graph.Nodes) != 3 {
		t.Fatalf("nodes = %d, want 3: %#v", len(graph.Nodes), graph.Nodes)
	}
	if len(graph.Edges) != 2 {
		t.Fatalf("edges = %d, want 2: %#v", len(graph.Edges), graph.Edges)
	}
	assertGraphNode(t, graph, "alpha", 0)
	assertGraphNode(t, graph, "beta", 1)
	assertGraphNode(t, graph, "gamma", 2)
	assertGraphEdge(t, graph, "alpha", "beta")
	assertGraphEdge(t, graph, "beta", "gamma")
	if graph.Query != "alpha" || graph.Params.Depth != 2 || graph.Params.TopN != 3 {
		t.Fatalf("metadata = %#v", graph)
	}
}

func TestBuildKeywordGraphHonorsMinScoreAndMaxNodes(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "1", Rank: 3, Keyword: "weak", Score: 1, TF: 1, DF: 1},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "beta", Score: 7, TF: 3, DF: 2},
		{ArticleID: "2", Rank: 3, Keyword: "gamma", Score: 6, TF: 3, DF: 1},
	}

	graph := buildKeywordGraph(rows, graphOptions{
		query:        "alpha",
		depth:        2,
		topN:         10,
		minScore:     10,
		minCooccur:   1,
		minKeywordDF: 1,
		maxNodes:     2,
	})

	if len(graph.Nodes) != 2 {
		t.Fatalf("nodes = %d, want 2: %#v", len(graph.Nodes), graph.Nodes)
	}
	assertGraphNode(t, graph, "alpha", 0)
	assertGraphNode(t, graph, "beta", 1)
	if len(graph.Edges) != 1 {
		t.Fatalf("edges = %d, want 1: %#v", len(graph.Edges), graph.Edges)
	}
	assertGraphEdge(t, graph, "alpha", "beta")
}

func TestBuildKeywordGraphUsesMultipleSeedQueries(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "gamma", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "delta", Score: 7, TF: 3, DF: 2},
	}

	graph := buildKeywordGraph(rows, graphOptions{
		query:        "alpha, gamma",
		queries:      []string{"alpha", "gamma"},
		depth:        1,
		topN:         5,
		minScore:     0,
		minCooccur:   1,
		minKeywordDF: 1,
		maxNodes:     10,
	})

	if got := len(graph.Queries); got != 2 {
		t.Fatalf("queries = %#v, want 2 seeds", graph.Queries)
	}
	assertGraphNode(t, graph, "alpha", 0)
	assertGraphNode(t, graph, "gamma", 0)
	assertGraphNode(t, graph, "beta", 1)
	assertGraphNode(t, graph, "delta", 1)
	assertGraphEdge(t, graph, "alpha", "beta")
	assertGraphEdge(t, graph, "gamma", "delta")
}

func assertGraphNode(t *testing.T, graph keywordGraph, id string, depth int) {
	t.Helper()
	for _, node := range graph.Nodes {
		if node.ID == id {
			if node.Depth != depth {
				t.Fatalf("node %q depth = %d, want %d", id, node.Depth, depth)
			}
			return
		}
	}
	t.Fatalf("missing node %q in %#v", id, graph.Nodes)
}

func assertGraphEdge(t *testing.T, graph keywordGraph, from string, to string) {
	t.Helper()
	for _, edge := range graph.Edges {
		if edge.From == from && edge.To == to {
			if edge.Score <= 0 || edge.Cooccur < 1 {
				t.Fatalf("edge %s -> %s has bad metrics: %#v", from, to, edge)
			}
			return
		}
	}
	t.Fatalf("missing edge %s -> %s in %#v", from, to, graph.Edges)
}
