import Graph from 'graphology';
import louvain from 'graphology-communities-louvain';
import forceAtlas2 from 'graphology-layout-forceatlas2';
import { Maximize2, Plus, RefreshCw, Search, Settings, X } from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate, useSearchParams } from 'react-router';
import Sigma from 'sigma';
import type { Settings as SigmaSettings } from 'sigma/settings';
import type { EdgeDisplayData, NodeDisplayData, PartialButFor, RenderParams } from 'sigma/types';
import { parsePipeTags, type Article } from '@violet-web/shared';

import { fetchKeywordGraph, fetchKeywordLinks, fetchRelatedWorks } from '../api/keyword-graph';
import { ArticleInfoDialog } from '../components/search/ArticleInfoDialog';
import { useAllArticles } from '../hooks/useAllArticles';
import { WorkThumbnail } from '../components/common/WorkThumbnail';
import { useAppStore } from '../stores/app-store';
import type {
  ExpandMode,
  GraphRequest,
  KeywordEdge,
  KeywordGraph,
  KeywordLinksResponse,
  KeywordNode,
  RelatedWork,
  RelatedWorksResponse,
} from '../types/keyword-graph';
import {
  buildSigmaGraphData,
  formatScore,
  summarizeGraph,
  type GraphPalette,
  type SigmaEdgeData,
  type SigmaNodeData,
} from '../utils/keyword-graph-model';
import {
  applyComplexityPreset,
  complexityPresets,
  type ComplexityPreset,
} from '../utils/keyword-graph-presets';
import styles from './KeywordGraphPage.module.css';

const defaultRequest: GraphRequest = {
  query: '',
  expand: 'contains',
  depth: 2,
  topN: 8,
  minScore: 0,
  minCooccur: 0,
  autoMinCooccur: true,
  minKeywordDF: 30,
  maxNodes: 90,
};

type SigmaNodeAttrs = SigmaNodeData & {
  x: number;
  y: number;
  hidden: boolean;
  zIndex: number;
  forceLabel: boolean;
};

type SigmaEdgeAttrs = SigmaEdgeData & {
  size: number;
  color: string;
  hidden: boolean;
};

interface ThemeColors {
  bg: string;
  panel: string;
  border: string;
  text: string;
  muted: string;
  primary: string;
  primaryHover: string;
  edge: string;
  edgeMuted: string;
  selected: string;
  labelStroke: string;
  palette: GraphPalette;
}

type DetailTab = 'links' | 'works';

interface KeywordGraphURLState {
  form: GraphRequest;
  complexity: ComplexityPreset;
  selectedID: string | null;
  detailTab: DetailTab;
  workKeywords: string[];
  includeSeedKeyword: boolean;
}

