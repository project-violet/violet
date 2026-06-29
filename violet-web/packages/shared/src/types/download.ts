export type DownloadStatus = 'pending' | 'downloading' | 'completed' | 'failed';

export interface DownloadRecord {
  Id: number;
  Article: string;
  Status: DownloadStatus;
  TotalPages: number;
  DownloadedPages: number;
  DateTime: string;
  ErrorMessage: string | null;
}
