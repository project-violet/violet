package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestKeywordGraphServerReturnsGraphJSON(t *testing.T) {
	server := newKeywordGraphServer([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "beta", Score: 7, TF: 3, DF: 2},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/graph?query=alpha&depth=1&topN=5&minCooccur=1&minKeywordDF=1", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var graph keywordGraph
	if err := json.Unmarshal(rec.Body.Bytes(), &graph); err != nil {
		t.Fatal(err)
	}
	if graph.Query != "alpha" {
		t.Fatalf("query = %q", graph.Query)
	}
	assertGraphNode(t, graph, "alpha", 0)
	assertGraphNode(t, graph, "beta", 1)
	assertGraphEdge(t, graph, "alpha", "beta")
}

func TestKeywordGraphServerAllowsZeroMinCooccurForAutoMode(t *testing.T) {
	server := newKeywordGraphServer([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "gamma", Score: 7, TF: 3, DF: 2},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/graph?query=alpha&depth=1&topN=5&minCooccur=0&autoMinCooccur=1&minKeywordDF=1", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var graph keywordGraph
	if err := json.Unmarshal(rec.Body.Bytes(), &graph); err != nil {
		t.Fatal(err)
	}
	if !graph.Params.AutoMinCooccur {
		t.Fatalf("auto min cooccur should be enabled: %+v", graph.Params)
	}
	if graph.Params.MinCooccur != 0 {
		t.Fatalf("min cooccur = %d, want 0", graph.Params.MinCooccur)
	}
	assertGraphNode(t, graph, "beta", 1)
	assertGraphNode(t, graph, "gamma", 1)
}

func TestKeywordGraphServerParsesMultipleGraphQueries(t *testing.T) {
	server := newKeywordGraphServer([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "gamma", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "delta", Score: 7, TF: 3, DF: 2},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/graph?query=alpha,gamma&depth=1&topN=5&minCooccur=1&minKeywordDF=1", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var graph keywordGraph
	if err := json.Unmarshal(rec.Body.Bytes(), &graph); err != nil {
		t.Fatal(err)
	}
	if got := len(graph.Queries); got != 2 {
		t.Fatalf("queries = %#v, want 2 seeds", graph.Queries)
	}
	assertGraphNode(t, graph, "alpha", 0)
	assertGraphNode(t, graph, "gamma", 0)
	assertGraphNode(t, graph, "beta", 1)
	assertGraphNode(t, graph, "delta", 1)
}

func TestKeywordGraphServerRejectsZeroMinCooccurForManualMode(t *testing.T) {
	server := newKeywordGraphServer(nil)
	req := httptest.NewRequest(http.MethodGet, "/api/graph?query=alpha&minCooccur=0&autoMinCooccur=0", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestKeywordGraphServerAllowsBrowserCORS(t *testing.T) {
	server := newKeywordGraphServer(nil)
	req := httptest.NewRequest(http.MethodOptions, "/api/graph", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "*" {
		t.Fatalf("Access-Control-Allow-Origin = %q, want *", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Methods"); got != "GET, OPTIONS" {
		t.Fatalf("Access-Control-Allow-Methods = %q", got)
	}
}

func TestKeywordGraphServerReturnsRelatedWorksJSON(t *testing.T) {
	server := newKeywordGraphServer([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, TF: 4, DF: 2},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/works?mode=selected&keywords=alpha,beta&match=all&limit=5", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var response relatedWorksResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if len(response.Works) != 1 || response.Works[0].ArticleID != "1" {
		t.Fatalf("works = %+v, want only article 1", response.Works)
	}
	if len(response.Works[0].MatchedKeywords) != 2 {
		t.Fatalf("matched keywords = %+v", response.Works[0].MatchedKeywords)
	}
}

func TestKeywordGraphServerServesHTML(t *testing.T) {
	server := newKeywordGraphServer(nil)
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if !containsAll(body, []string{"Keyword Graph", "/api/graph", "graph-canvas"}) {
		t.Fatalf("unexpected html:\n%s", body)
	}
}
