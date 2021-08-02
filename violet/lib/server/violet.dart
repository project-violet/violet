// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/pages/viewer/viewer_report.dart';
import 'package:violet/server/salt.dart';

class VioletServer {
  static const protocol = 'https';
  static const host = 'koromo.xyz/api';
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
      Logger.error('[API-top] E: ' + e.toString() + '\n' + st.toString());

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
    } catch (e, st) {
      Logger.error('[API-view] E: ' + e.toString() + '\n' + st.toString());
    }
  }

  static Future<void> viewClose(int articleid, int readTime) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());
    var userId = await getUserAppId();

    print(articleid);

    try {
      await http
          .post('$api/view_close',
              headers: {
                'v-token': vToken.toString(),
                'v-valid': vValid,
                "Content-Type": "application/json"
              },
              body: jsonEncode({
                'no': articleid.toString(),
                'user': userId,
                'time': readTime
              }))
          .then((value) {
        print(value.statusCode);
      });
    } catch (e, st) {
      Logger.error('[API-close] E: ' + e.toString() + '\n' + st.toString());
    }
  }

  static Future<void> viewReport(ViewerReport report) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());
    var userId = await getUserAppId();
    var submission = report.submission();
    var body = {
      'user': userId,
      'id': submission['id'],
      'pages': submission['pages'],
      'startsTime': submission['startsTime'],
      'endsTime': submission['endsTime'],
      'lastPage': submission['lastPage'],
      'validSeconds': submission['validSeconds'],
      'msPerPages': submission['msPerPages'],
    };

    try {
      await http
          .post(
        '$api/view_report',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        },
        body: jsonEncode(body),
      )
          .then((value) {
        print(value.statusCode);
      });
    } catch (e, st) {
      Logger.error('[API-report] E: ' + e.toString() + '\n' + st.toString());
    }
  }

  static Future<bool> uploadBookmark() async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());
    var userId = await getUserAppId();
    var upload = (await SharedPreferences.getInstance())
        .getBool('upload_bookmark_178_test');
    if (upload != null && upload != false) return false;

    /*
      ArticleReadLog
      BookmarkArticle
      BookmarkArtist
      BookmarkGroup
    */

    var user = await User.getInstance();
    var db = await Bookmark.getInstance();

    var record = await user.getUserLog();
    var article = await db.getArticle();
    var artist = await db.getArtist();
    var group = await db.getGroup();

    var uploadData = jsonEncode({
      'record': record.map((e) => e.result).toList(),
      'article': article.map((e) => e.result).toList(),
      'artist': artist.map((e) => e.result).toList(),
      'group': group.map((e) => e.result).toList(),
    });

    try {
      var res = await http
          .post('$api/upload',
              headers: {
                'v-token': vToken.toString(),
                'v-valid': vValid,
                "Content-Type": "application/json"
              },
              body: jsonEncode({
                'user': userId,
                'data': uploadData,
              }))
          .then((value) {
        print(value.statusCode);
        return value;
      });

      await (await SharedPreferences.getInstance())
          .setBool('upload_bookmark_178', true);

      return res.statusCode == 200;
    } catch (e, st) {
      Logger.error('[API-upload] E: ' + e.toString() + '\n' + st.toString());
    }
    return false;
  }

  static String _userId;
  static Future<String> getUserAppId() async {
    if (_userId == null)
      _userId = (await SharedPreferences.getInstance()).getString('fa_userid');
    return _userId;
  }

  // https://koromo.xyz/api/record/recent?count=10&limit=180
  static Future<dynamic> record(
      [int offset = 0, int count = 10, int limit = 0]) async {
    var gg = await http
        .get('$api/record/recent?offset=$offset&count=$count&limit=$limit');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple3<int, int, int>((e as List<dynamic>)[0] as int,
              (e as List<dynamic>)[1] as int, (e as List<dynamic>)[2] as int))
          .toList();
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      Logger.error('[API-record] E: ' + e.toString() + '\n' + st.toString());

      return 900;
    }
  }
}
