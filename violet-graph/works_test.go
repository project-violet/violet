package main

import (
	"fmt"
	"testing"
)

func TestFindRelatedWorksSelectedSoftAndAll(t *testing.T) {
	index := newKeywordIndex([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2, TotalPages: 12, DialogueCount: 80, CharacterCount: 1200},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2, TotalPages: 12, DialogueCount: 80, CharacterCount: 1200},
		{ArticleID: "1", Rank: 3, Keyword: "gamma", Score: 4, TF: 2, DF: 1, TotalPages: 12, DialogueCount: 80, CharacterCount: 1200},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, TF: 4, DF: 2, TotalPages: 8, DialogueCount: 30, CharacterCount: 500},
		{ArticleID: "3", Rank: 1, Keyword: "beta", Score: 7, TF: 3, DF: 2, TotalPages: 10, DialogueCount: 60, CharacterCount: 900},
	})

	soft := findRelatedWorksFromIndex(index, relatedWorksOptions{
		mode:     "selected",
		keywords: []string{"alpha", "beta"},
		match:    "soft",
		limit:    10,
	})
	if len(soft.Works) != 3 {
		t.Fatalf("soft works = %d, want 3", len(soft.Works))
	}
	if soft.Works[0].ArticleID != "1" || soft.Works[0].MatchedCount != 2 {
		t.Fatalf("top soft work = %+v, want article 1 with 2 matches", soft.Works[0])
	}
	if len(soft.Works[0].TopKeywords) == 0 || soft.Works[0].TopKeywords[0].Keyword != "alpha" {
		t.Fatalf("top keywords = %+v", soft.Works[0].TopKeywords)
	}

	all := findRelatedWorksFromIndex(index, relatedWorksOptions{
		mode:     "selected",
		keywords: []string{"alpha", "beta"},
		match:    "all",
		limit:    10,
	})
	if len(all.Works) != 1 || all.Works[0].ArticleID != "1" {
		t.Fatalf("all works = %+v, want only article 1", all.Works)
	}
}

func TestFindRelatedWorksSelectedPrioritizesKeywordCoverage(t *testing.T) {
	index := newKeywordIndex([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 100, TF: 10, DF: 3},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 12, TF: 4, DF: 3},
		{ArticleID: "2", Rank: 2, Keyword: "beta", Score: 8, TF: 3, DF: 2},
		{ArticleID: "3", Rank: 1, Keyword: "beta", Score: 30, TF: 6, DF: 2},
	})

	result := findRelatedWorksFromIndex(index, relatedWorksOptions{
		mode:     "selected",
		keywords: []string{"alpha", "beta"},
		match:    "soft",
		limit:    10,
	})

	if len(result.Works) < 3 {
		t.Fatalf("works = %+v", result.Works)
	}
	if result.Works[0].ArticleID != "2" || result.Works[0].MatchedCount != 2 {
		t.Fatalf("top work = %+v, want article 2 with both selected keywords", result.Works[0])
	}
	if result.Works[0].Score <= result.Works[1].Score {
		t.Fatalf("top score = %f, next = %f, want coverage-adjusted score first", result.Works[0].Score, result.Works[1].Score)
	}
}

func TestFindRelatedWorksGraphUsesExpandedGraphTerms(t *testing.T) {
	index := newKeywordIndex([]keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "alpha", Score: 10, TF: 5, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "beta", Score: 8, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 1, Keyword: "alpha", Score: 9, TF: 4, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "beta", Score: 7, TF: 3, DF: 2},
		{ArticleID: "3", Rank: 1, Keyword: "alpha", Score: 6, TF: 2, DF: 2},
	})

	result := findRelatedWorksFromIndex(index, relatedWorksOptions{
		mode:         "graph",
		query:        "alpha",
		expand:       "none",
		depth:        1,
		topN:         5,
		minCooccur:   1,
		minKeywordDF: 1,
		maxNodes:     20,
		limit:        10,
	})

	if len(result.QueryTerms) < 2 {
		t.Fatalf("query terms = %+v, want expanded graph terms", result.QueryTerms)
	}
	if len(result.Works) != 3 {
		t.Fatalf("works = %d, want 3", len(result.Works))
	}
	if result.Works[0].ArticleID != "1" || result.Works[0].MatchedCount < 2 {
		t.Fatalf("top graph work = %+v, want article 1 with expanded matches", result.Works[0])
	}
}

