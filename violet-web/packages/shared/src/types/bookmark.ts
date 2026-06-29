export interface BookmarkGroup {
  Id: number;
  Name: string;
  DateTime: string;
  Description: string | null;
  Color: number | null;
  Gorder: number;
}

export interface BookmarkArticle {
  Id: number;
  Article: string;
  DateTime: string;
  GroupId: number;
}

export interface BookmarkArtist {
  Id: number;
  Artist: string;
  IsGroup: ArtistType;
  DateTime: string;
  GroupId: number;
}

export enum ArtistType {
  Artist = 0,
  Group = 1,
  Uploader = 2,
  Series = 3,
  Character = 4,
}

export interface CreateBookmarkGroupRequest {
  Name: string;
  Description?: string;
  Color?: number;
}

export interface AddBookmarkArticleRequest {
  Article: string;
  GroupId?: number;
}

export interface AddBookmarkArtistRequest {
  Artist: string;
  IsGroup: ArtistType;
  GroupId?: number;
}

export interface BookmarkCropImage {
  Id: number;
  Article: number;
  Page: number;
  Area: string; // "left,top,right,bottom"
  AspectRatio: number;
  DateTime: string;
}

export interface AddBookmarkCropImageRequest {
  Article: number;
  Page: number;
  Area: string;
  AspectRatio: number;
}
