package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

type FileRef struct {
	Num int
	URL string
	Ext string
}

type Work struct {
	ID    string
	Files []FileRef
	Bytes int64
}

type Setting struct {
	WorkWorkers int
	FileWorkers int
	Label       string
}

type WorkResult struct {
	ID      string
	OK      bool
	Files   int
	Bytes   int64
	Elapsed time.Duration
	Err     error
}

type httpStatusError struct {
	StatusCode int
}

func (e httpStatusError) Error() string {
	return fmt.Sprintf("http %d", e.StatusCode)
}

var defaultTmpDir = filepath.Join("..", "tmp2-go")

type GalleryResolver interface {
	ResolveFiles(ctx context.Context, id string) ([]FileRef, error)
}

type options struct {
	count          int
	targetIDsPath  string
	tmpDir         string
	maxPages       int
	retries        int
	settingsArg    string
	idsArg         string
	keepTmp        bool
	downloadWorkID string
	fileWorkers    int
}

func parseOptions(args []string) (options, error) {
	fs := flag.NewFlagSet("fast-dl", flag.ContinueOnError)
	fs.SetOutput(io.Discard)

	opts := options{tmpDir: defaultTmpDir}
	fs.IntVar(&opts.count, "count", 4, "number of works to benchmark")
	fs.StringVar(&opts.targetIDsPath, "target-ids", filepath.Join("..", "works", "target_ids.json"), "target IDs JSON path")
	fs.IntVar(&opts.maxPages, "max-pages", 200, "skip works with more than this many pages")
	fs.IntVar(&opts.retries, "file-retries", 100, "retries per image")
	fs.StringVar(&opts.settingsArg, "settings", "2x64,2x32,4x16,4x32,1x32,1x64", "comma-separated workWorkers x fileWorkers settings")
	fs.StringVar(&opts.idsArg, "ids", "", "comma-separated explicit IDs")
	fs.BoolVar(&opts.keepTmp, "keep-tmp", false, "do not clean tmp dir between settings")
	fs.StringVar(&opts.downloadWorkID, "download-work", "", "download a single work and exit")
	fs.IntVar(&opts.fileWorkers, "file-workers", 64, "file workers for --download-work")

	if err := fs.Parse(args); err != nil {
		return options{}, err
	}
	return opts, nil
}

func main() {
	opts, err := parseOptions(os.Args[1:])
	must(err)
	resolver := NewHitomiResolver(makeHTTPClient())

	if opts.downloadWorkID != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		files, err := resolver.ResolveFiles(ctx, opts.downloadWorkID)
		must(err)
		if opts.maxPages > 0 && len(files) > opts.maxPages {
			fmt.Printf("PAGE_LIMIT id=%s files=%d max=%d\n", opts.downloadWorkID, len(files), opts.maxPages)
			return
		}
		work := Work{ID: opts.downloadWorkID, Files: files}
		must(os.MkdirAll(opts.tmpDir, 0755))
		client := makeHTTPClient()
		result := downloadWork(client, opts.tmpDir, work, opts.fileWorkers, opts.retries)
		status := "OK"
		if !result.OK {
			status = "FAIL"
		}
		fmt.Printf(
			"%s id=%s files=%d expected=%d bytes=%d elapsed=%.2f\n",
			status,
			result.ID,
			result.Files,
			len(files),
			result.Bytes,
			result.Elapsed.Seconds(),
		)
		if result.Err != nil {
			fmt.Fprintln(os.Stderr, result.Err)
		}
		if !result.OK {
			os.Exit(1)
		}
		return
	}

	settings, err := parseSettings(opts.settingsArg)
	must(err)

	fmt.Println("Resolving works...")
	resolveStart := time.Now()
	works, err := selectWorks(opts.targetIDsPath, opts.idsArg, opts.count, opts.maxPages, resolver)
	must(err)
	fmt.Printf("Resolved %d works in %.2fs\n", len(works), time.Since(resolveStart).Seconds())
	for _, work := range works {
		fmt.Printf("  %s files=%d\n", work.ID, len(work.Files))
	}
	fmt.Println()

	var summaries []string
	for _, setting := range settings {
		if !opts.keepTmp {
			must(os.RemoveAll(opts.tmpDir))
		}
		must(os.MkdirAll(opts.tmpDir, 0755))

		fmt.Printf("== %s ==\n", setting.Label)
		elapsed, results := runSetting(works, opts.tmpDir, setting, opts.retries)

		var ok, files int
		var bytes int64
		for _, result := range results {
			status := "ok"
			if !result.OK {
				status = "fail"
			}
			fmt.Printf("  %s %s %d files %.1fMiB %.2fs", result.ID, status, result.Files, mib(result.Bytes), result.Elapsed.Seconds())
			if result.Err != nil {
				fmt.Printf(" err=%v", result.Err)
			}
			fmt.Println()
			if result.OK {
				ok++
				files += result.Files
				bytes += result.Bytes
			}
		}
		rate := mib(bytes) / elapsed.Seconds()
		filesPerSec := float64(files) / elapsed.Seconds()
		summary := fmt.Sprintf(
			"%s: works=%d/%d files=%d bytes=%.1fMiB elapsed=%.2fs rate=%.2fMiB/s files/s=%.2f",
			setting.Label, ok, len(results), files, mib(bytes), elapsed.Seconds(), rate, filesPerSec,
		)
		fmt.Println("SUMMARY " + summary)
		fmt.Println()
		summaries = append(summaries, summary)
	}

	fmt.Println("== summaries ==")
	for _, summary := range summaries {
		fmt.Println(summary)
	}
}

