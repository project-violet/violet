package main

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func TestFindSimilarKeywordsRanksWeightedCooccurrence(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "seed", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "peer", Score: 9, TF: 4, DF: 3},
		{ArticleID: "1", Rank: 3, Keyword: "minor", Score: 2, TF: 2, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "seed", Score: 8, TF: 3, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "peer", Score: 7, TF: 3, DF: 3},
		{ArticleID: "2", Rank: 3, Keyword: "side", Score: 6, TF: 2, DF: 1},
		{ArticleID: "3", Rank: 1, Keyword: "peer", Score: 9, TF: 5, DF: 3},
	}

	results := findSimilarKeywords(rows, similarOptions{
		query:        "seed",
		topN:         10,
		minCooccur:   1,
		minKeywordDF: 1,
	})

	if len(results) != 3 {
		t.Fatalf("results = %d, want 3: %#v", len(results), results)
	}
	if results[0].Keyword != "peer" || results[0].Cooccur != 2 || results[0].QueryDF != 2 || results[0].KeywordDF != 3 {
		t.Fatalf("first result = %#v", results[0])
	}
	if results[0].QueryTerms != "seed" {
		t.Fatalf("query terms = %q", results[0].QueryTerms)
	}
	if results[1].Keyword != "side" {
		t.Fatalf("second result = %#v", results[1])
	}
}

func TestFindSimilarKeywordsExpandsQueryByContains(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "prefix", Score: 10, TF: 5, DF: 1},
		{ArticleID: "1", Rank: 2, Keyword: "shared", Score: 8, TF: 3, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "prefix-a", Score: 9, TF: 4, DF: 1},
		{ArticleID: "2", Rank: 2, Keyword: "shared", Score: 7, TF: 3, DF: 2},
		{ArticleID: "3", Rank: 1, Keyword: "prefix-b", Score: 8, TF: 3, DF: 1},
		{ArticleID: "3", Rank: 2, Keyword: "tail", Score: 7, TF: 3, DF: 1},
	}

	results := findSimilarKeywords(rows, similarOptions{
		query:        "prefix",
		expand:       "contains",
		topN:         10,
		minCooccur:   1,
		minKeywordDF: 1,
	})

	if len(results) != 2 {
		t.Fatalf("results = %d, want 2: %#v", len(results), results)
	}
	if results[0].Keyword != "shared" || results[0].Cooccur != 2 || results[0].QueryDF != 3 {
		t.Fatalf("first result = %#v", results[0])
	}
	if results[0].QueryTerms != "prefix|prefix-a|prefix-b" {
		t.Fatalf("query terms = %q", results[0].QueryTerms)
	}
	if results[1].Keyword != "tail" {
		t.Fatalf("second result = %#v", results[1])
	}
	for _, result := range results {
		if result.Keyword == "prefix-a" || result.Keyword == "prefix-b" {
			t.Fatalf("expanded query term leaked into results: %#v", result)
		}
	}
}

func TestFindSimilarKeywordsAutoMinCooccurRaisesThresholdForBroadQueries(t *testing.T) {
	rows := []keywordRow{}
	for i := 1; i <= 100; i++ {
		articleID := strconv.Itoa(i)
		rows = append(rows, keywordRow{ArticleID: articleID, Rank: 1, Keyword: "hub", Score: 10, TF: 5, DF: 100})
		if i <= 80 {
			rows = append(rows, keywordRow{ArticleID: articleID, Rank: 2, Keyword: "strong", Score: 8, TF: 4, DF: 80})
		}
		if i <= 40 {
			rows = append(rows, keywordRow{ArticleID: articleID, Rank: 3, Keyword: "mid", Score: 7, TF: 3, DF: 40})
		}
		if i == 1 {
			rows = append(rows, keywordRow{ArticleID: articleID, Rank: 4, Keyword: "weak", Score: 20, TF: 10, DF: 1})
		}
	}

	manual := findSimilarKeywords(rows, similarOptions{
		query:          "hub",
		topN:           10,
		minCooccur:     1,
		minKeywordDF:   1,
		autoMinCooccur: false,
	})
	auto := findSimilarKeywords(rows, similarOptions{
		query:          "hub",
		topN:           10,
		minCooccur:     1,
		minKeywordDF:   1,
		autoMinCooccur: true,
	})

	if !hasSimilarKeyword(manual, "weak") {
		t.Fatalf("manual results should keep weak low-cooccur keyword: %#v", manual)
	}
	if hasSimilarKeyword(auto, "weak") {
		t.Fatalf("auto results should drop weak low-cooccur keyword: %#v", auto)
	}
	if !hasSimilarKeyword(auto, "strong") || !hasSimilarKeyword(auto, "mid") {
		t.Fatalf("auto results should keep strong cooccurring keywords: %#v", auto)
	}
}