export function KeywordGraphPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const {
    keywordGraphServerUrl,
    themeColor,
    themeMode,
  } = useAppStore();
  const initialURLState = useMemo(() => parseKeywordGraphURLState(searchParams), []);
  const [form, setForm] = useState<GraphRequest>(initialURLState.form);
  const [complexity, setComplexity] = useState<ComplexityPreset>(initialURLState.complexity);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [graph, setGraph] = useState<KeywordGraph | null>(null);
  const [selectedID, setSelectedID] = useState<string | null>(initialURLState.selectedID);
  const [workKeywords, setWorkKeywords] = useState<string[]>(initialURLState.workKeywords);
  const [includeSeedKeyword, setIncludeSeedKeyword] = useState(initialURLState.includeSeedKeyword);
  const [comboLinks, setComboLinks] = useState<KeywordLinksResponse | null>(null);
  const [relatedWorks, setRelatedWorks] = useState<RelatedWorksResponse | null>(null);
  const [relatedWorksLoading, setRelatedWorksLoading] = useState(false);
  const [detailTab, setDetailTab] = useState<DetailTab>(initialURLState.detailTab);
  const [status, setStatus] = useState('Keyword graph server ready');
  const [loading, setLoading] = useState(false);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const sigmaRef = useRef<Sigma<SigmaNodeAttrs, SigmaEdgeAttrs> | null>(null);
  const graphologyRef = useRef<Graph<SigmaNodeAttrs, SigmaEdgeAttrs> | null>(null);
  const colorsRef = useRef<ThemeColors | null>(null);

  const selectedNode = useMemo(() => {
    if (!graph || !selectedID) {
      return null;
    }
    return graph.nodes.find((node) => node.id === selectedID) ?? null;
  }, [graph, selectedID]);

  const selectedEdges = useMemo(() => {
    if (!graph || !selectedID) {
      return [];
    }
    return graph.edges
      .filter((edge) => edge.from === selectedID || edge.to === selectedID)
      .sort((left, right) => right.score - left.score);
  }, [graph, selectedID]);
  const seedKeywords = useMemo(() => (graph ? graphSeedKeywords(graph) : []), [graph]);

  async function loadGraph(
    nextForm = form,
    options: { selectedID?: string | null; resetWorkKeywords?: boolean } = {},
  ) {
    const query = nextForm.query.trim();
    if (!query) {
      setStatus('query required');
      setGraph(null);
      setSelectedID(null);
      return;
    }
    setLoading(true);
    setStatus('loading graph');
    try {
      const nextGraph = await fetchKeywordGraph(keywordGraphServerUrl, { ...nextForm, query });
      setGraph(nextGraph);
      const nextSelectedID =
        options.selectedID && nextGraph.nodes.some((node) => node.id === options.selectedID)
          ? options.selectedID
          : graphSeedKeywords(nextGraph).length > 1
            ? null
            : nextGraph.nodes[0]?.id ?? null;
      setSelectedID(nextSelectedID);
      if (options.resetWorkKeywords ?? true) {
        setWorkKeywords([]);
        setIncludeSeedKeyword(true);
      }
      setStatus(summarizeGraph(nextGraph));
    } catch (error) {
      setStatus(error instanceof Error ? error.message : 'failed to load graph');
    } finally {
      setLoading(false);
    }
  }

  function setField<K extends keyof GraphRequest>(key: K, value: GraphRequest[K]) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  function setNumberField(
    key: keyof Pick<GraphRequest, 'depth' | 'topN' | 'minScore' | 'minCooccur' | 'minKeywordDF' | 'maxNodes'>,
    value: number,
  ) {
    setForm((current) => ({ ...current, [key]: Number.isFinite(value) ? value : current[key] }));
  }

  function chooseComplexity(value: ComplexityPreset) {
    setComplexity(value);
    setForm((current) => applyComplexityPreset(current, value));
  }

  function focusKeyword(keyword: string) {
    const next = { ...form, query: keyword, expand: 'none' as ExpandMode };
    setForm(next);
    void loadGraph(next);
  }

  function addWorkKeyword(keyword: string) {
    setWorkKeywords((current) => (current.includes(keyword) ? current : [...current, keyword]));
    setDetailTab('works');
  }

  function removeWorkKeyword(keyword: string) {
    setWorkKeywords((current) => current.filter((item) => item !== keyword));
  }

  function fitGraph() {
    sigmaRef.current?.getCamera().animatedReset({ duration: 220 });
  }

  useEffect(() => {
    if (!containerRef.current) {
      return;
    }
    const colors = readThemeColors();
    colorsRef.current = colors;
    const sigmaGraph = new Graph<SigmaNodeAttrs, SigmaEdgeAttrs>({ type: 'undirected' });
    const sigma = new Sigma<SigmaNodeAttrs, SigmaEdgeAttrs>(
      sigmaGraph,
      containerRef.current,
      sigmaSettings(colors),
    );
    graphologyRef.current = sigmaGraph;
    sigmaRef.current = sigma;

    sigma.on('clickNode', ({ node }) => {
      setSelectedID(node);
      sigma.refresh();
    });
    sigma.on('clickStage', () => {
      setSelectedID(null);
      sigma.refresh();
    });

    return () => {
      sigma.kill();
      sigmaRef.current = null;
      graphologyRef.current = null;
    };
  }, []);

  useEffect(() => {
    const sigma = sigmaRef.current;
    if (!sigma) {
      return;
    }
    const colors = readThemeColors();
    colorsRef.current = colors;
    sigma.setSetting('labelColor', { color: colors.text });
    sigma.setSetting('defaultEdgeColor', colors.edge);
    sigma.setSetting('defaultDrawNodeLabel', (context, data, settings) => drawNodeLabel(context, data, settings, colors));
    sigma.setSetting('defaultDrawNodeHover', (context, data, settings) => drawNodeHover(context, data, settings, colors));
    sigma.setSetting('nodeReducer', (node, data) => reduceNode(node, data, colors));
    sigma.setSetting('edgeReducer', (edge, data) => reduceEdge(edge, data, colors));
    sigma.refresh();
  }, [themeColor, themeMode]);

  useEffect(() => {
    const sigma = sigmaRef.current;
    if (!sigma || !graph) {
      return;
    }
    const colors = colorsRef.current ?? readThemeColors();
    const nextGraph = buildGraphologyGraph(graph, colors);
    activeSigmaGraph = nextGraph;
    sigma.setGraph(nextGraph);
    graphologyRef.current = nextGraph;
    applyCompactViewport(sigma, nextGraph);
    sigma.getCamera().animatedReset({ duration: 260 });
    sigma.refresh();
  }, [graph, themeColor, themeMode]);

  useEffect(() => {
    activeSelectedID = selectedID;
    sigmaRef.current?.refresh();
  }, [selectedID]);

  useEffect(() => {
    if (!initialURLState.form.query.trim()) {
      return;
    }
    void loadGraph(initialURLState.form, {
      selectedID: initialURLState.selectedID,
      resetWorkKeywords: false,
    });
    // Only hydrate once from the URL when this page is mounted.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const nextSearch = buildKeywordGraphSearchParams({
      form,
      complexity,
      selectedID,
      detailTab,
      workKeywords,
      includeSeedKeyword,
    }).toString();
    const nextURL = `/keyword-graph${nextSearch ? `?${nextSearch}` : ''}`;
    const currentURL = `${window.location.pathname}${window.location.search}`;
    if (currentURL !== nextURL) {
      navigate(nextURL, { replace: true });
    }
  }, [complexity, detailTab, form, includeSeedKeyword, navigate, selectedID, workKeywords]);

  useEffect(() => {
    if (!graph) {
      setRelatedWorks(null);
      return;
    }
    const controller = new AbortController();
    const seedKeywords = graphSeedKeywords(graph);
    const effectiveWorkKeywords = uniqueKeywords([
      ...(includeSeedKeyword ? seedKeywords : []),
      ...workKeywords,
    ]);
    setRelatedWorksLoading(true);
    void fetchRelatedWorks(
      keywordGraphServerUrl,
      effectiveWorkKeywords.length > 0
        ? { mode: 'selected', keywords: effectiveWorkKeywords, match: 'soft', limit: 100 }
        : { mode: 'graph', query: graph.query, graph: graphRequestFromGraph(graph), match: 'soft', limit: 100 },
      controller.signal,
    )
      .then((response) => setRelatedWorks(response))
      .catch((error) => {
        if (!(error instanceof DOMException && error.name === 'AbortError')) {
          setRelatedWorks(null);
        }
      })
      .finally(() => {
        if (!controller.signal.aborted) {
          setRelatedWorksLoading(false);
        }
      });
    return () => controller.abort();
  }, [graph, includeSeedKeyword, keywordGraphServerUrl, workKeywords]);

  useEffect(() => {
    if (!graph || seedKeywords.length < 2) {
      setComboLinks(null);
      return;
    }
    const controller = new AbortController();
    void fetchKeywordLinks(
      keywordGraphServerUrl,
      {
        keywords: seedKeywords,
        minKeywordDF: graph.params.min_keyword_df,
        minCooccur: 1,
        limit: 80,
      },
      controller.signal,
    )
      .then((response) => setComboLinks(response))
      .catch((error) => {
        if (!(error instanceof DOMException && error.name === 'AbortError')) {
          setComboLinks(null);
        }
      });
    return () => controller.abort();
  }, [graph, keywordGraphServerUrl, seedKeywords]);

  return (
    <div className={`${styles.page} keywordGraphFill`}>
      <div className={styles.graphCanvas} ref={containerRef} />

      <form
        className={styles.searchPanel}
        onSubmit={(event) => {
          event.preventDefault();
          void loadGraph();
        }}
      >
        <div className={styles.searchRow}>
          <div className={styles.queryBox}>
            <Search size={16} />
            <input
              value={form.query}
              onChange={(event) => setField('query', event.target.value)}
              placeholder="keyword"
              autoComplete="off"
            />
          </div>
          <div className={styles.segmented} aria-label="Complexity">
            {complexityPresets.map((preset) => (
              <button
                key={preset.value}
                type="button"
                className={complexity === preset.value ? styles.segmentActive : ''}
                onClick={() => chooseComplexity(preset.value)}
              >
                {preset.label}
              </button>
            ))}
          </div>
          <button className={styles.primaryButton} type="submit" disabled={loading}>
            <Search size={15} />
            Search
          </button>
          <button className={styles.iconButton} type="button" onClick={fitGraph} aria-label="Fit graph">
            <Maximize2 size={17} />
          </button>
          <button className={styles.iconButton} type="button" onClick={() => loadGraph()} aria-label="Reload graph">
            <RefreshCw size={17} />
          </button>
          <button
            className={`${styles.iconButton} ${settingsOpen ? styles.iconButtonActive : ''}`}
            type="button"
            onClick={() => setSettingsOpen((value) => !value)}
            aria-label="Graph settings"
          >
            <Settings size={17} />
          </button>
        </div>
        {settingsOpen && (
          <div className={styles.settingsPanel}>
            <label>
              <span>Depth</span>
              <input type="number" min={0} max={5} value={form.depth} onChange={(event) => setNumberField('depth', Number(event.target.value))} />
            </label>
            <label>
              <span>Top N</span>
              <input type="number" min={1} max={200} value={form.topN} onChange={(event) => setNumberField('topN', Number(event.target.value))} />
            </label>
            <label>
              <span>Min Score</span>
              <input type="number" min={0} step={0.1} value={form.minScore} onChange={(event) => setNumberField('minScore', Number(event.target.value))} />
            </label>
            <label>
              <span>Max Nodes</span>
              <input type="number" min={1} max={2000} value={form.maxNodes} onChange={(event) => setNumberField('maxNodes', Number(event.target.value))} />
            </label>
            <label className={styles.cooccurLabel}>
              <span>Min Cooccur</span>
              <div className={styles.cooccurControl}>
                <label className={styles.autoToggle}>
                  <input
                    type="checkbox"
                    checked={form.autoMinCooccur}
                    onChange={(event) => {
                      const enabled = event.target.checked;
                      setForm((current) => ({
                        ...current,
                        autoMinCooccur: enabled,
                        minCooccur: enabled ? 0 : Math.max(current.minCooccur, 20),
                      }));
                    }}
                  />
                  <span>Auto</span>
                </label>
                <input
                  type="number"
                  min={form.autoMinCooccur ? 0 : 1}
                  value={form.autoMinCooccur ? 0 : form.minCooccur}
                  disabled={form.autoMinCooccur}
                  onChange={(event) => setNumberField('minCooccur', Number(event.target.value))}
                />
              </div>
            </label>
            <label>
              <span>Min DF</span>
              <input type="number" min={1} value={form.minKeywordDF} onChange={(event) => setNumberField('minKeywordDF', Number(event.target.value))} />
            </label>
            <label>
              <span>Expand</span>
              <select value={form.expand} onChange={(event) => setField('expand', event.target.value as ExpandMode)}>
                <option value="none">none</option>
                <option value="contains">contains</option>
              </select>
            </label>
          </div>
        )}
        <div className={styles.statusLine}>
          <span>{status}</span>
          <span>{keywordGraphServerUrl}</span>
        </div>
      </form>

      <NodeDetails
        node={selectedNode}
        edges={selectedEdges}
        graph={graph}
        comboLinks={comboLinks}
        relatedWorks={relatedWorks}
        relatedWorksLoading={relatedWorksLoading}
        workKeywords={workKeywords}
        seedKeywords={seedKeywords}
        includeSeedKeyword={includeSeedKeyword}
        tab={detailTab}
        onTabChange={setDetailTab}
        onSelectKeyword={setSelectedID}
        onFocus={focusKeyword}
        onAddWorkKeyword={addWorkKeyword}
        onRemoveWorkKeyword={removeWorkKeyword}
        onClearWorkKeywords={() => {
          setWorkKeywords([]);
          setIncludeSeedKeyword(false);
        }}
      />
    </div>
  );
}

