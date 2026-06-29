package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"html/template"
	"net/http"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
)

type serveOptions struct {
	inputPath string
	host      string
	port      int
}

type keywordGraphServer struct {
	index keywordIndex
}

func runServe(args []string) error {
	opts := parseServeFlags(args)
	rows, err := readKeywordCSV(opts.inputPath)
	if err != nil {
		return err
	}
	addr := fmt.Sprintf("%s:%d", opts.host, opts.port)
	fmt.Printf("loaded keyword_rows=%d input=%s\n", len(rows), opts.inputPath)
	fmt.Printf("Keyword Graph: http://%s\n", addr)
	return http.ListenAndServe(addr, newKeywordGraphServer(rows))
}

func parseServeFlags(args []string) serveOptions {
	var opts serveOptions
	flags := flag.NewFlagSet("serve", flag.ExitOnError)
	flags.StringVar(&opts.inputPath, "input", filepath.Join("..", "..", "artifacts", "dialogue-explore", "work-keywords-go.csv"), "Keyword CSV from extract.")
	flags.StringVar(&opts.host, "host", "127.0.0.1", "Host to bind.")
	flags.IntVar(&opts.port, "port", 8787, "Port to bind.")
	flags.Parse(args)
	if opts.port < 1 || opts.port > 65535 {
		fatal(fmt.Errorf("--port must be between 1 and 65535"))
	}
	return opts
}

func newKeywordGraphServer(rows []keywordRow) http.Handler {
	return &keywordGraphServer{index: newKeywordIndex(rows)}
}

func (server *keywordGraphServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	writeCORSHeaders(w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	switch {
	case r.URL.Path == "/":
		server.serveIndex(w, r)
	case r.URL.Path == "/api/graph":
		server.serveGraph(w, r)
	case r.URL.Path == "/api/links":
		server.serveLinks(w, r)
	case r.URL.Path == "/api/works":
		server.serveWorks(w, r)
	default:
		http.NotFound(w, r)
	}
}

func writeCORSHeaders(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
}

func (server *keywordGraphServer) serveIndex(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := keywordGraphHTML.Execute(w, nil); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func (server *keywordGraphServer) serveGraph(w http.ResponseWriter, r *http.Request) {
	opts, err := parseGraphQuery(r)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, err)
		return
	}
	graph := buildKeywordGraphFromIndex(server.index, opts)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(graph); err != nil {
		writeJSONError(w, http.StatusInternalServerError, err)
	}
}

func (server *keywordGraphServer) serveWorks(w http.ResponseWriter, r *http.Request) {
	opts, err := parseWorksQuery(r)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, err)
		return
	}
	works := findRelatedWorksFromIndex(server.index, opts)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(works); err != nil {
		writeJSONError(w, http.StatusInternalServerError, err)
	}
}

func (server *keywordGraphServer) serveLinks(w http.ResponseWriter, r *http.Request) {
	opts, err := parseLinksQuery(r)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, err)
		return
	}
	links := findRelatedLinksFromIndex(server.index, opts)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(links); err != nil {
		writeJSONError(w, http.StatusInternalServerError, err)
	}
}

func parseGraphQuery(r *http.Request) (graphOptions, error) {
	values := r.URL.Query()
	opts := graphOptions{
		query:          strings.TrimSpace(values.Get("query")),
		queries:        splitGraphQueryValues(values),
		expand:         queryString(values, "expand", "none"),
		depth:          queryInt(values, 2, "depth"),
		topN:           queryInt(values, 20, "topN", "top_n"),
		minScore:       queryFloat(values, 0, "minScore", "min_score"),
		minCooccur:     queryInt(values, 0, "minCooccur", "min_cooccur"),
		autoMinCooccur: queryBool(values, true, "autoMinCooccur", "auto_min_cooccur"),
		minKeywordDF:   queryInt(values, 5, "minKeywordDF", "min_keyword_df"),
		maxNodes:       queryInt(values, 250, "maxNodes", "max_nodes"),
	}
	if opts.query == "" && len(opts.queries) == 0 {
		return opts, fmt.Errorf("query is required")
	}
	if opts.expand != "none" && opts.expand != "contains" {
		return opts, fmt.Errorf("expand must be none or contains")
	}
	if opts.depth < 0 {
		return opts, fmt.Errorf("depth must be >= 0")
	}
	if opts.depth > 5 {
		opts.depth = 5
	}
	if opts.topN < 1 {
		return opts, fmt.Errorf("topN must be >= 1")
	}
	if opts.topN > 200 {
		opts.topN = 200
	}
	if opts.minScore < 0 {
		return opts, fmt.Errorf("minScore must be >= 0")
	}
	if opts.autoMinCooccur {
		if opts.minCooccur < 0 {
			return opts, fmt.Errorf("minCooccur must be >= 0 when autoMinCooccur is enabled")
		}
	} else if opts.minCooccur < 1 {
		return opts, fmt.Errorf("minCooccur must be >= 1 when autoMinCooccur is disabled")
	}
	if opts.minKeywordDF < 1 {
		return opts, fmt.Errorf("minKeywordDF must be >= 1")
	}
	if opts.maxNodes < 1 {
		return opts, fmt.Errorf("maxNodes must be >= 1")
	}
	if opts.maxNodes > 2000 {
		opts.maxNodes = 2000
	}
	return opts, nil
}