func TestFindWorkSetPrioritizesAggregateScoreOverCooccur(t *testing.T) {
	rows := []keywordRow{}
	for i := 1; i <= 10; i++ {
		articleID := string(rune('0' + i))
		if i == 10 {
			articleID = "10"
		}
		rows = append(rows,
			keywordRow{ArticleID: articleID, Rank: 1, Keyword: "common", Score: 1, TF: 1, DF: 10},
			keywordRow{ArticleID: articleID, Rank: 2, Keyword: "peer", Score: 1, TF: 1, DF: 10},
		)
		if i <= 5 {
			rows = append(rows, keywordRow{ArticleID: articleID, Rank: 3, Keyword: "signature", Score: 20, TF: 20, DF: 5})
		}
	}
	index := newKeywordIndex(rows)

	result, ok := findWorkSetFromIndex(index, []string{"1", "2", "3", "4", "5"})
	if !ok {
		t.Fatal("work set not found")
	}
	if len(result.TopKeywords) == 0 {
		t.Fatalf("top keywords = %+v", result.TopKeywords)
	}
	if result.TopKeywords[0].Keyword != "signature" {
		t.Fatalf("top keyword = %+v, want aggregate score leader first", result.TopKeywords[0])
	}
	if result.TopKeywords[0].Rank != 1 {
		t.Fatalf("top rank = %d, want 1", result.TopKeywords[0].Rank)
	}
}

func TestFindWorkSetKeepsAggregateScoreLeaderBeforeCooccurCutoff(t *testing.T) {
	rows := []keywordRow{}
	articleIDs := []string{"1", "2", "3", "4", "5"}
	for _, articleID := range articleIDs {
		rows = append(rows,
			keywordRow{ArticleID: articleID, Rank: 1, Keyword: "anchor", Score: 1, TF: 1, DF: 125},
			keywordRow{ArticleID: articleID, Rank: 2, Keyword: "signature", Score: 100, TF: 100, DF: 5},
		)
		for i := 0; i < 120; i++ {
			rows = append(rows, keywordRow{
				ArticleID: articleID,
				Rank:      i + 3,
				Keyword:   "cooccur-heavy-" + string(rune('a'+i%26)) + string(rune('a'+i/26)),
				Score:     1,
				TF:        1,
				DF:        125,
			})
		}
	}
	for i := 6; i <= 125; i++ {
		articleID := fmt.Sprintf("extra-%d", i)
		rows = append(rows, keywordRow{ArticleID: articleID, Rank: 1, Keyword: "anchor", Score: 1, TF: 1, DF: 125})
		for j := 0; j < 120; j++ {
			rows = append(rows, keywordRow{
				ArticleID: articleID,
				Rank:      j + 2,
				Keyword:   "cooccur-heavy-" + string(rune('a'+j%26)) + string(rune('a'+j/26)),
				Score:     1,
				TF:        1,
				DF:        125,
			})
		}
	}
	index := newKeywordIndex(rows)

	result, ok := findWorkSetFromIndex(index, articleIDs)
	if !ok {
		t.Fatal("work set not found")
	}
	if len(result.TopKeywords) == 0 {
		t.Fatalf("top keywords = %+v", result.TopKeywords)
	}
	if result.TopKeywords[0].Keyword != "signature" {
		t.Fatalf("top keyword = %+v, want aggregate score leader first", result.TopKeywords[0])
	}
}
