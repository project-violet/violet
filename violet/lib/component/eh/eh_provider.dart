// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/image_provider.dart';

class EHentaiImageProvider extends VioletImageProvider {
  List<String> urls;

  EHentaiImageProvider(this.urls);

  @override
  Future<List<String>> getSmallImagesUrl() async {
    // https://e-hentai.org/g/1740744/2944a0ec84/
    // https://ehgt.org/m/001740/1740744-00.jpg
    throw UnimplementedError();
  }

  @override
  Future<String> getThumbnailUrl() async {
    return await getImageUrl(0);
  }

  @override
  Future<Map<String, String>> getHeader(int page) async {
    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies');
    return {"Cookie": cookie};
  }

  @override
  Future<String> getImageUrl(int page) async {
    var img = await EHSession.requestString(urls[page]);
    return EHParser.getImagesAddress(img);
  }

  @override
  int length() {
    return urls.length;
  }
}
