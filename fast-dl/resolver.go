package main

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/dop251/goja"
)

//go:embed scripts/hitomi_get_image_list_v3_model.js
var hitomiV3Model string

const hitomiUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

type HitomiResolver struct {
	client         *http.Client
	ggURL          string
	galleryBaseURL string

	mu           sync.Mutex
	scriptCache  string
	scriptCached time.Time
	cacheTTL     time.Duration
}

type resolvedImageList struct {
	Result []string `json:"result"`
}

func NewHitomiResolver(client *http.Client) *HitomiResolver {
	return &HitomiResolver{
		client:   client,
		ggURL:    "https://ltn.gold-usergeneratedcontent.net/gg.js",
		cacheTTL: 30 * time.Minute,
	}
}

func (r *HitomiResolver) ResolveFiles(ctx context.Context, id string) ([]FileRef, error) {
	script, err := r.ensureScript(ctx)
	if err != nil {
		return nil, err
	}

	vm := goja.New()
	if _, err := vm.RunString(script); err != nil {
		return nil, err
	}

	downloadURL, err := r.createDownloadURL(vm, id)
	if err != nil {
		return nil, err
	}
	if r.galleryBaseURL != "" {
		downloadURL = strings.TrimRight(r.galleryBaseURL, "/") + "/" + id + ".js"
	}

	headers, err := r.galleryHeaders(vm, id)
	if err != nil {
		return nil, err
	}

	galleryInfo, err := fetchText(ctx, r.client, downloadURL, headers)
	if err != nil {
		return nil, err
	}
	if _, err := vm.RunString(galleryInfo); err != nil {
		return nil, err
	}

	value, ok := goja.AssertFunction(vm.Get("hitomi_get_image_list"))
	if !ok {
		return nil, fmt.Errorf("hitomi_get_image_list is not a function")
	}
	resultValue, err := value(goja.Undefined())
	if err != nil {
		return nil, err
	}

	var parsed resolvedImageList
	if err := json.Unmarshal([]byte(resultValue.String()), &parsed); err != nil {
		return nil, err
	}
	if len(parsed.Result) == 0 {
		return nil, fmt.Errorf("empty resolved image list for %s", id)
	}
	return imageURLsToFileRefs(parsed.Result), nil
}

func (r *HitomiResolver) ensureScript(ctx context.Context) (string, error) {
	r.mu.Lock()
	if r.scriptCache != "" && time.Since(r.scriptCached) < r.cacheTTL {
		script := r.scriptCache
		r.mu.Unlock()
		return script, nil
	}
	r.mu.Unlock()

	ggBody, err := fetchText(ctx, r.client, r.ggURL, map[string]string{"User-Agent": hitomiUserAgent})
	if err != nil {
		return "", err
	}
	gg, err := parseGg(ggBody)
	if err != nil {
		return "", err
	}
	script := strings.ReplaceAll(hitomiV3Model, "%%gg.m%", gg.M)
	script = strings.ReplaceAll(script, "%%gg.b%", gg.B)
	script = strings.ReplaceAll(script, "%%gg.s%", gg.S)

	r.mu.Lock()
	r.scriptCache = script
	r.scriptCached = time.Now()
	r.mu.Unlock()
	return script, nil
}

func (r *HitomiResolver) createDownloadURL(vm *goja.Runtime, id string) (string, error) {
	fn, ok := goja.AssertFunction(vm.Get("create_download_url"))
	if !ok {
		return "", fmt.Errorf("create_download_url is not a function")
	}
	value, err := fn(goja.Undefined(), vm.ToValue(id))
	if err != nil {
		return "", err
	}
	return value.String(), nil
}

func (r *HitomiResolver) galleryHeaders(vm *goja.Runtime, id string) (map[string]string, error) {
	fn, ok := goja.AssertFunction(vm.Get("hitomi_get_header_content"))
	if !ok {
		return nil, fmt.Errorf("hitomi_get_header_content is not a function")
	}
	value, err := fn(goja.Undefined(), vm.ToValue(id))
	if err != nil {
		return nil, err
	}

	var headers map[string]string
	if err := json.Unmarshal([]byte(value.String()), &headers); err != nil {
		return nil, err
	}
	headers["User-Agent"] = hitomiUserAgent
	return headers, nil
}

type ggParts struct {
	M string
	B string
	S string
}

func parseGg(body string) (ggParts, error) {
	code := body
	if parts := strings.SplitN(body, "'use strict';", 2); len(parts) == 2 {
		code = parts[1]
	}

	vm := goja.New()
	if _, err := vm.RunString(code); err != nil {
		return ggParts{}, err
	}

	mValue, err := vm.RunString(`var r = ""; for (var i = 0; i < 4096; i++) { r += gg.m(i).toString() + ","; } r`)
	if err != nil {
		return ggParts{}, err
	}
	bValue, err := vm.RunString("gg.b")
	if err != nil {
		return ggParts{}, err
	}
	sValue, err := vm.RunString("gg.s.toString()")
	if err != nil {
		return ggParts{}, err
	}
	return ggParts{M: mValue.String(), B: bValue.String(), S: sValue.String()}, nil
}

func fetchText(ctx context.Context, client *http.Client, rawURL string, headers map[string]string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return "", err
	}
	for key, value := range headers {
		req.Header.Set(key, value)
	}
	if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", hitomiUserAgent)
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("http %d fetching %s", resp.StatusCode, rawURL)
	}
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func imageURLsToFileRefs(urls []string) []FileRef {
	files := make([]FileRef, 0, len(urls))
	for i, imageURL := range urls {
		files = append(files, FileRef{
			Num: i + 1,
			URL: imageURL,
			Ext: extensionFromURL(imageURL),
		})
	}
	return files
}

func extensionFromURL(rawURL string) string {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "webp"
	}
	ext := strings.TrimPrefix(filepath.Ext(parsed.Path), ".")
	if ext == "" {
		return "webp"
	}
	if _, err := strconv.Atoi(ext); err == nil {
		return "webp"
	}
	return ext
}