func parseSettings(input string) ([]Setting, error) {
	parts := strings.Split(input, ",")
	settings := make([]Setting, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		pair := strings.Split(strings.ToLower(part), "x")
		if len(pair) != 2 {
			return nil, fmt.Errorf("invalid setting %q", part)
		}
		workWorkers, err := strconv.Atoi(pair[0])
		if err != nil {
			return nil, err
		}
		fileWorkers, err := strconv.Atoi(pair[1])
		if err != nil {
			return nil, err
		}
		settings = append(settings, Setting{WorkWorkers: workWorkers, FileWorkers: fileWorkers, Label: part})
	}
	return settings, nil
}

func selectWorks(targetIDsPath, idsArg string, count, maxPages int, resolver GalleryResolver) ([]Work, error) {
	var ids []string
	if idsArg != "" {
		ids = strings.Split(idsArg, ",")
		for i := range ids {
			ids[i] = strings.TrimSpace(ids[i])
		}
	} else {
		data, err := os.ReadFile(targetIDsPath)
		if err != nil {
			return nil, err
		}
		var rawIDs []int
		if err := json.Unmarshal(data, &rawIDs); err != nil {
			return nil, err
		}
		for i := len(rawIDs) - 1; i >= 0; i-- {
			ids = append(ids, strconv.Itoa(rawIDs[i]))
		}
	}

	var selected []Work
	for _, id := range ids {
		if id == "" {
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		files, err := resolver.ResolveFiles(ctx, id)
		cancel()
		if err != nil {
			fmt.Printf("  skip %s resolve error: %v\n", id, err)
			continue
		}
		if maxPages > 0 && len(files) > maxPages {
			fmt.Printf("  skip %s pages=%d > %d\n", id, len(files), maxPages)
			continue
		}
		selected = append(selected, Work{ID: id, Files: files})
		if len(selected) >= count {
			break
		}
	}

	sort.Slice(selected, func(i, j int) bool {
		a, _ := strconv.Atoi(selected[i].ID)
		b, _ := strconv.Atoi(selected[j].ID)
		return a < b
	})
	return selected, nil
}

func runSetting(works []Work, tmpDir string, setting Setting, retries int) (time.Duration, []WorkResult) {
	start := time.Now()
	jobs := make(chan Work)
	results := make(chan WorkResult, len(works))
	client := makeHTTPClient()

	var wg sync.WaitGroup
	for i := 0; i < setting.WorkWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for work := range jobs {
				results <- downloadWork(client, tmpDir, work, setting.FileWorkers, retries)
			}
		}()
	}

	for _, work := range works {
		jobs <- work
	}
	close(jobs)
	wg.Wait()
	close(results)

	var collected []WorkResult
	for result := range results {
		collected = append(collected, result)
	}
	sort.Slice(collected, func(i, j int) bool { return collected[i].ID < collected[j].ID })
	return time.Since(start), collected
}

