import type { KeywordEdge, KeywordGraph, KeywordNode } from '../types/keyword-graph';

export interface GraphPalette {
  primary: string;
  depthOne: string;
  depthTwo: string;
  depthThree: string;
  depthFour: string;
  muted: string;
}

export type SigmaNodeData = {
  id: string;
  label: string;
  depth: number;
  df: number;
  community: string;
  labelPriority: number;
  color: string;
  size: number;
};

export type SigmaEdgeData = {
  id: string;
  source: string;
  target: string;
  score: number;
  cooccur: number;
  weight: number;
};

export type SigmaGraphData = {
  nodes: SigmaNodeData[];
  edges: SigmaEdgeData[];
};

export function buildSigmaGraphData(graph: KeywordGraph, palette: GraphPalette): SigmaGraphData {
  const communityByNode = assignCommunities(graph);
  return {
    nodes: graph.nodes.map((node) => ({
      id: node.id,
      label: node.label,
      depth: node.depth,
      df: node.df,
      community: communityByNode.get(node.id) ?? node.id,
      labelPriority: labelPriority(node),
      color: nodeColor(node.depth, palette),
      size: nodeSize(node),
    })),
    edges: graph.edges.map((edge) => ({
      id: edge.id,
      source: edge.from,
      target: edge.to,
      score: edge.score,
      cooccur: edge.cooccur,
      weight: edgeWeight(edge),
    })),
  };
}

export function summarizeGraph(graph: KeywordGraph | null): string {
  if (!graph) {
    return 'no graph';
  }
  const minCooccur = graph.edges.reduce<number | null>((minimum, edge) => {
    if (!Number.isFinite(edge.cooccur)) {
      return minimum;
    }
    return minimum == null ? edge.cooccur : Math.min(minimum, edge.cooccur);
  }, null);
  const summary = `${graph.nodes.length.toLocaleString()} nodes / ${graph.edges.length.toLocaleString()} edges`;
  return minCooccur == null ? summary : `${summary} / min cooccur ${minCooccur.toLocaleString()}`;
}

export function formatScore(value: number): string {
  return value.toLocaleString(undefined, {
    minimumFractionDigits: 3,
    maximumFractionDigits: 3,
  });
}

function nodeColor(depth: number, palette: GraphPalette): string {
  const colors = [
    palette.primary,
    palette.depthOne,
    palette.depthTwo,
    palette.depthThree,
    palette.depthFour,
    palette.muted,
  ];
  return colors[Math.min(Math.max(depth, 0), colors.length - 1)];
}

function assignCommunities(graph: KeywordGraph): Map<string, string> {
  const nodesByID = new Map(graph.nodes.map((node) => [node.id, node]));
  const communityByNode = new Map<string, string>();
  for (const node of graph.nodes) {
    if (node.depth <= 1) {
      communityByNode.set(node.id, node.id);
    }
  }
  for (const node of graph.nodes) {
    if (node.depth <= 1) {
      continue;
    }
    const parent = strongestDepthOneNeighbor(node.id, graph.edges, nodesByID);
    communityByNode.set(node.id, parent?.id ?? node.id);
  }
  return communityByNode;
}

function strongestDepthOneNeighbor(
  nodeID: string,
  edges: KeywordEdge[],
  nodesByID: Map<string, KeywordNode>,
): KeywordNode | null {
  let best: { node: KeywordNode; score: number } | null = null;
  for (const edge of edges) {
    const otherID = edge.from === nodeID ? edge.to : edge.to === nodeID ? edge.from : null;
    if (!otherID) {
      continue;
    }
    const other = nodesByID.get(otherID);
    if (!other || other.depth !== 1) {
      continue;
    }
    if (!best || edge.score > best.score) {
      best = { node: other, score: edge.score };
    }
  }
  return best?.node ?? null;
}

function nodeSize(node: KeywordNode): number {
  const dfSize = Math.log((node.df || 1) + 1) * 1.6;
  const depthBonus = node.depth === 0 ? 6 : node.depth === 1 ? 2 : 0;
  return Math.max(8, Math.min(24, 7 + dfSize + depthBonus));
}

function labelPriority(node: KeywordNode): number {
  const depthScore = node.depth === 0 ? 1000 : node.depth === 1 ? 520 : Math.max(0, 360 - node.depth * 80);
  return depthScore + Math.log((node.df || 1) + 1) * 12;
}

function edgeWeight(edge: KeywordEdge): number {
  return Math.max(0.4, Math.min(5.5, 0.7 + Math.log((edge.cooccur || 1) + 1) * 0.85));
}
