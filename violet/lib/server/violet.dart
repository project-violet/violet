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
import 'package:violet/server/wsalt.dart' as wsalt;
import 'package:violet/settings/settings.dart';

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

  static Future<dynamic> top_recent(int s) async {
    var gg = await http.get('$api/top_recent?s=$s');

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
      Logger.error(
          '[API-top-recent] E: ' + e.toString() + '\n' + st.toString());

      return 900;
    }
  }

  static Future<dynamic> top_ts(int s) async {
    var gg = await http.get('$api/top_ts?s=$s');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result =
          DateTime.tryParse(jsonDecode(gg.body)['result'] as String).toLocal();
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      Logger.error('[API-top-ts] E: ' + e.toString() + '\n' + st.toString());

      return 900;
    }
  }

  static Future<dynamic> cur_ts() async {
    var gg = await http.get('$api/cur_ts');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result =
          DateTime.tryParse(jsonDecode(gg.body)['result'] as String).toLocal();
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      Logger.error('[API-cur-ts] E: ' + e.toString() + '\n' + st.toString());

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
    // var upload = (await SharedPreferences.getInstance())
    //     .getBool('upload_bookmark_179_test');
    // if (upload != null && upload != false) return false;

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
          .post('$api/bookmarks/upload',
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

      // await (await SharedPreferences.getInstance())
      //     .setBool('upload_bookmark_179', true);

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

  static Future<dynamic> recordU(
      [int offset = 0, int count = 10, int limit = 0]) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = wsalt.getValid(vToken.toString());

    var gg = await http.get(
        '$api/record/recent_u?offset=$offset&count=$count&limit=$limit',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        });

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple4<int, int, int, String>(
              (e as List<dynamic>)[0] as int,
              (e as List<dynamic>)[1] as int,
              (e as List<dynamic>)[2] as int,
              (e as List<dynamic>)[3] as String))
          .toList();
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      Logger.error('[API-record] E: ' + e.toString() + '\n' + st.toString());

      return 900;
    }
  }

  static Future<dynamic> userRecent(String userAppId,
      [int count = 10, int limit = 0]) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = wsalt.getValid(vToken.toString());

    var gg = await http.get(
        '$api/record/user_recent?userid=$userAppId&count=$count&limit=$limit',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        });

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

  static Future<dynamic> searchComment(String param) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = wsalt.getValid(vToken.toString());

    var gg = await http
        .get('$api/excomment/find?q=' + Uri.encodeFull(param), headers: {
      'v-token': vToken.toString(),
      'v-valid': vValid,
      "Content-Type": "application/json"
    });

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple4<int, DateTime, String, String>(
              int.parse((e as Map<String, dynamic>)['id'] as String),
              DateTime.parse((e as Map<String, dynamic>)['time'] as String),
              (e as Map<String, dynamic>)['author'] as String,
              (e as Map<String, dynamic>)['body'] as String))
          .toList();
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      Logger.error(
          '[API-searchComment] E: ' + e.toString() + '\n' + st.toString());

      return 900;
    }
  }

  static Future<dynamic> searchCommentAuthor(String author) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = wsalt.getValid(vToken.toString());

    var gg = await http
        .get('$api/excomment/author?q=' + Uri.encodeFull(author), headers: {
      'v-token': vToken.toString(),
      'v-valid': vValid,
      "Content-Type": "application/json"
    });

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple4<int, DateTime, String, String>(
              int.parse((e as Map<String, dynamic>)['id'] as String),
              DateTime.parse((e as Map<String, dynamic>)['time'] as String),
              (e as Map<String, dynamic>)['author'] as String,
              (e as Map<String, dynamic>)['body'] as String))
          .toList();
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      Logger.error(
          '[API-searchComment] E: ' + e.toString() + '\n' + st.toString());

      return 900;
    }
  }

  static Future<dynamic> searchMessage(String type, String what) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = wsalt.getValid(vToken.toString());

    var gg = await http.get(
        '${Settings.searchMessageAPI}/$type/' + Uri.encodeFull(what),
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        });

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      var result = (jsonDecode(gg.body) as List<dynamic>);
      return result;
    } catch (e, st) {
      print(e);
      print(st);
      Logger.error(
          '[API-searchMessage] E: ' + e.toString() + '\n' + st.toString());

      return 900;
    }
  }

  static Future<dynamic> resotreBookmark(String userAppId) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.get(
        '$api/bookmarks/restore?user=$userAppId',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        },
      ).then((value) {
        print(value.statusCode);
        return value;
      });

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as Map<String, dynamic>;
    } catch (e, st) {
      Logger.error('[API-restore] E: ' + e.toString() + '\n' + st.toString());
    }
    return false;
  }

  static Future<List<dynamic>> bookmarkLists() async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.get(
        '$api/bookmarks/bookmarks',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        },
      ).then((value) {
        print(value.statusCode);
        return value;
      });

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as List<dynamic>;
    } catch (e, st) {
      Logger.error('[API-bookmarks] E: ' + e.toString() + '\n' + st.toString());
    }
    return null;
  }

  static Future<List<dynamic>> versionsBookmark(String userAppId) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.get(
        '$api/bookmarks/versions?user=$userAppId',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        },
      ).then((value) {
        print(value.statusCode);
        return value;
      });

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as List<dynamic>;
    } catch (e, st) {
      Logger.error('[API-versions] E: ' + e.toString() + '\n' + st.toString());
    }
    return null;
  }

  static Future<dynamic> resotreBookmarkWithVersion(
      String userAppId, String vid) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.get(
        '$api/bookmarks/restore_v?user=$userAppId&vid=$vid',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          "Content-Type": "application/json"
        },
      ).then((value) {
        print(value.statusCode);
        return value;
      });

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as Map<String, dynamic>;
    } catch (e, st) {
      Logger.error('[API-restore_v] E: ' + e.toString() + '\n' + st.toString());
    }
    return false;
  }
}
