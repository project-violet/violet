// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.



abstract class VioletImageProvider {
  int length();
  Future<void> init(); // init for viewer
  Future<String> getThumbnailUrl();
  Future<List<String>> getSmallImagesUrl();
  Future<String> getImageUrl(int page);
  Future<Map<String, String>> getHeader(int page);
}