function buildGraphologyGraph(graph: KeywordGraph, colors: ThemeColors): Graph<SigmaNodeAttrs, SigmaEdgeAttrs> {
  const data = buildSigmaGraphData(graph, colors.palette);
  const sigmaGraph = new Graph<SigmaNodeAttrs, SigmaEdgeAttrs>({ type: 'undirected' });
  const communityOrder = Array.from(new Set(data.nodes.filter((node) => node.depth <= 1).map((node) => node.id)));
  const communityIndex = new Map(communityOrder.map((id, index) => [id, index]));

  for (const node of data.nodes) {
    const position = initialPosition(node, data.nodes.length, communityIndex.get(node.community) ?? 0, communityOrder.length);
    sigmaGraph.addNode(node.id, {
      ...node,
      x: position.x,
      y: position.y,
      hidden: false,
      zIndex: node.depth === 0 ? 4 : node.depth === 1 ? 3 : 1,
      forceLabel: node.depth <= 1,
    });
  }

  for (const edge of data.edges) {
    if (!sigmaGraph.hasNode(edge.source) || !sigmaGraph.hasNode(edge.target)) {
      continue;
    }
    sigmaGraph.addEdgeWithKey(edge.id, edge.source, edge.target, {
      ...edge,
      size: edge.weight,
      color: colors.edge,
      hidden: false,
    });
  }

  try {
    louvain.assign(sigmaGraph, {
      nodeCommunityAttribute: 'community',
      getEdgeWeight: 'weight',
    });
  } catch {
    // Depth-based communities are already assigned; Louvain only improves clustering when it can.
  }

  forceAtlas2.assign(sigmaGraph, {
    iterations: Math.max(140, Math.min(360, data.nodes.length * 5)),
    settings: {
      ...forceAtlas2.inferSettings(sigmaGraph),
      gravity: 0.34,
      scalingRatio: 4.2,
      slowDown: 2.4,
      strongGravityMode: false,
      barnesHutOptimize: data.nodes.length > 140,
      edgeWeightInfluence: 0.62,
    },
  });

  return sigmaGraph;
}