func makeHTTPClient() *http.Client {
	transport := &http.Transport{
		Proxy:               http.ProxyFromEnvironment,
		MaxIdleConns:        512,
		MaxIdleConnsPerHost: 256,
		MaxConnsPerHost:     0,
		IdleConnTimeout:     90 * time.Second,
		DisableCompression:  true,
		DialContext: (&net.Dialer{
			Timeout:   15 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		TLSHandshakeTimeout:   15 * time.Second,
		ResponseHeaderTimeout: 60 * time.Second,
	}
	return &http.Client{Transport: transport, Timeout: 90 * time.Second}
}

func downloadWork(client *http.Client, tmpDir string, work Work, fileWorkers, retries int) WorkResult {
	start := time.Now()
	workDir := filepath.Join(tmpDir, work.ID)
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return WorkResult{ID: work.ID, Err: err, Elapsed: time.Since(start)}
	}

	jobs := make(chan FileRef)
	var wg sync.WaitGroup
	var mu sync.Mutex
	var files int
	var bytes int64
	var firstErr error

	referer := "https://hitomi.la/galleries/" + work.ID + ".html"
	for i := 0; i < fileWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for file := range jobs {
				target := filepath.Join(workDir, fmt.Sprintf("%04d.%s", file.Num, file.Ext))
				n, err := downloadFile(client, file.URL, target, referer, retries)
				mu.Lock()
				if err != nil {
					if firstErr == nil {
						firstErr = err
					}
					mu.Unlock()
					continue
				}
				files++
				bytes += n
				mu.Unlock()
			}
		}()
	}

	for _, file := range work.Files {
		jobs <- file
	}
	close(jobs)
	wg.Wait()

	mu.Lock()
	resultFiles := files
	resultBytes := bytes
	err := firstErr
	mu.Unlock()
	return WorkResult{
		ID:      work.ID,
		OK:      err == nil && resultFiles == len(work.Files),
		Files:   resultFiles,
		Bytes:   resultBytes,
		Elapsed: time.Since(start),
		Err:     err,
	}
}

func downloadFile(client *http.Client, fileURL, target, referer string, retries int) (int64, error) {
	var lastErr error
	part := target + ".part"
	for attempt := 0; attempt <= retries; attempt++ {
		n, err := tryDownloadFile(client, fileURL, part, target, referer)
		if err == nil {
			return n, nil
		}
		lastErr = err
		_ = os.Remove(part)
		if !shouldRetryDownload(err, attempt, retries) {
			break
		}
		time.Sleep(retryDelay(err, attempt))
	}
	return 0, lastErr
}

func shouldRetryDownload(err error, attempt, retries int) bool {
	if attempt >= retries {
		return false
	}
	var statusErr httpStatusError
	if !errors.As(err, &statusErr) {
		return true
	}
	switch statusErr.StatusCode {
	case http.StatusTooManyRequests, http.StatusInternalServerError, http.StatusBadGateway, http.StatusServiceUnavailable, http.StatusGatewayTimeout:
		return true
	default:
		return false
	}
}

func retryDelay(err error, attempt int) time.Duration {
	var statusErr httpStatusError
	if errors.As(err, &statusErr) {
		return 100 * time.Millisecond
	}
	return time.Second
}

func tryDownloadFile(client *http.Client, fileURL, part, target, referer string) (int64, error) {
	req, err := http.NewRequest(http.MethodGet, fileURL, nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("User-Agent", "fast-dl/0.1")
	req.Header.Set("Referer", referer)

	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return 0, httpStatusError{StatusCode: resp.StatusCode}
	}

	out, err := os.Create(part)
	if err != nil {
		return 0, err
	}
	n, copyErr := io.CopyBuffer(out, resp.Body, make([]byte, 256*1024))
	closeErr := out.Close()
	if copyErr != nil {
		return 0, copyErr
	}
	if closeErr != nil {
		return 0, closeErr
	}
	return n, os.Rename(part, target)
}

func mib(bytes int64) float64 {
	return float64(bytes) / (1024 * 1024)
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
