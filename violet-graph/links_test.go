package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFindRelatedLinksUsesKeywordIntersection(t *testing.T) {
	index := newKeywordIndex([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, DF: 3},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, DF: 3},
		{ArticleID: "1", Rank: 3, Keyword: "combo", Score: 6, DF: 3},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, DF: 3},
		{ArticleID: "2", Rank: 2, Keyword: "combo", Score: 8, DF: 3},
		{ArticleID: "3", Rank: 1, Keyword: "beta", Score: 9, DF: 3},
		{ArticleID: "3", Rank: 2, Keyword: "combo", Score: 8, DF: 3},
		{ArticleID: "4", Rank: 1, Keyword: "alpha", Score: 7, DF: 3},
		{ArticleID: "4", Rank: 2, Keyword: "beta", Score: 6, DF: 3},
		{ArticleID: "4", Rank: 3, Keyword: "combo", Score: 5, DF: 3},
		{ArticleID: "4", Rank: 4, Keyword: "rare", Score: 20, DF: 1},
	})

	result := findRelatedLinksFromIndex(index, relatedLinksOptions{
		keywords:     []string{"alpha", "beta"},
		minKeywordDF: 1,
		limit:        10,
	})
	if len(result.Links) == 0 {
		t.Fatalf("links = %+v, want combo link", result.Links)
	}
	if result.Links[0].Keyword != "combo" || result.Links[0].Cooccur != 2 {
		t.Fatalf("top link = %+v, want combo with cooccur 2", result.Links[0])
	}
	for _, link := range result.Links {
		if link.Keyword == "alpha" || link.Keyword == "beta" {
			t.Fatalf("query keyword leaked into links: %+v", result.Links)
		}
	}
}

func TestKeywordGraphServerReturnsRelatedLinksJSON(t *testing.T) {
	server := newKeywordGraphServer([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, DF: 2},
		{ArticleID: "1", Rank: 3, Keyword: "combo", Score: 6, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 7, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "beta", Score: 5, DF: 2},
		{ArticleID: "2", Rank: 3, Keyword: "combo", Score: 4, DF: 2},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/links?keywords=alpha,beta&minKeywordDF=1&limit=5", nil)
	rec := httptest.NewRecorder()
	server.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var response relatedLinksResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if len(response.Links) != 1 || response.Links[0].Keyword != "combo" {
		t.Fatalf("links = %+v, want combo only", response.Links)
	}
}
