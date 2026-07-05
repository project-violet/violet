package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestTokenizeFiltersNoiseAndNormalizesKorean(t *testing.T) {
	tokens := tokenizeText("역자8GB 식자 CG16 hello 루루무랑 루루무가 루루무는", 2, false)
	want := []string{"루루무", "루루무", "루루무"}
	if len(tokens) != len(want) {
		t.Fatalf("token count = %d, want %d: %#v", len(tokens), len(want), tokens)
	}
	for i := range want {
		if tokens[i] != want[i] {
			t.Fatalf("tokens[%d] = %q, want %q: %#v", i, tokens[i], want[i], tokens)
		}
	}
}

func TestExtractRanksDistinctiveWorkTerms(t *testing.T) {
	docs := []workDocument{
		{
			ArticleID:      "1",
			TotalPages:     2,
			DialogueCount:  4,
			CharacterCount: 20,
			TermCounts: map[string]int{
				"루루무": 4,
				"공통어": 2,
			},
		},
		{
			ArticleID:      "2",
			TotalPages:     1,
			DialogueCount:  3,
			CharacterCount: 15,
			TermCounts: map[string]int{
				"미카":  3,
				"공통어": 3,
			},
		},
	}

	rows := rankWorkKeywords(docs, 2, 1, 1, 1.0)
	if len(rows) != 4 {
		t.Fatalf("rows = %d, want 4", len(rows))
	}
	if rows[0].ArticleID != "1" || rows[0].Keyword != "루루무" || rows[0].Rank != 1 {
		t.Fatalf("first row = %#v", rows[0])
	}
	if rows[2].ArticleID != "2" || rows[2].Keyword != "미카" || rows[2].Rank != 1 {
		t.Fatalf("third row = %#v", rows[2])
	}
}

func TestExtractFromRawAndWriteCSV(t *testing.T) {
	tmp := t.TempDir()
	rawDir := filepath.Join(tmp, "raw")
	if err := os.Mkdir(rawDir, 0o755); err != nil {
		t.Fatal(err)
	}
	raw := `{"pages":[{"dialogues":[{"text":"루루무 루루무","confidence":0.99},{"text":"역자8GB","confidence":0.99}]},{"dialogues":[{"text":"미카 루루무","confidence":0.4},{"text":"온천 온천","confidence":0.99}]}]}`
	if err := os.WriteFile(filepath.Join(rawDir, "123.json"), []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}

	doc, err := loadWorkDocument(filepath.Join(rawDir, "123.json"), 0.5, 2, false)
	if err != nil {
		t.Fatal(err)
	}
	if doc == nil {
		t.Fatal("document is nil")
	}
	if doc.TermCounts["루루무"] != 2 || doc.TermCounts["온천"] != 2 {
		t.Fatalf("term counts = %#v", doc.TermCounts)
	}

	rows := rankWorkKeywords([]workDocument{*doc}, 10, 1, 2, 1.0)
	out := filepath.Join(tmp, "keywords.csv")
	if err := writeKeywordCSV(rows, out); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(out)
	if err != nil {
		t.Fatal(err)
	}
	if got := string(data); !containsAll(got, []string{"article_id,rank,keyword,score,tf,df,total_pages,dialogue_count,char_count", "123,1,"}) {
		t.Fatalf("unexpected csv:\n%s", got)
	}
	readRows, err := readKeywordCSV(out)
	if err != nil {
		t.Fatal(err)
	}
	if len(readRows) == 0 {
		t.Fatal("read rows is empty")
	}
	if readRows[0].TotalPages != 2 || readRows[0].DialogueCount != 3 || readRows[0].CharacterCount == 0 {
		t.Fatalf("read stats = pages %d dialogues %d chars %d", readRows[0].TotalPages, readRows[0].DialogueCount, readRows[0].CharacterCount)
	}
}

func containsAll(text string, needles []string) bool {
	for _, needle := range needles {
		if !contains(text, needle) {
			return false
		}
	}
	return true
}

func contains(text, needle string) bool {
	for i := 0; i+len(needle) <= len(text); i++ {
		if text[i:i+len(needle)] == needle {
			return true
		}
	}
	return false
}
