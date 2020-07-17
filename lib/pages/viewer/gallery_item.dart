// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

class GalleryExampleItem {
  GalleryExampleItem({
    this.id,
    this.url,
    this.headers,
    this.isSvg = false,
    this.loaded = false,
  });

  final String id;
  final String url;
  final Map<String, String> headers;
  final bool isSvg;
  double height;
  bool loaded;
}
