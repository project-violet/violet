// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:tuple/tuple.dart';
import 'package:violet/component/image_provider.dart';

class HitomiImageProvider extends VioletImageProvider {
  Tuple3<List<String>, List<String>, List<String>> urls;

  HitomiImageProvider(this.urls);

  @override
  Future<void> init() async {}

  @override
  Future<List<String>> getSmallImagesUrl() async {
    return urls.item3;
  }

  @override
  Future<String> getThumbnailUrl() async {
    return urls.item2[0];
  }

  @override
  Future<Map<String, String>> getHeader(int page) async {
    return {"Referer": 'https://hitomi.la/reader/1234.html'};
  }

  @override
  Future<String> getImageUrl(int page) async {
    return urls.item1[page];
  }

  @override
  int length() {
    return urls.item1.length;
  }
}
