// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:tuple/tuple.dart';
import 'package:http/http.dart' as http;

import 'package:violet/server/salt.dart';

class VioletServer {
  static const protocol = 'https';
  static const host = 'api.koromo.xyz';
  static const api = '$protocol://$host';

  static Future<List<Tuple2<int, int>>> top(
      int offset, int count, String type) async {
    var gg = await http.get('$api/top?offset=$offset&count=$count&type=$type');

    if (gg.statusCode != 200) {
      return null;
    }

    return (jsonDecode(gg.body)['result'] as List<dynamic>).map((e) =>
        Tuple2<int, int>(
            (e as List<dynamic>)[0] as int, (e as List<dynamic>)[1] as int));
  }

  static Future<void> view(int articleid) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    print(articleid);

    // throw view request
    try {
      http.post('$api/view',
          headers: {
            'v-token': vToken.toString(),
            'v-valid': vValid,
            "Content-Type": "application/json"
          },
          body: jsonEncode({'no': articleid.toString(), 'user': 'test'}));
    } catch (e) {}
  }
}