function parseKeywordGraphURLState(params: URLSearchParams): KeywordGraphURLState {
  return {
    form: {
      query: params.get('q') ?? defaultRequest.query,
      expand: parseExpandMode(params.get('expand')),
      depth: parseNumberParam(params, 'depth', defaultRequest.depth),
      topN: parseNumberParam(params, 'topN', defaultRequest.topN, 1),
      minScore: parseNumberParam(params, 'minScore', defaultRequest.minScore),
      minCooccur: parseNumberParam(params, 'minCooccur', defaultRequest.minCooccur, 0),
      autoMinCooccur: parseBoolParam(params, 'autoMinCooccur', defaultRequest.autoMinCooccur),
      minKeywordDF: parseNumberParam(params, 'minKeywordDF', defaultRequest.minKeywordDF, 1),
      maxNodes: parseNumberParam(params, 'maxNodes', defaultRequest.maxNodes, 1),
    },
    complexity: parseComplexityPreset(params.get('complexity')),
    selectedID: normalizeURLText(params.get('selected')),
    detailTab: params.get('tab') === 'works' ? 'works' : 'links',
    workKeywords: parseKeywordList(params.get('wk')),
    includeSeedKeyword: params.get('seed') !== '0',
  };
}

function buildKeywordGraphSearchParams(state: KeywordGraphURLState): URLSearchParams {
  const params = new URLSearchParams();
  const query = state.form.query.trim();
  if (query) {
    params.set('q', query);
  }
  if (state.complexity !== 'compact') {
    params.set('complexity', state.complexity);
  }
  setParamIfChanged(params, 'expand', state.form.expand, defaultRequest.expand);
  setNumberParamIfChanged(params, 'depth', state.form.depth, defaultRequest.depth);
  setNumberParamIfChanged(params, 'topN', state.form.topN, defaultRequest.topN);
  setNumberParamIfChanged(params, 'minScore', state.form.minScore, defaultRequest.minScore);
  setNumberParamIfChanged(params, 'minCooccur', state.form.minCooccur, defaultRequest.minCooccur);
  setBoolParamIfChanged(params, 'autoMinCooccur', state.form.autoMinCooccur, defaultRequest.autoMinCooccur);
  setNumberParamIfChanged(params, 'minKeywordDF', state.form.minKeywordDF, defaultRequest.minKeywordDF);
  setNumberParamIfChanged(params, 'maxNodes', state.form.maxNodes, defaultRequest.maxNodes);
  if (state.selectedID) {
    params.set('selected', state.selectedID);
  }
  if (state.detailTab !== 'links') {
    params.set('tab', state.detailTab);
  }
  if (!state.includeSeedKeyword) {
    params.set('seed', '0');
  }
  if (state.workKeywords.length > 0) {
    params.set('wk', state.workKeywords.join(','));
  }
  return params;
}

