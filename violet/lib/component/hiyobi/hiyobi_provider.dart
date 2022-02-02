// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/component/image_provider.dart';
import 'package:tuple/tuple.dart';

class HiyobiImageProvider extends VioletImageProvider {
  Tuple2<String, List<String>> urls;

  HiyobiImageProvider(this.urls);

  @override
  Future<void> init() async {}

  @override
  Future<List<String>> getSmallImagesUrl() async {
    throw UnimplementedError();
  }

  @override
  Future<String> getThumbnailUrl() async {
    return urls.item1;
  }

  @override
  Future<Map<String, String>> getHeader(int page) async {
    return {};
  }

  @override
  Future<String> getImageUrl(int page) async {
    return urls.item2[page];
  }

  @override
  int length() {
    return urls.item2.length;
  }

  @override
  Future<double> getEstimatedImageHeight(int page, double baseWidth) async {
    return -1;
  }

  @override
  bool isRefreshable() {
    return false;
  }

  @override
  Future<void> refresh() async {}
}
