import type { GraphRequest } from '../types/keyword-graph';

export type ComplexityPreset = 'compact' | 'balanced' | 'full';

type ComplexityPresetConfig = Pick<GraphRequest, 'topN' | 'minCooccur' | 'autoMinCooccur' | 'minKeywordDF' | 'maxNodes'> & {
  value: ComplexityPreset;
  label: string;
};

export const complexityPresets: ComplexityPresetConfig[] = [
  {
    value: 'compact',
    label: 'Compact',
    topN: 8,
    minCooccur: 0,
    autoMinCooccur: true,
    minKeywordDF: 30,
    maxNodes: 90,
  },
  {
    value: 'balanced',
    label: 'Balanced',
    topN: 14,
    minCooccur: 0,
    autoMinCooccur: true,
    minKeywordDF: 30,
    maxNodes: 150,
  },
  {
    value: 'full',
    label: 'Full',
    topN: 24,
    minCooccur: 0,
    autoMinCooccur: true,
    minKeywordDF: 30,
    maxNodes: 320,
  },
];

export function applyComplexityPreset(request: GraphRequest, preset: ComplexityPreset): GraphRequest {
  const config = complexityPresets.find((candidate) => candidate.value === preset) ?? complexityPresets[0];
  return {
    ...request,
    topN: config.topN,
    minCooccur: config.minCooccur,
    autoMinCooccur: config.autoMinCooccur,
    minKeywordDF: config.minKeywordDF,
    maxNodes: config.maxNodes,
  };
}