func TestFindSimilarKeywordsAutoMinCooccurAcceptsZeroManualFloor(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "seed", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "first", Score: 8, TF: 4, DF: 1},
		{ArticleID: "2", Rank: 1, Keyword: "seed", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "second", Score: 7, TF: 3, DF: 1},
	}

	results := findSimilarKeywords(rows, similarOptions{
		query:          "seed",
		topN:           10,
		minCooccur:     0,
		minKeywordDF:   1,
		autoMinCooccur: true,
	})

	if !hasSimilarKeyword(results, "first") || !hasSimilarKeyword(results, "second") {
		t.Fatalf("auto min cooccur with zero floor should keep one-off terms: %#v", results)
	}
}

func TestKeywordIndexStoresWorksByKeyword(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "seed", Score: 10},
		{ArticleID: "1", Rank: 2, Keyword: "peer", Score: 8},
		{ArticleID: "2", Rank: 1, Keyword: "seed", Score: 7},
		{ArticleID: "3", Rank: 1, Keyword: "side", Score: 9},
	}

	index := newKeywordIndex(rows)

	if len(index.keywordWorks["seed"]) != 2 {
		t.Fatalf("seed work count = %d, want 2", len(index.keywordWorks["seed"]))
	}
	if _, ok := index.keywordWorks["seed"]["1"]; !ok {
		t.Fatalf("seed should include article 1")
	}
	if _, ok := index.keywordWorks["seed"]["2"]; !ok {
		t.Fatalf("seed should include article 2")
	}
	if len(index.keywordWorks["peer"]) != 1 {
		t.Fatalf("peer work count = %d, want 1", len(index.keywordWorks["peer"]))
	}
}

func hasSimilarKeyword(results []similarResult, keyword string) bool {
	for _, result := range results {
		if result.Keyword == keyword {
			return true
		}
	}
	return false
}

func TestSimilarCSVRoundTrip(t *testing.T) {
	tmp := t.TempDir()
	input := filepath.Join(tmp, "keywords.csv")
	output := filepath.Join(tmp, "similar.csv")
	data := "article_id,rank,keyword,score,tf,df,total_pages,dialogue_count,char_count\n" +
		"1,1,seed,10,5,2,10,100,1000\n" +
		"1,2,peer,9,4,3,10,100,1000\n" +
		"2,1,seed,8,3,2,8,80,800\n" +
		"2,2,side,7,3,1,8,80,800\n"
	if err := os.WriteFile(input, []byte(data), 0o644); err != nil {
		t.Fatal(err)
	}

	rows, err := readKeywordCSV(input)
	if err != nil {
		t.Fatal(err)
	}
	results := findSimilarKeywords(rows, similarOptions{
		query:        "seed",
		topN:         10,
		minCooccur:   1,
		minKeywordDF: 1,
	})
	if err := writeSimilarCSV(results, output, false); err != nil {
		t.Fatal(err)
	}
	out, err := os.ReadFile(output)
	if err != nil {
		t.Fatal(err)
	}
	got := string(out)
	if !containsAll(got, []string{
		"query,keyword,score,cooccur,query_df,keyword_df",
		"seed,peer,",
		"seed,side,",
	}) {
		t.Fatalf("unexpected output:\n%s", got)
	}
	if contains(got, "query_terms") || contains(got, "seed,seed,") {
		t.Fatalf("query terms should be hidden by default:\n%s", got)
	}
}

func TestSimilarCSVCanShowQueryTerms(t *testing.T) {
	results := []similarResult{
		{
			Query:      "prefix",
			QueryTerms: "prefix|prefix-a|prefix-b",
			Keyword:    "shared",
			Score:      1.25,
			Cooccur:    2,
			QueryDF:    3,
			KeywordDF:  2,
		},
	}
	tmp := t.TempDir()
	output := filepath.Join(tmp, "similar-with-terms.csv")
	if err := writeSimilarCSV(results, output, true); err != nil {
		t.Fatal(err)
	}
	out, err := os.ReadFile(output)
	if err != nil {
		t.Fatal(err)
	}
	got := string(out)
	if !containsAll(got, []string{
		"query,query_terms,keyword,score,cooccur,query_df,keyword_df",
		"prefix,prefix|prefix-a|prefix-b,shared,",
	}) {
		t.Fatalf("unexpected output:\n%s", got)
	}
}
