// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/server/salt.dart';

import 'package:violet/network/wrapper.dart' as http;

class VioletServer {
  static const protocol = 'https';
  static const host = 'api.koromo.xyz';
  static const api = '$protocol://$host';

  static Future<dynamic> top(int offset, int count, String type) async {
    var gg = await http.get('$api/top?offset=$offset&count=$count&type=$type');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple2<int, int>(
              (e as List<dynamic>)[0] as int, (e as List<dynamic>)[1] as int))
          .toList();
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      return 900;
    }
  }

  static Future<void> view(int articleid) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());
    var userId = await getUserAppId();

    print(articleid);

    try {
      await http
          .post('$api/view',
              headers: {
                'v-token': vToken.toString(),
                'v-valid': vValid,
                "Content-Type": "application/json"
              },
              body: jsonEncode({'no': articleid.toString(), 'user': userId}))
          .then((value) {
        print(value.statusCode);
      });
    } catch (e) {}
  }

  static String _userId;
  static Future<String> getUserAppId() async {
    if (_userId == null)
      _userId = (await SharedPreferences.getInstance()).getString('fa_userid');
    return _userId;
  }
}
