package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestBuildAuthorSimilarityRanksSharedSignatureAuthors(t *testing.T) {
	rows := []keywordRow{
		{ArticleID: "1", Rank: 1, Keyword: "school", Score: 10, TF: 10, DF: 2},
		{ArticleID: "1", Rank: 2, Keyword: "lesson", Score: 8, TF: 8, DF: 2},
		{ArticleID: "1", Rank: 3, Keyword: "common", Score: 1, TF: 1, DF: 3},
		{ArticleID: "2", Rank: 1, Keyword: "school", Score: 9, TF: 9, DF: 2},
		{ArticleID: "2", Rank: 2, Keyword: "lesson", Score: 7, TF: 7, DF: 2},
		{ArticleID: "2", Rank: 3, Keyword: "common", Score: 1, TF: 1, DF: 3},
		{ArticleID: "3", Rank: 1, Keyword: "space", Score: 10, TF: 10, DF: 1},
		{ArticleID: "3", Rank: 2, Keyword: "common", Score: 1, TF: 1, DF: 3},
	}
	authorWorks := []authorWorkRow{
		{AuthorKey: "artist-a", AuthorName: "Artist A", ArticleID: "1", ContributionWeight: 1},
		{AuthorKey: "artist-b", AuthorName: "Artist B", ArticleID: "2", ContributionWeight: 1},
		{AuthorKey: "artist-c", AuthorName: "Artist C", ArticleID: "3", ContributionWeight: 1},
	}

	result := buildAuthorSimilarity(rows, authorWorks, authorSimilarityOptions{
		topN:              2,
		topKeywords:       3,
		maxKeywordAuthors: 2,
		minSharedKeywords: 1,
		sharedKeywords:    3,
		workers:           1,
	})

	author := findAuthorSimilarityResult(result.Authors, "artist-a")
	if author == nil {
		t.Fatalf("missing artist-a result")
	}
	if len(author.SimilarAuthors) != 1 {
		t.Fatalf("artist-a neighbors = %d, want 1", len(author.SimilarAuthors))
	}
	neighbor := author.SimilarAuthors[0]
	if neighbor.AuthorKey != "artist-b" {
		t.Fatalf("artist-a top neighbor = %q, want artist-b", neighbor.AuthorKey)
	}
	if neighbor.SharedKeywordCount != 2 {
		t.Fatalf("shared keyword count = %d, want 2", neighbor.SharedKeywordCount)
	}
	if len(neighbor.SharedKeywords) == 0 || neighbor.SharedKeywords[0].Keyword != "school" {
		t.Fatalf("top shared keyword = %#v, want school first", neighbor.SharedKeywords)
	}
}

func TestReadAuthorWorkCSVParsesExportRows(t *testing.T) {
	tmp := t.TempDir()
	path := filepath.Join(tmp, "author_work.csv")
	data := "author_key,author_name,article_id,article_artist_count,contribution_weight\n" +
		"artist-a,Artist A,100,2,0.5\n"
	if err := os.WriteFile(path, []byte(data), 0o644); err != nil {
		t.Fatal(err)
	}

	rows, err := readAuthorWorkCSV(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 {
		t.Fatalf("rows = %d, want 1", len(rows))
	}
	if rows[0].AuthorKey != "artist-a" || rows[0].ArticleID != "100" || rows[0].ContributionWeight != 0.5 {
		t.Fatalf("parsed row = %#v", rows[0])
	}
}

func findAuthorSimilarityResult(authors []authorSimilarityAuthor, key string) *authorSimilarityAuthor {
	for i := range authors {
		if authors[i].AuthorKey == key {
			return &authors[i]
		}
	}
	return nil
}