func parseLinksQuery(r *http.Request) (relatedLinksOptions, error) {
	values := r.URL.Query()
	opts := relatedLinksOptions{
		query:        strings.TrimSpace(values.Get("query")),
		keywords:     splitQueryKeywords(values["keywords"]),
		minKeywordDF: queryInt(values, 1, "minKeywordDF", "min_keyword_df"),
		minCooccur:   queryInt(values, 1, "minCooccur", "min_cooccur"),
		limit:        queryInt(values, 50, "limit"),
	}
	if opts.query == "" && len(opts.keywords) == 0 {
		return opts, fmt.Errorf("query or keywords are required")
	}
	if opts.minKeywordDF < 1 {
		return opts, fmt.Errorf("minKeywordDF must be >= 1")
	}
	if opts.minCooccur < 1 {
		return opts, fmt.Errorf("minCooccur must be >= 1")
	}
	if opts.limit < 1 {
		return opts, fmt.Errorf("limit must be >= 1")
	}
	if opts.limit > 200 {
		opts.limit = 200
	}
	return opts, nil
}

func parseWorksQuery(r *http.Request) (relatedWorksOptions, error) {
	values := r.URL.Query()
	opts := relatedWorksOptions{
		mode:           queryString(values, "mode", "graph"),
		query:          strings.TrimSpace(values.Get("query")),
		keywords:       splitQueryKeywords(values["keywords"]),
		match:          queryString(values, "match", "soft"),
		expand:         queryString(values, "expand", "none"),
		depth:          queryInt(values, 2, "depth"),
		topN:           queryInt(values, 20, "topN", "top_n"),
		minScore:       queryFloat(values, 0, "minScore", "min_score"),
		minCooccur:     queryInt(values, 0, "minCooccur", "min_cooccur"),
		autoMinCooccur: queryBool(values, true, "autoMinCooccur", "auto_min_cooccur"),
		minKeywordDF:   queryInt(values, 5, "minKeywordDF", "min_keyword_df"),
		maxNodes:       queryInt(values, 250, "maxNodes", "max_nodes"),
		limit:          queryInt(values, 30, "limit"),
	}
	if opts.mode != "graph" && opts.mode != "selected" {
		return opts, fmt.Errorf("mode must be graph or selected")
	}
	if opts.match != "soft" && opts.match != "all" {
		return opts, fmt.Errorf("match must be soft or all")
	}
	if opts.expand != "none" && opts.expand != "contains" {
		return opts, fmt.Errorf("expand must be none or contains")
	}
	if opts.mode == "graph" && opts.query == "" {
		return opts, fmt.Errorf("query is required")
	}
	if opts.mode == "selected" && len(opts.keywords) == 0 {
		return opts, fmt.Errorf("keywords are required")
	}
	if opts.depth < 0 {
		return opts, fmt.Errorf("depth must be >= 0")
	}
	if opts.depth > 5 {
		opts.depth = 5
	}
	if opts.topN < 1 {
		return opts, fmt.Errorf("topN must be >= 1")
	}
	if opts.topN > 200 {
		opts.topN = 200
	}
	if opts.minScore < 0 {
		return opts, fmt.Errorf("minScore must be >= 0")
	}
	if opts.autoMinCooccur {
		if opts.minCooccur < 0 {
			return opts, fmt.Errorf("minCooccur must be >= 0 when autoMinCooccur is enabled")
		}
	} else if opts.minCooccur < 1 {
		return opts, fmt.Errorf("minCooccur must be >= 1 when autoMinCooccur is disabled")
	}
	if opts.minKeywordDF < 1 {
		return opts, fmt.Errorf("minKeywordDF must be >= 1")
	}
	if opts.maxNodes < 1 {
		return opts, fmt.Errorf("maxNodes must be >= 1")
	}
	if opts.maxNodes > 2000 {
		opts.maxNodes = 2000
	}
	if opts.limit < 1 {
		return opts, fmt.Errorf("limit must be >= 1")
	}
	if opts.limit > 200 {
		opts.limit = 200
	}
	return opts, nil
}

