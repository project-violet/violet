// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/thread/semaphore.dart';

class EHentaiImageProvider extends VioletImageProvider {
  // List<String> urls;
  int count;
  bool initialized = false;
  bool isEHentai;
  String thumbnail;
  List<String> pagesUrl;
  List<String> urls;
  List<String> imgUrls;
  Semaphore pageThrottler;

  EHentaiImageProvider(
      {this.count, this.thumbnail, this.pagesUrl, this.isEHentai});

  @override
  Future<void> init() async {
    if (initialized) return;
    pageThrottler = Semaphore(maxCount: 1);
    urls = List<String>.filled(count, null);
    // for (int i = 0; i < pagesUrl.length; i++) {
    //   var phtml = await EHSession.requestString(pagesUrl[i]);
    //   urls.addAll(EHParser.getImagesUrl(phtml));
    // }
    imgUrls = List<String>.filled(count, '');
    initialized = true;
  }

  @override
  Future<List<String>> getSmallImagesUrl() async {
    // https://e-hentai.org/g/1740744/2944a0ec84/
    // https://ehgt.org/m/001740/1740744-00.jpg
    throw UnimplementedError();
  }

  @override
  Future<String> getThumbnailUrl() async {
    return thumbnail;
  }

  @override
  Future<Map<String, String>> getHeader(int page) async {
    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies');
    return {"Cookie": cookie};
  }

  @override
  Future<String> getImageUrl(int page) async {
    if (imgUrls[page] != '') {
      return imgUrls[page];
    }

    await pageThrottler.acquire();

    if (urls[page] == null) {
      // 20item per page
      var ppage = page ~/ (isEHentai ? 40 : 20);
      print(pagesUrl[ppage]);
      var phtml = await EHSession.requestString(pagesUrl[ppage]);
      var pages = EHParser.getImagesUrl(phtml);

      for (int i = 0; i < pages.length; i++) {
        urls[ppage * (isEHentai ? 40 : 20) + i] = pages[i];
      }
      for (var a in urls) print(a);
    }

    pageThrottler.release();

    var img = await EHSession.requestString(urls[page]);
    return imgUrls[page] = EHParser.getImagesAddress(img);
  }

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
}
