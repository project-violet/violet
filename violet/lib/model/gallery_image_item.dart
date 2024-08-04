// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

class GalleryImageItem {
  GalleryImageItem({
    required this.id,
    required this.url,
    required this.headers,
    this.isSvg = false,
    this.loaded = false,
  });

  final String id;
  final String url;
  final Map<String, String> headers;
  final bool isSvg;
  double? height;
  bool loaded;
}