func writeJSONError(w http.ResponseWriter, status int, err error) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
}

func queryString(values url.Values, name string, fallback string) string {
	if value := strings.TrimSpace(values.Get(name)); value != "" {
		return value
	}
	return fallback
}

func queryInt(values url.Values, fallback int, names ...string) int {
	for _, name := range names {
		raw := strings.TrimSpace(values.Get(name))
		if raw == "" {
			continue
		}
		value, err := strconv.Atoi(raw)
		if err == nil {
			return value
		}
	}
	return fallback
}

func queryFloat(values url.Values, fallback float64, names ...string) float64 {
	for _, name := range names {
		raw := strings.TrimSpace(values.Get(name))
		if raw == "" {
			continue
		}
		value, err := strconv.ParseFloat(raw, 64)
		if err == nil {
			return value
		}
	}
	return fallback
}

func queryBool(values url.Values, fallback bool, names ...string) bool {
	for _, name := range names {
		raw := strings.ToLower(strings.TrimSpace(values.Get(name)))
		if raw == "" {
			continue
		}
		switch raw {
		case "1", "true", "yes", "on":
			return true
		case "0", "false", "no", "off":
			return false
		}
	}
	return fallback
}

func splitQueryKeywords(values []string) []string {
	seen := make(map[string]struct{})
	keywords := make([]string, 0)
	for _, value := range values {
		for _, part := range strings.FieldsFunc(value, func(r rune) bool {
			return r == ',' || r == '|'
		}) {
			keyword := strings.TrimSpace(part)
			if keyword == "" {
				continue
			}
			if _, exists := seen[keyword]; exists {
				continue
			}
			seen[keyword] = struct{}{}
			keywords = append(keywords, keyword)
		}
	}
	return keywords
}

func splitGraphQueryValues(values url.Values) []string {
	queries := splitQueryKeywords(values["queries"])
	if len(queries) > 0 {
		return queries
	}
	return splitQueryKeywords(values["query"])
}

