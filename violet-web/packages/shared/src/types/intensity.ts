export type IntensityPeak = [page: number, score: number];
export type IntensityPageRange = [startPage: number, endPage: number];

export interface IntensityTimeline {
  workId: number;
  pageCount: number;
  raw: number[];
  smooth: number[];
  peaks: IntensityPeak[];
  interpolatedRanges?: IntensityPageRange[];
  status?: 'no_dialogue_chunks';
}

export interface IntensityTimelineStatus {
  available: boolean;
  indexedWorks: number;
  fileSize: number;
  error?: string;
}
