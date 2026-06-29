package main

import (
	"encoding/json"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

// parseGalleryBlock parses a galleryblock HTML fragment into a HitomiArticle.
// Mirrors the C# HitomiParser.ParseGalleryBlock logic.
func parseGalleryBlock(html string) (*HitomiArticle, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil, err
	}

	root := doc.Find("div").First()
	art := &HitomiArticle{}

	// Magic = href of first <a>
	art.Magic, _ = root.Children().Filter("a").First().Attr("href")

	// Thumbnail
	img := root.Find("a img").First()
	thumb, exists := img.Attr("data-src")
	if !exists || thumb == "" {
		thumb, _ = img.Attr("src")
	}
	if idx := strings.Index(thumb, "//tn.hitomi.la/"); idx >= 0 {
		thumb = thumb[idx+len("//tn.hitomi.la/"):]
	}
	thumb = strings.ReplaceAll(thumb, "smallbig", "big")
	art.Thumbnail = thumb

	// Title
	art.Title = strings.TrimSpace(root.Find("h1").First().Text())

	// Artists from .artist-list
	root.Find(".artist-list li").Each(func(_ int, s *goquery.Selection) {
		if a := s.Find("a").First(); a.Length() > 0 {
			art.Artists = append(art.Artists, strings.TrimSpace(a.Text()))
		}
	})
	if len(art.Artists) == 0 {
		art.Artists = []string{"N/A"}
	}

	// Content table is inside the second <div> child of root
	contentDiv := root.Children().Filter("div").Eq(1)
	table := contentDiv.Find("table").First()
	rows := table.Find("tr")

	// Row 0: Series (td:nth-child(2) ul li a)
	if rows.Length() > 0 {
		rows.Eq(0).Find("td").Eq(1).Find("ul li").Each(func(_ int, s *goquery.Selection) {
			if a := s.Find("a").First(); a.Length() > 0 {
				art.Series = append(art.Series, strings.TrimSpace(a.Text()))
			}
		})
	}

	// Row 1: Type
	if rows.Length() > 1 {
		art.Type = strings.TrimSpace(rows.Eq(1).Find("td").Eq(1).Find("a").First().Text())
	}

	// Row 2: Language
	if rows.Length() > 2 {
		lang := strings.TrimSpace(rows.Eq(2).Find("td").Eq(1).Find("a").First().Text())
		art.Language = legalizeLanguage(lang)
	}

	// Row 3: Tags
	if rows.Length() > 3 {
		rows.Eq(3).Find("td").Eq(1).Find("ul li").Each(func(_ int, s *goquery.Selection) {
			if a := s.Find("a").First(); a.Length() > 0 {
				art.Tags = append(art.Tags, legalizeTag(a.Text()))
			}
		})
	}

	// DateTime from <p> inside content div
	art.DateTime = strings.TrimSpace(contentDiv.Children().Filter("p").First().Text())

	return art, nil
}

// parseGallery parses a full gallery page to extract Groups and Characters.
// Mirrors HitomiParser.ParseGallery.
func parseGallery(html string) (groups []string, characters []string) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return
	}

	// Check for redirect page
	title := strings.TrimSpace(doc.Find("title").First().Text())
	if title == "Redirect" {
		return
	}

	doc.Find(".gallery-info table tr").Each(func(_ int, s *goquery.Selection) {
		label := strings.ToLower(strings.TrimSpace(s.Find("td").First().Text()))
		switch label {
		case "group":
			s.Find("a").Each(func(_ int, a *goquery.Selection) {
				groups = append(groups, strings.TrimSpace(a.Text()))
			})
		case "characters":
			s.Find("a").Each(func(_ int, a *goquery.Selection) {
				characters = append(characters, strings.TrimSpace(a.Text()))
			})
		}
	})
	return
}

// GalleryInfo holds the parsed result from a gallery JS response.
type GalleryInfo struct {
	Files      int
	Groups     []string
	Characters []string
}

// parseGalleryJS parses a gallery JS response for file count, groups, and characters.
// The JS format is: var galleryinfo = { "files": [...], "groups": [...], ... };
func parseGalleryJS(js string) GalleryInfo {
	var info GalleryInfo

	jsonStr := extractGalleryJSON(js)
	if jsonStr == "" {
		return info
	}

	var data struct {
		Files      []json.RawMessage `json:"files"`
		Groups     []struct {
			Group string `json:"group"`
		} `json:"groups"`
		Characters []struct {
			Character string `json:"character"`
		} `json:"characters"`
	}
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		return info
	}

	info.Files = len(data.Files)
	for _, g := range data.Groups {
		if g.Group != "" {
			info.Groups = append(info.Groups, g.Group)
		}
	}
	for _, c := range data.Characters {
		if c.Character != "" {
			info.Characters = append(info.Characters, c.Character)
		}
	}
	return info
}

// extractGalleryJSON extracts the JSON object from "var galleryinfo = {...};"
func extractGalleryJSON(js string) string {
	parts := strings.SplitN(js, "var galleryinfo = ", 2)
	if len(parts) < 2 {
		return ""
	}
	s := parts[1]
	depth := 0
	for i, ch := range s {
		switch ch {
		case '{':
			depth++
		case '}':
			depth--
			if depth == 0 {
				return s[:i+1]
			}
		}
	}
	return ""
}