var keywordGraphHTML = template.Must(template.New("keyword-graph").Parse(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Keyword Graph</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f6f7f9;
      --panel: #ffffff;
      --line: #d8dee8;
      --text: #17202a;
      --muted: #5e6a78;
      --accent: #1f6feb;
      --accent-2: #13795b;
      --warning: #b7791f;
      --danger: #c73e3e;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: var(--text);
      font-family: "Segoe UI", Arial, sans-serif;
      letter-spacing: 0;
    }
    .app {
      display: grid;
      grid-template-columns: minmax(280px, 340px) minmax(0, 1fr);
      height: 100vh;
    }
    .sidebar {
      border-right: 1px solid var(--line);
      background: var(--panel);
      padding: 16px;
      overflow: auto;
    }
    .main {
      display: grid;
      grid-template-rows: auto minmax(0, 1fr) auto;
      min-width: 0;
    }
    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 12px 16px;
      border-bottom: 1px solid var(--line);
      background: var(--panel);
    }
    h1 {
      margin: 0 0 14px;
      font-size: 20px;
      font-weight: 650;
    }
    h2 {
      margin: 18px 0 8px;
      font-size: 14px;
      font-weight: 650;
      color: var(--muted);
    }
    label {
      display: block;
      margin: 10px 0 5px;
      color: var(--muted);
      font-size: 12px;
      font-weight: 600;
    }
    input, select {
      width: 100%;
      height: 34px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #fff;
      color: var(--text);
      padding: 6px 8px;
      font: inherit;
      font-size: 13px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }
    .button-row {
      display: flex;
      gap: 8px;
      margin-top: 14px;
    }
    button {
      height: 34px;
      border: 1px solid var(--accent);
      border-radius: 6px;
      background: var(--accent);
      color: #fff;
      cursor: pointer;
      font: inherit;
      font-size: 13px;
      font-weight: 650;
      padding: 0 12px;
    }
    button.secondary {
      border-color: var(--line);
      background: #fff;
      color: var(--text);
    }
    .status {
      min-height: 20px;
      color: var(--muted);
      font-size: 13px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .canvas-wrap {
      position: relative;
      min-width: 0;
      min-height: 0;
      background: #fbfcfe;
    }
    #graph-canvas {
      width: 100%;
      height: 100%;
      display: block;
    }
    .details {
      border-top: 1px solid var(--line);
      background: var(--panel);
      padding: 10px 16px;
      min-height: 98px;
      max-height: 170px;
      overflow: auto;
      font-size: 13px;
    }
    .details strong { font-weight: 650; }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
      font-size: 12px;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 5px 4px;
      text-align: left;
      white-space: nowrap;
    }
    th { color: var(--muted); font-weight: 650; }
    .legend {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      color: var(--muted);
      font-size: 12px;
    }
    .swatch {
      display: inline-block;
      width: 10px;
      height: 10px;
      border-radius: 50%;
      margin-right: 4px;
      vertical-align: -1px;
    }
    @media (max-width: 860px) {
      .app {
        grid-template-columns: 1fr;
        grid-template-rows: auto minmax(520px, 1fr);
        height: auto;
        min-height: 100vh;
      }
      .sidebar {
        border-right: 0;
        border-bottom: 1px solid var(--line);
      }
      .main {
        min-height: 620px;
      }
    }
  </style>
