// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';

class NHentaiManager {
  // [Thumbnail Image], [Big Thumbnails] [Image List]
  static Future<Tuple3<String, List<String>, List<String>>> getImageList(
      String id, int pageCount) async {
    var bt = List<String>.generate(pageCount,
        (index) => 'https://t.nhentai.net/galleries/$id/${index + 1}t.jpg');
    var il = List<String>.generate(pageCount,
        (index) => 'https://i.nhentai.net/galleries/$id/${index + 1}.jpg');

    var ti = 'https://t.nhentai.net/galleries/$id/cover.jpg';

    return Tuple3<String, List<String>, List<String>>(ti, bt, il);
  }
}