function parseNumberParam(params: URLSearchParams, key: string, fallback: number, min = 0): number {
  const rawValue = params.get(key);
  if (rawValue == null || rawValue.trim() === '') {
    return fallback;
  }
  const value = Number(rawValue);
  return Number.isFinite(value) && value >= min ? value : fallback;
}

function setParamIfChanged(params: URLSearchParams, key: string, value: string, fallback: string) {
  if (value !== fallback) {
    params.set(key, value);
  }
}

function setNumberParamIfChanged(params: URLSearchParams, key: string, value: number, fallback: number) {
  if (value !== fallback) {
    params.set(key, String(value));
  }
}

function setBoolParamIfChanged(params: URLSearchParams, key: string, value: boolean, fallback: boolean) {
  if (value !== fallback) {
    params.set(key, value ? '1' : '0');
  }
}

function parseBoolParam(params: URLSearchParams, key: string, fallback: boolean): boolean {
  const value = params.get(key)?.trim().toLowerCase();
  if (!value) {
    return fallback;
  }
  if (value === '1' || value === 'true' || value === 'yes' || value === 'on') {
    return true;
  }
  if (value === '0' || value === 'false' || value === 'no' || value === 'off') {
    return false;
  }
  return fallback;
}

function parseExpandMode(value: string | null): ExpandMode {
  return value === 'none' || value === 'contains' ? value : defaultRequest.expand;
}

function parseComplexityPreset(value: string | null): ComplexityPreset {
  return value === 'balanced' || value === 'full' ? value : 'compact';
}

function normalizeURLText(value: string | null): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

function parseKeywordList(value: string | null): string[] {
  if (!value) {
    return [];
  }
  return uniqueKeywords(value.split(','));
}

function uniqueKeywords(keywords: string[]): string[] {
  return Array.from(new Set(keywords.map((keyword) => keyword.trim()).filter(Boolean)));
}

function graphSeedKeywords(graph: KeywordGraph): string[] {
  const queries = uniqueKeywords(graph.queries ?? []);
  if (queries.length > 0) {
    return queries;
  }
  const query = graph.query.trim();
  return query ? [query] : [];
}

function graphRequestFromGraph(graph: KeywordGraph): GraphRequest {
  return {
    query: graph.query,
    expand: graph.params.expand,
    depth: graph.params.depth,
    topN: graph.params.top_n,
    minScore: graph.params.min_score,
    minCooccur: graph.params.min_cooccur,
    autoMinCooccur: graph.params.auto_min_cooccur ?? defaultRequest.autoMinCooccur,
    minKeywordDF: graph.params.min_keyword_df,
    maxNodes: graph.params.max_nodes,
  };
}

function applyCompactViewport(
  sigma: Sigma<SigmaNodeAttrs, SigmaEdgeAttrs>,
  sigmaGraph: Graph<SigmaNodeAttrs, SigmaEdgeAttrs>,
) {
  const xs: number[] = [];
  const ys: number[] = [];
  sigmaGraph.forEachNode((_, attrs) => {
    xs.push(attrs.x);
    ys.push(attrs.y);
  });
  if (xs.length === 0 || ys.length === 0) {
    sigma.setCustomBBox(null);
    return;
  }
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const centerX = (minX + maxX) / 2;
  const centerY = (minY + maxY) / 2;
  const halfWidth = Math.max(10, (maxX - minX) / 2) * 1.04;
  const halfHeight = Math.max(10, (maxY - minY) / 2) * 1.04;
  sigma.setCustomBBox({
    x: [centerX - halfWidth, centerX + halfWidth],
    y: [centerY - halfHeight, centerY + halfHeight],
  });
}

function initialPosition(
  node: SigmaNodeData,
  total: number,
  communityIndex: number,
  communityCount: number,
): { x: number; y: number } {
  if (node.depth === 0) {
    return { x: 0, y: 0 };
  }
  const baseAngle = (Math.PI * 2 * communityIndex) / Math.max(communityCount, 1);
  const jitter = hashToUnit(node.id) * 0.9 - 0.45;
  const angle = baseAngle + jitter;
  const radius = node.depth === 1 ? 10 : 20 + Math.min(18, total * 0.06) + hashToUnit(`${node.id}:r`) * 8;
  return {
    x: Math.cos(angle) * radius,
    y: Math.sin(angle) * radius,
  };
}

function sigmaSettings(colors: ThemeColors): Partial<SigmaSettings<SigmaNodeAttrs, SigmaEdgeAttrs>> {
  return {
    renderLabels: true,
    hideLabelsOnMove: false,
    hideEdgesOnMove: false,
    labelFont: 'Segoe UI, Arial, sans-serif',
    labelSize: 12,
    labelWeight: '700',
    labelColor: { color: colors.text },
    labelDensity: 1,
    labelGridCellSize: 36,
    labelRenderedSizeThreshold: 0,
    minEdgeThickness: 0.6,
    zIndex: true,
    stagePadding: 0,
    defaultEdgeColor: colors.edge,
    defaultDrawNodeLabel: (context, data, settings) => drawNodeLabel(context, data, settings, colors),
    defaultDrawNodeHover: (context, data, settings) => drawNodeHover(context, data, settings, colors),
    nodeHoverProgramClasses: {
      circle: NoopNodeHoverProgram,
    },
    nodeReducer: (node, data) => reduceNode(node, data, colors),
    edgeReducer: (edge, data) => reduceEdge(edge, data, colors),
  };
}

