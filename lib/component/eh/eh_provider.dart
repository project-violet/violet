// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:html_unescape/html_unescape.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/thread/semaphore.dart';

class EHentaiImageProvider extends VioletImageProvider {
  // List<String> urls;
  int count;
  bool initialized = false;
  bool isEHentai;
  String thumbnail;
  List<String> pagesUrl;
  late List<String?> urls;
  late List<String> imgUrls;
  late Semaphore pageThrottler;

  EHentaiImageProvider({
    required this.count,
    required this.thumbnail,
    required this.pagesUrl,
    required this.isEHentai,
  });

  @override
  Future<void> init() async {
    if (initialized) return;
    pageThrottler = Semaphore(maxCount: 1);
    urls = List<String?>.filled(count, null);
    // for (int i = 0; i < pagesUrl.length; i++) {
    //   var phtml = await EHSession.requestString(pagesUrl[i]);
    //   urls.addAll(EHParser.getImagesUrl(phtml));
    // }
    imgUrls = List<String>.filled(count, '');
    initialized = true;
  }

  @override
  Future<List<String>> getSmallImagesUrl() async {
    var phtml = await EHSession.requestString('${pagesUrl[0]}&inline_set=ts_l');
    return EHParser.getThumbnailImages(phtml);
  }

  @override
  Future<String> getThumbnailUrl() async {
    return thumbnail;
  }

  @override
  Future<Map<String, String>> getHeader(int page) async {
    final prefs = await MultiPreferences.getInstance();
    var cookie = await prefs.getString('eh_cookies');
    return {'Cookie': cookie ?? ''};
  }

  @override
  Future<String> getImageUrl(int page) async {
    if (imgUrls[page] != '') {
      return imgUrls[page];
    }

    await pageThrottler.acquire();

    if (urls[page] == null) {
      // 40item per page
      var ppage = page ~/ 40;
      var phtml =
          await EHSession.requestString('${pagesUrl[ppage]}&inline_set=ts_m');
      var pages = EHParser.getImagesUrl(phtml);

      for (int i = 0; i < pages.length; i++) {
        urls[ppage * 40 + i] = pages[i];
      }
    }

    pageThrottler.release();

    var img = await EHSession.requestString(urls[page]!);

    if (Settings.downloadEhRawImage) {
      var unescape = HtmlUnescape();
      return imgUrls[page] =
          unescape.convert(EHParser.getOriginalImageAddress(img));
    }
    return imgUrls[page] = EHParser.getImageAddress(img);
  }

  @override
  bool canGetImageUrlSync() => false;

  @override
  String? getImageUrlSync(int page) => null;

  @override
  int length() {
    return count;
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

  @override
  Future<void> refreshPartial(List<bool> target) async {}

  @override
  Future<double> getOriginalImageHeight(int page) async {
    return -1;
  }
}
