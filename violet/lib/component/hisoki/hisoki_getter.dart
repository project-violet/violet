// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:violet/component/hisoki/hisoki_hash.dart';
import 'package:violet/network/wrapper.dart' as http;

class HisokiGetter {
  static Future<List<(String, double, double)>?> getImages(int id) async {
    var hash = HisokiHash.getHash('$id');

    if (hash == null) return null;

    var info = jsonDecode(
        (await http.get('https://hisoki.me/api/v1/manga/$hash')).body)['body'];
    var sl = info['sl'] as List<dynamic>;
    var il = info['il'] as List<dynamic>;

    var result = <(String, double, double)>[];

    for (var i = 0; i < il.length; i++) {
      result.add((
        '${il[i]}.webp',
        (sl[i]['w'] as int).toDouble(),
        (sl[i]['h'] as int).toDouble()
      ));
    }

    return result;
  }
}
