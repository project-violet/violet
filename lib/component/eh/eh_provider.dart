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
