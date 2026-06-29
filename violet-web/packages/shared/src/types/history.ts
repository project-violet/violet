export interface ArticleReadLog {
  Id: number;
  Article: string;
  DateTimeStart: string;
  DateTimeEnd: string | null;
  LastPage: number;
  Type: ReadLogType;
}

export enum ReadLogType {
  FromSearch = 0,
  FromBookmark = 1,
}

export interface InsertReadLogRequest {
  Article: string;
  Type: ReadLogType;
}

export interface UpdateReadLogRequest {
  LastPage: number;
  DateTimeEnd?: string;
}
