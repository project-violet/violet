package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHitomiResolverBuildsFileRefsFromGalleryScript(t *testing.T) {
	const ggBody = `
'use strict';
var gg = {
  m: function(g) { return g % 2; },
  b: "base/",
  s: function(h) { return h.substring(h.length - 1); }
};
`
	const hashA = "000000000000000000000000000000000000000000000000000000000000abc"
	const hashB = "111111111111111111111111111111111111111111111111111111111111def"

	var gallerySeen bool
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/gg.js":
			_, _ = w.Write([]byte(ggBody))
		case "/galleries/123.js":
			gallerySeen = true
			if got := r.Header.Get("Referer"); got != "https://hitomi.la/reader/123.html" {
				t.Fatalf("referer = %q", got)
			}
			_, _ = w.Write([]byte(`var galleryinfo = {"id":123,"files":[{"hash":"` + hashA + `","name":"001.jpg","hasavif":1,"haswebp":1},{"hash":"` + hashB + `","name":"002.png","hasavif":0,"haswebp":1}]};`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()

	resolver := NewHitomiResolver(server.Client())
	resolver.ggURL = server.URL + "/gg.js"
	resolver.galleryBaseURL = server.URL + "/galleries"
	files, err := resolver.ResolveFiles(context.Background(), "123")
	if err != nil {
		t.Fatal(err)
	}
	if !gallerySeen {
		t.Fatal("gallery script was not fetched")
	}
	if len(files) != 2 {
		t.Fatalf("len(files) = %d", len(files))
	}
	if files[0].Num != 1 || files[0].Ext != "avif" {
		t.Fatalf("files[0] = %+v", files[0])
	}
	if files[1].Num != 2 || files[1].Ext != "webp" {
		t.Fatalf("files[1] = %+v", files[1])
	}
	if files[0].URL == "" || files[1].URL == "" {
		t.Fatalf("empty URLs: %+v", files)
	}
}

func TestParseResolvedImageList(t *testing.T) {
	raw := `{"result":["https://a.example/1.avif","https://b.example/2.webp"],"btresult":[],"stresult":[]}`
	var parsed resolvedImageList
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		t.Fatal(err)
	}
	files := imageURLsToFileRefs(parsed.Result)
	if len(files) != 2 {
		t.Fatalf("len(files) = %d", len(files))
	}
	if files[0].Num != 1 || files[0].Ext != "avif" {
		t.Fatalf("files[0] = %+v", files[0])
	}
	if files[1].Num != 2 || files[1].Ext != "webp" {
		t.Fatalf("files[1] = %+v", files[1])
	}
}
