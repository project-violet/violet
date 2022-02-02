// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:violet/network/wrapper.dart' as http;
import 'package:tuple/tuple.dart';

class HiyobiManager {
  // [Thumbnail Image], [Image List]
  static Future<Tuple2<String, List<String>>> getImageList(String id) async {
    var gg = await http.get('https://cdn.hiyobi.me/json/${id}_list.json');
    var urls = gg.body;
    var files = jsonDecode(urls) as List<dynamic>;
    var result = List<String>();

    files.forEach((value) {
      if (value['haswebp'] == 1)
        result.add('https://cdn.hiyobi.me/data/$id/${value['hash']}.webp');
      else
        result.add('https://rcdn.hiyobi.me/data_r/$id/${value['name']}');
    });

    return Tuple2<String, List<String>>(
        'https://tn.hiyobi.me/tn/$id.jpg', result);
  }
}
