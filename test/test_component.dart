// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/eh/eh_parser.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  // test("EHentai Gallery Parse", () async {
  //   var result =
  //       await HentaiManager.searchEHentai('"female:big breasts"', "0", false);

  //   expect(result.length >= 25, true);
  // });

  // test("Hitomi Article Info from Gallery Id", () async {
  //   const targetId = 1916981;

  //   var result = await HitomiManager.getImageList('$targetId');

  //   expect(result.item1.length, 42);
  // });

  // test("EHentai Get Original Image Address", () async {
  //   var body =
  //       'lass="mr" /> <a href="https://e-hentai.org/fullimg.php?gid=1344011&amp;page=2&amp;key=3m0vqlp9ta0">Download original 2078 x 3000 4.44 MB source<';

  //   print(EHParser.getOriginalImageAddress(body));
  // });

  test("EHentai Get Thumbnail Images Address", () async {
    var body = """
Page 20: 020.jpg" src="https://exhentai.org/t/66/55/6655fb520e13eff74ebf9aa49c210cfb7fdfc1d9-1069560-2120-3000-jpg_l.jpg" /></a></div><
 src="https://ehgt.org/f5/f8/f5f8425827e4c8c0658385b4d3cb80adc23e1b94-518399-1280-1810-jpg_l.jpg" /></a
        """;

    print(EHParser.getThumbnailImages(body));
  });
}
