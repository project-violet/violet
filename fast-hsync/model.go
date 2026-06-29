package main

import (
	"strconv"
	"strings"
	"time"
)

// HitomiArticle represents a parsed gallery entry from HTML.
type HitomiArticle struct {
	Artists    []string
	Characters []string
	Groups     []string
	Language   string
	Series     []string
	Tags       []string
	Type       string
	DateTime   string
	Thumbnail  string
	Magic      string
	Title      string
	Files      string
}

// HitomiColumnModel matches the SQLite schema from the C# version.
type HitomiColumnModel struct {
	ID            int        `json:"Id"`
	Title         string     `json:"Title"`
	EHash         string     `json:"EHash,omitempty"`
	Type          string     `json:"Type"`
	Artists       string     `json:"Artists"`
	Characters    string     `json:"Characters,omitempty"`
	Groups        string     `json:"Groups,omitempty"`
	Language      string     `json:"Language"`
	Series        string     `json:"Series,omitempty"`
	Tags          string     `json:"Tags,omitempty"`
	Uploader      string     `json:"Uploader,omitempty"`
	Published     *time.Time `json:"Published,omitempty"`
	Files         int        `json:"Files"`
	Class         string     `json:"Class,omitempty"`
	ExistOnHitomi int        `json:"ExistOnHitomi"`
	Thumbnail     string     `json:"Thumbnail,omitempty"`
}

var languageMap = map[string]string{
	"모든 언어":         "all",
	"한국어":            "korean",
	"N/A":              "n/a",
	"日本語":            "japanese",
	"English":          "english",
	"Español":          "spanish",
	"ไทย":              "thai",
	"Deutsch":          "german",
	"中文":             "chinese",
	"Português":        "portuguese",
	"Français":         "french",
	"Tagalog":          "tagalog",
	"Русский":          "russian",
	"Italiano":         "italian",
	"polski":           "polish",
	"tiếng việt":       "vietnamese",
	"magyar":           "hungarian",
	"Čeština":          "czech",
	"Bahasa Indonesia": "indonesian",
	"العربية":          "arabic",
}

func legalizeLanguage(lang string) string {
	if mapped, ok := languageMap[lang]; ok {
		return mapped
	}
	return lang
}

func legalizeTag(tag string) string {
	tag = strings.TrimSpace(tag)
	if strings.HasSuffix(tag, "♀") {
		return "female:" + strings.TrimSpace(strings.TrimSuffix(tag, "♀"))
	}
	if strings.HasSuffix(tag, "♂") {
		return "male:" + strings.TrimSpace(strings.TrimSuffix(tag, "♂"))
	}
	return tag
}

func extractID(magic string) (int, error) {
	if strings.Contains(magic, "-") {
		parts := strings.Split(magic, "-")
		last := parts[len(parts)-1]
		last = strings.SplitN(last, ".", 2)[0]
		return strconv.Atoi(last)
	}
	if strings.Contains(magic, "galleries") {
		parts := strings.Split(magic, "/")
		last := parts[len(parts)-1]
		last = strings.SplitN(last, ".", 2)[0]
		return strconv.Atoi(last)
	}
	return strconv.Atoi(strings.TrimSpace(magic))
}

func articleToColumnModel(art *HitomiArticle, id int) *HitomiColumnModel {
	m := &HitomiColumnModel{
		ID:            id,
		Title:         art.Title,
		Type:          art.Type,
		Language:      art.Language,
		ExistOnHitomi: 1,
		Thumbnail:     art.Thumbnail,
	}

	if m.Language == "" {
		m.Language = "n/a"
	}

	if len(art.Artists) > 0 && art.Artists[0] != "" {
		m.Artists = "|" + strings.Join(art.Artists, "|") + "|"
	} else {
		m.Artists = "|N/A|"
	}
	if len(art.Characters) > 0 && art.Characters[0] != "" {
		m.Characters = "|" + strings.Join(art.Characters, "|") + "|"
	}
	if len(art.Groups) > 0 && art.Groups[0] != "" {
		m.Groups = "|" + strings.Join(art.Groups, "|") + "|"
	}
	if len(art.Series) > 0 && art.Series[0] != "" {
		m.Series = "|" + strings.Join(art.Series, "|") + "|"
	}
	if len(art.Tags) > 0 && art.Tags[0] != "" {
		m.Tags = "|" + strings.Join(art.Tags, "|") + "|"
	}

	if art.Files != "" {
		m.Files, _ = strconv.Atoi(art.Files)
	}

	if art.DateTime != "" {
		layouts := []string{
			"2006-01-02 15:04:05-07",
			"2006-01-02 15:04:05-0700",
			"2006-01-02 15:04:05",
			time.RFC3339,
		}
		for _, layout := range layouts {
			if t, err := time.Parse(layout, strings.TrimSpace(art.DateTime)); err == nil {
				m.Published = &t
				break
			}
		}
	}

	return m
}
