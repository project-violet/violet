// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

abstract class VioletImageProvider {
  int length();
  Future<void> init(); // init for viewer
  Future<String> getThumbnailUrl();
  Future<List<String>> getSmallImagesUrl();
  Future<String> getImageUrl(int page);
  bool canGetImageUrlSync();
  String? getImageUrlSync(int page);
  Future<Map<String, String>> getHeader(int page);
  Future<double> getEstimatedImageHeight(int page, double baseWidth);
  Future<double> getOriginalImageHeight(int page);
  bool isRefreshable();
  Future<void> refresh();
  Future<void> refreshPartial(List<bool> target);
}