function reduceNode(node: string, data: SigmaNodeAttrs, colors: ThemeColors): Partial<NodeDisplayData> {
  const selectedID = selectedIDForReducer();
  if (!selectedID) {
    return {
      x: data.x,
      y: data.y,
      label: data.label,
      color: data.color,
      size: data.size,
      forceLabel: data.depth <= 1 || data.labelPriority >= 350,
      zIndex: data.zIndex,
    };
  }

  const sigmaGraph = reducerGraph();
  const isSelected = node === selectedID;
  const isNeighbor = Boolean(sigmaGraph?.hasEdge(node, selectedID) || sigmaGraph?.hasEdge(selectedID, node));
  const isSeed = data.depth === 0;
  if (!isSelected && !isNeighbor && !isSeed) {
    return {
      x: data.x,
      y: data.y,
      label: data.label,
      color: colors.muted,
      size: data.size * 0.74,
      forceLabel: false,
      zIndex: 0,
    };
  }
  return {
    x: data.x,
    y: data.y,
    label: data.label,
    color: isSelected ? colors.selected : data.color,
    size: data.size * (isSelected ? 1.35 : isNeighbor ? 1.08 : 1.02),
    forceLabel: true,
    zIndex: isSelected ? 10 : isNeighbor ? 6 : Math.max(data.zIndex, 5),
  };
}

function reduceEdge(edge: string, data: SigmaEdgeAttrs, colors: ThemeColors): Partial<EdgeDisplayData> {
  const selectedID = selectedIDForReducer();
  if (!selectedID) {
    return {
      color: data.color,
      size: data.size,
    };
  }
  const sigmaGraph = reducerGraph();
  if (!sigmaGraph) {
    return data;
  }
  const source = sigmaGraph.source(edge);
  const target = sigmaGraph.target(edge);
  const connected = source === selectedID || target === selectedID;
  return {
    color: connected ? colors.selected : colors.edgeMuted,
    size: connected ? data.size * 1.5 : Math.max(0.3, data.size * 0.55),
    hidden: false,
  };
}

let activeSigmaGraph: Graph<SigmaNodeAttrs, SigmaEdgeAttrs> | null = null;
let activeSelectedID: string | null = null;

function selectedIDForReducer(): string | null {
  return activeSelectedID;
}

function reducerGraph(): Graph<SigmaNodeAttrs, SigmaEdgeAttrs> | null {
  return activeSigmaGraph;
}

function drawNodeLabel(
  context: CanvasRenderingContext2D,
  data: PartialButFor<NodeDisplayData, 'x' | 'y' | 'size' | 'label' | 'color'>,
  settings: SigmaSettings<SigmaNodeAttrs, SigmaEdgeAttrs>,
  colors: ThemeColors,
) {
  if (!data.label) {
    return;
  }
  const fontSize = Math.max(9, Math.min(13, data.size * 0.52));
  const label = fitLabel(context, data.label, Math.max(28, data.size * 1.75), fontSize, settings.labelFont);
  context.save();
  context.font = `700 ${fontSize}px ${settings.labelFont}`;
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.lineWidth = 3;
  context.strokeStyle = colors.labelStroke;
  context.fillStyle = '#ffffff';
  context.strokeText(label, data.x, data.y);
  context.fillText(label, data.x, data.y);
  context.restore();
}

function drawNodeHover(
  context: CanvasRenderingContext2D,
  data: PartialButFor<NodeDisplayData, 'x' | 'y' | 'size' | 'label' | 'color'>,
  settings: SigmaSettings<SigmaNodeAttrs, SigmaEdgeAttrs>,
  colors: ThemeColors,
) {
  context.save();
  context.beginPath();
  context.arc(data.x, data.y, data.size + 3, 0, Math.PI * 2);
  context.lineWidth = 3;
  context.strokeStyle = colors.selected;
  context.stroke();
  context.restore();
  drawNodeLabel(context, data, settings, colors);
}

class NoopNodeHoverProgram {
  drawLabel = undefined;
  drawHover = undefined;

  constructor(
    _gl: WebGLRenderingContext,
    _pickingBuffer: WebGLFramebuffer | null,
    _renderer: Sigma<SigmaNodeAttrs, SigmaEdgeAttrs>,
  ) {}

  kill() {}

  reallocate(_capacity: number) {}

  process(_nodeIndex: number, _offset: number, _data: NodeDisplayData) {}

  render(_params: RenderParams) {}
}

function fitLabel(context: CanvasRenderingContext2D, label: string, maxWidth: number, fontSize: number, fontFamily: string): string {
  context.font = `700 ${fontSize}px ${fontFamily}`;
  if (context.measureText(label).width <= maxWidth) {
    return label;
  }
  const chars = Array.from(label);
  for (let length = chars.length - 1; length > 1; length -= 1) {
    const next = `${chars.slice(0, length).join('')}…`;
    if (context.measureText(next).width <= maxWidth) {
      return next;
    }
  }
  return chars[0] ?? '';
}

function hashToUnit(text: string): number {
  let hash = 2166136261;
  for (const char of text) {
    hash ^= char.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) / 4294967295;
}