</head>
<body>
  <div class="app">
    <aside class="sidebar">
      <h1>Keyword Graph</h1>
      <label for="query">Query</label>
      <input id="query" value="" autocomplete="off" autofocus>
      <div class="grid">
        <div>
          <label for="depth">Depth</label>
          <input id="depth" type="number" min="0" max="5" value="2">
        </div>
        <div>
          <label for="topN">Top N</label>
          <input id="topN" type="number" min="1" max="200" value="20">
        </div>
        <div>
          <label for="minScore">Min Score</label>
          <input id="minScore" type="number" min="0" step="0.1" value="0">
        </div>
        <div>
          <label for="maxNodes">Max Nodes</label>
          <input id="maxNodes" type="number" min="1" max="2000" value="250">
        </div>
        <div>
          <label for="minCooccur">Min Cooccur</label>
          <input id="minCooccur" type="number" min="1" value="20">
        </div>
        <div>
          <label for="autoMinCooccur">Auto Cooccur</label>
          <input id="autoMinCooccur" type="checkbox" checked>
        </div>
        <div>
          <label for="minKeywordDF">Min Keyword DF</label>
          <input id="minKeywordDF" type="number" min="1" value="5">
        </div>
      </div>
      <label for="expand">Expand</label>
      <select id="expand">
        <option value="none">none</option>
        <option value="contains">contains</option>
      </select>
      <div class="button-row">
        <button id="load">Load</button>
        <button id="fit" class="secondary">Fit</button>
      </div>
      <h2>Selected</h2>
      <div id="selected">-</div>
    </aside>
    <main class="main">
      <div class="topbar">
        <div class="status" id="status">Ready</div>
        <div class="legend">
          <span><i class="swatch" style="background:#1f6feb"></i>depth 0</span>
          <span><i class="swatch" style="background:#13795b"></i>depth 1</span>
          <span><i class="swatch" style="background:#b7791f"></i>depth 2+</span>
        </div>
      </div>
      <div class="canvas-wrap">
        <canvas id="graph-canvas"></canvas>
      </div>
      <section class="details" id="details"></section>
    </main>
  </div>
  <script>
    const canvas = document.getElementById('graph-canvas');
    const ctx = canvas.getContext('2d');
    const state = {
      graph: { nodes: [], edges: [] },
      positions: new Map(),
      selected: null,
      scale: 1,
      offsetX: 0,
      offsetY: 0
    };
    const colors = ['#1f6feb', '#13795b', '#b7791f', '#c73e3e', '#6f42c1', '#59636e'];

    function value(id) {
      return document.getElementById(id).value.trim();
    }

    function status(text) {
      document.getElementById('status').textContent = text;
    }

    function resizeCanvas() {
      const rect = canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.floor(rect.width * dpr));
      canvas.height = Math.max(1, Math.floor(rect.height * dpr));
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      draw();
    }

    function nodeRadius(node) {
      return Math.max(7, Math.min(22, 7 + Math.log((node.df || 1) + 1) * 2.4));
    }

    function nodeColor(node) {
      return colors[Math.min(colors.length - 1, node.depth || 0)];
    }

    function layoutGraph(graph) {
      const rect = canvas.getBoundingClientRect();
      const w = Math.max(640, rect.width);
      const h = Math.max(420, rect.height);
      const nodes = graph.nodes || [];
      const edges = graph.edges || [];
      const centerX = w / 2;
      const centerY = h / 2;
      state.positions.clear();
      nodes.forEach((node, i) => {
        const ring = 70 + (node.depth || 0) * 125;
        const angle = (i / Math.max(1, nodes.length)) * Math.PI * 2;
        state.positions.set(node.id, {
          x: centerX + Math.cos(angle) * ring,
          y: centerY + Math.sin(angle) * ring,
          vx: 0,
          vy: 0
        });
      });
      for (let step = 0; step < 220; step++) {
        for (let i = 0; i < nodes.length; i++) {
          const a = nodes[i];
          const pa = state.positions.get(a.id);
          for (let j = i + 1; j < nodes.length; j++) {
            const b = nodes[j];
            const pb = state.positions.get(b.id);
            let dx = pa.x - pb.x;
            let dy = pa.y - pb.y;
            let distSq = dx * dx + dy * dy + 0.01;
            let force = Math.min(1.7, 2400 / distSq);
            pa.vx += dx * force;
            pa.vy += dy * force;
            pb.vx -= dx * force;
            pb.vy -= dy * force;
          }
        }
        edges.forEach(edge => {
          const pa = state.positions.get(edge.from);
          const pb = state.positions.get(edge.to);
          if (!pa || !pb) return;
          const dx = pb.x - pa.x;
          const dy = pb.y - pa.y;
          const dist = Math.sqrt(dx * dx + dy * dy) || 1;
          const target = 105 + Math.min(130, 12 * Math.log((edge.cooccur || 1) + 1));
          const force = (dist - target) * 0.018;
          const fx = dx / dist * force;
          const fy = dy / dist * force;
          pa.vx += fx;
          pa.vy += fy;
          pb.vx -= fx;
          pb.vy -= fy;
        });
        nodes.forEach(node => {
          const p = state.positions.get(node.id);
          p.vx += (centerX - p.x) * 0.004;
          p.vy += (centerY - p.y) * 0.004;
          p.x += p.vx;
          p.y += p.vy;
          p.vx *= 0.82;
          p.vy *= 0.82;
        });
      }
      fitGraph(false);
    }

    function fitGraph(redraw = true) {
      const nodes = state.graph.nodes || [];
      if (!nodes.length) return;
      const rect = canvas.getBoundingClientRect();
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      nodes.forEach(node => {
        const p = state.positions.get(node.id);
        if (!p) return;
        minX = Math.min(minX, p.x);
        minY = Math.min(minY, p.y);
        maxX = Math.max(maxX, p.x);
        maxY = Math.max(maxY, p.y);
      });
      const graphW = Math.max(1, maxX - minX + 120);
      const graphH = Math.max(1, maxY - minY + 120);
      state.scale = Math.min(1.6, Math.max(0.25, Math.min(rect.width / graphW, rect.height / graphH)));
      state.offsetX = rect.width / 2 - ((minX + maxX) / 2) * state.scale;
      state.offsetY = rect.height / 2 - ((minY + maxY) / 2) * state.scale;
      if (redraw) draw();
    }

    function screenPoint(p) {
      return {
        x: p.x * state.scale + state.offsetX,
        y: p.y * state.scale + state.offsetY
      };
    }

    function draw() {
      const rect = canvas.getBoundingClientRect();
      ctx.clearRect(0, 0, rect.width, rect.height);
      ctx.fillStyle = '#fbfcfe';
      ctx.fillRect(0, 0, rect.width, rect.height);
      const edges = state.graph.edges || [];
      const nodes = state.graph.nodes || [];
      ctx.lineCap = 'round';
      edges.forEach(edge => {
        const pa = state.positions.get(edge.from);
        const pb = state.positions.get(edge.to);
        if (!pa || !pb) return;
        const a = screenPoint(pa);
        const b = screenPoint(pb);
        ctx.strokeStyle = 'rgba(82, 95, 111, 0.32)';
        ctx.lineWidth = Math.max(1, Math.min(6, 1 + Math.log((edge.cooccur || 1) + 1)));
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.stroke();
      });
      nodes.forEach(node => {
        const p = state.positions.get(node.id);
        if (!p) return;
        const sp = screenPoint(p);
        const r = nodeRadius(node) * state.scale;
        ctx.beginPath();
        ctx.fillStyle = nodeColor(node);
        ctx.strokeStyle = state.selected === node.id ? '#111827' : '#ffffff';
        ctx.lineWidth = state.selected === node.id ? 3 : 2;
        ctx.arc(sp.x, sp.y, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        ctx.font = '12px Segoe UI, Arial';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'top';
        ctx.fillStyle = '#17202a';
        const label = node.label.length > 18 ? node.label.slice(0, 17) + '...' : node.label;
        ctx.fillText(label, sp.x, sp.y + r + 4);
      });
    }

    function pickNode(event) {
      const rect = canvas.getBoundingClientRect();
      const x = event.clientX - rect.left;
      const y = event.clientY - rect.top;
      let best = null;
      let bestDist = Infinity;
      for (const node of state.graph.nodes || []) {
        const p = state.positions.get(node.id);
        if (!p) continue;
        const sp = screenPoint(p);
        const dx = sp.x - x;
        const dy = sp.y - y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        const limit = nodeRadius(node) * state.scale + 8;
        if (dist <= limit && dist < bestDist) {
          best = node;
          bestDist = dist;
        }
      }
      return best;
    }

    function showSelected(node) {
      state.selected = node ? node.id : null;
      document.getElementById('selected').textContent = node ? node.label + ' / depth ' + node.depth + ' / df ' + node.df : '-';
      const related = node ? (state.graph.edges || []).filter(edge => edge.from === node.id || edge.to === node.id) : [];
      const rows = related.slice(0, 40).map(edge => {
        const other = edge.from === node.id ? edge.to : edge.from;
        return '<tr><td>' + escapeHTML(other) + '</td><td>' + edge.score.toFixed(3) + '</td><td>' + edge.cooccur + '</td></tr>';
      }).join('');
      document.getElementById('details').innerHTML = node
        ? '<strong>' + escapeHTML(node.label) + '</strong><table><thead><tr><th>keyword</th><th>score</th><th>cooccur</th></tr></thead><tbody>' + rows + '</tbody></table>'
        : '';
      draw();
    }

    function escapeHTML(text) {
      return String(text).replace(/[&<>"']/g, ch => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#039;'}[ch]));
    }

    async function loadGraph() {
      const query = value('query');
      if (!query) {
        status('Query required');
        return;
      }
      const params = new URLSearchParams({
        query,
        depth: value('depth'),
        topN: value('topN'),
        minScore: value('minScore'),
        minCooccur: value('minCooccur'),
        autoMinCooccur: document.getElementById('autoMinCooccur').checked ? '1' : '0',
        minKeywordDF: value('minKeywordDF'),
        maxNodes: value('maxNodes'),
        expand: value('expand')
      });
      status('Loading...');
      const response = await fetch('/api/graph?' + params.toString());
      const payload = await response.json();
      if (!response.ok) {
        status(payload.error || 'HTTP ' + response.status);
        return;
      }
      state.graph = payload;
      state.selected = null;
      layoutGraph(payload);
      showSelected(null);
      status(payload.nodes.length + ' nodes / ' + payload.edges.length + ' edges');
    }

    document.getElementById('load').addEventListener('click', loadGraph);
    document.getElementById('fit').addEventListener('click', () => fitGraph(true));
    document.getElementById('query').addEventListener('keydown', event => {
      if (event.key === 'Enter') loadGraph();
    });
    canvas.addEventListener('click', event => {
      const node = pickNode(event);
      showSelected(node);
    });
    canvas.addEventListener('dblclick', event => {
      const node = pickNode(event);
      if (node) {
        document.getElementById('query').value = node.id;
        loadGraph();
      }
    });
    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();
  </script>
</body>
</html>`))
