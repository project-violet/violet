// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:image_size_getter/image_size_getter.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/script/script_manager.dart';

class HitomiImageProvider extends VioletImageProvider {
  Tuple3<List<String>, List<String>, List<String>?> urls;
  String id;

  HitomiImageProvider(this.urls, this.id);

  @override
  Future<void> init() async {}

  @override
  Future<List<String>> getSmallImagesUrl() async {
    return urls.item3 ?? [];
  }

  @override
  Future<String> getThumbnailUrl() async {
    return urls.item2[0];
  }

  @override
  Future<Map<String, String>> getHeader(int page) async {
    // return {
    //   "Referer": 'https://hitomi.la/reader/1234.html',
    //   'accept': HttpWrapper.accept,
    //   'user-agent': HttpWrapper.userAgent,
    // };

    return await ScriptManager.runHitomiGetHeaderContent(id);
  }

  @override
  Future<String> getImageUrl(int page) async {
    return urls.item1[page];
  }

  @override
  bool canGetImageUrlSync() => true;

  @override
  String getImageUrlSync(int page) => urls.item1[page];

  @override
  int length() {
    return urls.item1.length;
  }

  List<double>? _heightCache;
  List<double>? _estimatedCache;

  @override
  Future<double> getEstimatedImageHeight(int page, double baseWidth) async {
    if (urls.item3 == null || urls.item3!.length <= page) return -1;

    if (_estimatedCache == null) {
      _estimatedCache = List<double>.filled(urls.item3!.length, 0);
    } else if (_estimatedCache![page] != 0) {
      return _estimatedCache![page];
    }

    final header = await getHeader(page);
    final image =
        (await http.get(urls.item3![page], headers: header)).bodyBytes;
    final thumbSize = ImageSizeGetter.getSize(MemoryInput(image));

    // w1:h1=w2:h2
    // w1h2=h1w2
    // h2=h1w2/w1
    return _estimatedCache![page] =
        thumbSize.height * baseWidth / thumbSize.width;
  }

  /*
    https://ltn.hitomi.la/common.js의 get_gg함수는 30분에 한 번씩 호출된다.
    이에 따라 get_gg에 의해 로드되는 gg.js는 적어도 30분에 한 번씩 재구성됨을 
    추론할 수 있다.
   */
  @override
  bool isRefreshable() {
    return true;
  }

  @override
  Future<void> refresh() async {
    urls = await HitomiManager.getImageList(id);
  }

  @override
  Future<void> refreshPartial(List<bool> target) async {
    if (urls.item1.length != target.length) {
      await refresh();
      return;
    }

    final turls = await HitomiManager.getImageList(id);

    for (var i = 0; i < turls.item1.length; i++) {
      if (target[i]) urls.item1[i] = turls.item1[i];
    }
  }

  @override
  Future<double> getOriginalImageHeight(int page) async {
    if (_heightCache == null) {
      _heightCache = List<double>.filled(urls.item3!.length, 0);
    } else if (_heightCache![page] != 0) {
      return _heightCache![page];
    }

    final info = await ScriptManager.getGalleryInfo(id);
    if (info == null) {
      _heightCache = List<double>.filled(urls.item3!.length, -1);
      return -1;
    }

    print(info);

    final json = jsonDecode(info.split('var galleryinfo = ')[1].split(';')[0]);

    for (final file in json['files']) {
      _heightCache![page] = file['height'].toDouble();
    }

    return _heightCache![page];
  }
}
