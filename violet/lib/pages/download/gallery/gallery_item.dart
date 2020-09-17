// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:violet/database/user/download.dart';

const imageExtensions = [
  'png',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'rle',
  'dib',
  'jpg',
  'tif',
  'jfif',
  'jpe',
  'psd',
  'jp2',
  'j2c',
  'tiff',
  'raw'
];

class GalleryItem {
  // Content Path
  // One of Movie, One of Picture, One of File
  final String path;
  final int downloadItemId;
  bool isPhoto;
  final bool hasThumbnail;
  final String thumbnailAddress;
  final String thumbnailUrl;
  final dynamic thumbnailHeader;
  final List<String> files;
  final int filesIndex;

  GalleryItem({
    @required this.path,
    @required this.downloadItemId,
    @required this.files,
    @required this.filesIndex,
    this.isPhoto,
    this.hasThumbnail,
    this.thumbnailUrl,
    this.thumbnailAddress,
    this.thumbnailHeader,
  }) {
    if (this.isPhoto == null) {
      // Image Extensions
      if (imageExtensions.contains(path.split('.').last))
        isPhoto = true;
      else
        isPhoto = false;
    }
  }

  static List<GalleryItem> fromDonwloadItem(DownloadItemModel item) {
    if (item.files() == null) return null;
    List<String> files = (jsonDecode(item.files()) as List<dynamic>)
        .map((e) => e as String)
        .toList();
    int index = 0;

    return files
        .map((e) => GalleryItem(
              files: files,
              filesIndex: index++,
              downloadItemId: item.id(),
              path: e,
              thumbnailUrl: item.thumbnail(),
              thumbnailHeader: item.thumbnailHeader(),
            ))
        .toList();
  }
}