function NodeDetails({
  node,
  edges,
  graph,
  comboLinks,
  relatedWorks,
  relatedWorksLoading,
  workKeywords,
  seedKeywords,
  includeSeedKeyword,
  tab,
  onTabChange,
  onSelectKeyword,
  onFocus,
  onAddWorkKeyword,
  onRemoveWorkKeyword,
  onClearWorkKeywords,
}: {
  node: KeywordNode | null;
  edges: KeywordEdge[];
  graph: KeywordGraph | null;
  comboLinks: KeywordLinksResponse | null;
  relatedWorks: RelatedWorksResponse | null;
  relatedWorksLoading: boolean;
  workKeywords: string[];
  seedKeywords: string[];
  includeSeedKeyword: boolean;
  tab: DetailTab;
  onTabChange: (tab: DetailTab) => void;
  onSelectKeyword: (keyword: string) => void;
  onFocus: (keyword: string) => void;
  onAddWorkKeyword: (keyword: string) => void;
  onRemoveWorkKeyword: (keyword: string) => void;
  onClearWorkKeywords: () => void;
}) {
  const workRows = relatedWorks?.works ?? [];
  const articleIds = useMemo(() => workRows.map((work) => work.article_id), [workRows]);
  const { data: relatedArticles = [], isLoading: relatedArticlesLoading } = useAllArticles(
    'keyword-graph-related-works',
    articleIds.length > 0 ? articleIds : undefined,
  );
  const articleMap = useMemo(() => {
    const map = new Map<string, Article>();
    for (const article of relatedArticles) {
      map.set(String(article.Id), article);
    }
    return map;
  }, [relatedArticles]);
  const effectiveWorkTags = uniqueKeywords([
    ...(includeSeedKeyword ? seedKeywords : []),
    ...workKeywords,
  ]);
  const hasWorkContext = effectiveWorkTags.length > 0 || workRows.length > 0;
  const workTags = effectiveWorkTags.length > 0 ? effectiveWorkTags : relatedWorks?.query_terms.slice(0, 5) ?? [];
  const detailTitle = node?.label ?? (seedKeywords.length > 1 ? seedKeywords.join(' + ') : 'Selected');
  const aggregateLinks = useMemo(() => {
    if (node || !graph) {
      return [];
    }
    if (seedKeywords.length > 1 && comboLinks) {
      return comboLinks.links.map((link) => ({
        keyword: link.keyword,
        score: link.score,
        cooccur: link.cooccur,
        links: link.cooccur,
      }));
    }
    return aggregateGraphLinks(graph, seedKeywords).slice(0, 80);
  }, [comboLinks, graph, node, seedKeywords]);

  return (
    <aside className={styles.detailPanel}>
      <div className={styles.detailHeader}>
        <div>
          <div className={styles.detailTitle}>{detailTitle}</div>
          <div className={styles.detailMeta}>
            {node ? `depth ${node.depth} / df ${node.df.toLocaleString()} / ${edges.length.toLocaleString()} links` : 'select a node'}
          </div>
        </div>
        {node && (
          <div className={styles.detailActions}>
            <button type="button" onClick={() => onAddWorkKeyword(node.id)}>
              <Plus size={14} />
              Add
            </button>
            <button type="button" className={styles.primarySmall} onClick={() => onFocus(node.id)}>
              Expand
            </button>
          </div>
        )}
      </div>

      <div className={styles.tabs}>
        <button type="button" className={tab === 'links' ? styles.tabActive : ''} onClick={() => onTabChange('links')}>
          Links
        </button>
        <button type="button" className={tab === 'works' ? styles.tabActive : ''} onClick={() => onTabChange('works')}>
          Works {workRows.length}
        </button>
      </div>

      {!node && tab === 'links' && (
        <div className={styles.linkList}>
          <LinkHeader />
          {aggregateLinks.map((link) => (
            <button
              key={link.keyword}
              type="button"
              className={styles.linkRow}
              onClick={() => onSelectKeyword(link.keyword)}
              onDoubleClick={() => onFocus(link.keyword)}
              title={`${link.links.toLocaleString()} links`}
            >
              <span>{link.keyword}</span>
              <span>{formatScore(link.score)}</span>
              <span>{link.cooccur.toLocaleString()}</span>
            </button>
          ))}
          {aggregateLinks.length === 0 && <div className={styles.emptyState}>no ranked keywords</div>}
        </div>
      )}

      {node && tab === 'links' && (
        <div className={styles.linkList}>
          <LinkHeader />
          {edges.slice(0, 80).map((edge) => {
            const keyword = edge.from === node.id ? edge.to : edge.from;
            return (
              <button
                key={edge.id}
                type="button"
                className={styles.linkRow}
                onClick={() => onSelectKeyword(keyword)}
                onDoubleClick={() => onFocus(keyword)}
              >
                <span>{keyword}</span>
                <span>{formatScore(edge.score)}</span>
                <span>{edge.cooccur.toLocaleString()}</span>
              </button>
            );
          })}
        </div>
      )}

      {tab === 'works' && hasWorkContext && (
        <div className={styles.worksPanel}>
          <div className={styles.keywordChips}>
            {workTags.map((keyword) => (
              <span key={keyword} className={styles.keywordChip}>
                {keyword}
                {workKeywords.includes(keyword) && (
                  <button type="button" onClick={() => onRemoveWorkKeyword(keyword)} aria-label={`Remove ${keyword}`}>
                    <X size={12} />
                  </button>
                )}
              </span>
            ))}
            {(includeSeedKeyword || workKeywords.length > 0) && (
              <button type="button" className={styles.clearButton} onClick={onClearWorkKeywords}>
                Clear
              </button>
            )}
          </div>
          {relatedWorksLoading ? (
            <div className={styles.emptyState}>loading works</div>
          ) : (
            <div className={styles.workList}>
              {workRows.map((work) => (
                <RelatedWorkArticleRow
                  key={work.article_id}
                  work={work}
                  article={articleMap.get(work.article_id)}
                  articleLoading={relatedArticlesLoading}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </aside>
  );
}

function LinkHeader() {
  return (
    <div className={styles.linkHeader} aria-hidden="true">
      <span>Keyword</span>
      <span>Score</span>
      <span>Cooccur</span>
    </div>
  );
}

interface AggregateGraphLink {
  keyword: string;
  score: number;
  cooccur: number;
  links: number;
}

function aggregateGraphLinks(graph: KeywordGraph, seedKeywords: string[]): AggregateGraphLink[] {
  const seedSet = new Set(seedKeywords);
  const nodesByID = new Map(graph.nodes.map((node) => [node.id, node]));
  const rows = new Map<string, AggregateGraphLink>();

  for (const edge of graph.edges) {
    const fromIsSeed = seedSet.has(edge.from);
    const toIsSeed = seedSet.has(edge.to);
    if (fromIsSeed === toIsSeed) {
      continue;
    }
    addAggregateLink(rows, nodesByID, seedSet, fromIsSeed ? edge.to : edge.from, edge.score, edge.cooccur);
  }

  if (rows.size === 0) {
    for (const edge of graph.edges) {
      addAggregateLink(rows, nodesByID, seedSet, edge.to, edge.score, edge.cooccur);
      addAggregateLink(rows, nodesByID, seedSet, edge.from, edge.score, edge.cooccur);
    }
  }

  return Array.from(rows.values()).sort((left, right) => {
    if (left.score !== right.score) return right.score - left.score;
    if (left.cooccur !== right.cooccur) return right.cooccur - left.cooccur;
    if (left.links !== right.links) return right.links - left.links;
    return left.keyword.localeCompare(right.keyword);
  });
}

function addAggregateLink(
  rows: Map<string, AggregateGraphLink>,
  nodesByID: Map<string, KeywordNode>,
  seedSet: Set<string>,
  keyword: string,
  score: number,
  cooccur: number,
) {
  if (seedSet.has(keyword) || !nodesByID.has(keyword)) {
    return;
  }
  const row = rows.get(keyword);
  if (row) {
    row.score += score;
    row.cooccur += cooccur;
    row.links += 1;
    return;
  }
  rows.set(keyword, {
    keyword,
    score,
    cooccur,
    links: 1,
  });
}

function RelatedWorkArticleRow({
  work,
  article,
  articleLoading,
}: {
  work: RelatedWork;
  article?: Article;
  articleLoading: boolean;
}) {
  const [showInfoDialog, setShowInfoDialog] = useState(false);
  const articleId = Number(work.article_id);
  const artists = article ? parsePipeTags(article.Artists).slice(0, 2).join(', ') : '';
  const language = article?.Language ? article.Language.toUpperCase() : '';
  const pageCount = article?.Files ? `${article.Files.toLocaleString()}p` : '';
  const metaParts = [artists, language, pageCount].filter(Boolean);
  const matchedKeywords = formatWorkKeywords(work.matched_keywords);
  const fallbackKeywords = formatWorkKeywords(work.top_keywords);

  return (
    <>
      <button
        type="button"
        className={styles.workRow}
        onClick={() => {
          if (article) setShowInfoDialog(true);
        }}
        title={article ? article.Title : work.article_id}
      >
        <WorkThumbnail articleId={article?.Id ?? articleId} />
        <span className={styles.workMain}>
          <span className={styles.workTitle}>{article?.Title ?? (articleLoading ? 'loading article...' : `#${work.article_id}`)}</span>
          {metaParts.length > 0 && <span className={styles.workMeta}>{metaParts.join(' / ')}</span>}
          <span className={styles.workKeywords}>{matchedKeywords || fallbackKeywords}</span>
        </span>
        <span className={styles.workStats}>
          <span className={styles.workScore}>{formatScore(work.score)}</span>
          <span className={styles.workHit}>{work.matched_count}</span>
        </span>
      </button>
      {showInfoDialog &&
        article &&
        createPortal(<ArticleInfoDialog article={article} onClose={() => setShowInfoDialog(false)} />, document.body)}
    </>
  );
}

function formatWorkKeywords(keywords: RelatedWork['matched_keywords']): string {
  return keywords
    .slice(0, 4)
    .map((keyword) => keyword.keyword)
    .join(', ');
}

function readThemeColors(): ThemeColors {
  const styles = getComputedStyle(document.documentElement);
  const css = (name: string, fallback: string) => styles.getPropertyValue(name).trim() || fallback;
  const primary = css('--color-primary', '#7c5cbf');
  const text = css('--color-text', '#e0e0e0');
  const muted = css('--color-text-secondary', '#999');
  return {
    bg: css('--color-bg', '#0f0f0f'),
    panel: css('--color-bg-elevated', '#1a1a1a'),
    border: css('--color-border', '#333'),
    text,
    muted,
    primary,
    primaryHover: css('--color-primary-hover', primary),
    edge: colorMix(text, 0.42, '#64748b'),
    edgeMuted: colorMix(muted, 0.45, '#94a3b8'),
    selected: '#f97316',
    labelStroke: document.documentElement.dataset.theme === 'light' ? 'rgba(15, 23, 42, 0.45)' : 'rgba(0, 0, 0, 0.62)',
    palette: {
      primary,
      depthOne: '#08979c',
      depthTwo: '#7c3aed',
      depthThree: '#db2777',
      depthFour: '#ea580c',
      muted,
    },
  };
}

function colorMix(_color: string, _alpha: number, fallback: string): string {
  return fallback;
}
