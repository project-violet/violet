// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
    final gg =
        await http.get('$api/top?offset=$offset&count=$count&type=$type');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) =>
              Tuple2<int, int>((e as List<dynamic>)[0] as int, (e)[1] as int))
          .toList();
      return result;
    } catch (e, st) {
      Logger.error('[API-top] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> topRecent(int s) async {
    final gg = await http.get('$api/top_recent?s=$s');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) =>
              Tuple2<int, int>((e as List<dynamic>)[0] as int, (e)[1] as int))
          .toList();
      return result;
    } catch (e, st) {
      Logger.error('[API-top-recent] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> topTs(int s) async {
    final gg = await http.get('$api/top_ts?s=$s');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result =
          DateTime.parse(jsonDecode(gg.body)['result'] as String).toLocal();
      return result;
    } catch (e, st) {
      Logger.error('[API-top-ts] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> curTs() async {
    final gg = await http.get('$api/cur_ts');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result =
          DateTime.parse(jsonDecode(gg.body)['result'] as String).toLocal();
      return result;
    } catch (e, st) {
      Logger.error('[API-cur-ts] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<void> view(int articleid) async {
    final userId = await _getUserAppId();

    try {
      await http.post(
        '$api/view',
        headers: _vHeader(),
        body: jsonEncode({
          'no': articleid.toString(),
          'user': userId,
        }),
      );
    } catch (e, st) {
      Logger.error('[API-view] E: $e\n'
          '$st');
    }
  }

  static Future<void> viewClose(int articleid, int readTime) async {
    final userId = await _getUserAppId();

    try {
      await http.post(
        '$api/view_close',
        headers: _vHeader(),
        body: jsonEncode({
          'no': articleid.toString(),
          'user': userId,
          'time': readTime,
        }),
      );
    } catch (e, st) {
      Logger.error('[API-close] E: $e\n'
          '$st');
    }
  }

  static Future<void> viewReport(ViewerReport report) async {
    final userId = await _getUserAppId();
    final submission = report.submission();
    final body = {
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
      await http.post(
        '$api/view_report',
        headers: _vHeader(),
        body: jsonEncode(body),
      );
    } catch (e, st) {
      Logger.error('[API-report] E: $e\n'
          '$st');
    }
  }

  static Future<bool> fileUploadBytes(String fn, Uint8List data) async {
    final userId = await _getUserAppId();

    try {
      final res = await http.post(
        '$api/fupload',
        headers: _vHeader(),
        body: jsonEncode({
          'user': userId,
          'fn': fn,
          'data': data,
        }),
      );

      return res.statusCode == 200;
    } catch (e, st) {
      Logger.error('[API-fupload] E: $e\n'
          '$st');
    }
    return false;
  }

  static Future<void> uploadFile(String filename) async {
    final filePath = filename;

    final dio = Dio();
    final formData =
        FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});

    await dio.post('$api/fupload', data: formData);
  }

  static Future<void> uploadString(String filename, String data) async {
    final dio = Dio();
    final formData = FormData.fromMap(
        {'file': MultipartFile.fromString(data, filename: filename)});

    await dio.post('$api/fupload', data: formData);
  }

  static Future<bool> fileUpload(String fn, String data) async {
    final userId = await _getUserAppId();

    try {
      final res = await http.post(
        '$api/fupload',
        headers: _vHeader(),
        body: jsonEncode({
          'user': userId,
          'fn': fn,
          'data': data,
        }),
      );

      return res.statusCode == 200;
    } catch (e, st) {
      Logger.error('[API-fupload] E: $e\n'
          '$st');
    }
    return false;
  }

  static Future<bool> uploadBookmark() async {
    final userId = await _getUserAppId();
    // final prefs = await SharedPreferences.getInstance();
    // final upload = prefs.getBool('upload_bookmark_179_test');
    // if (upload != null && upload != false) return false;

    /*
      ArticleReadLog
      BookmarkArticle
      BookmarkArtist
      BookmarkGroup
    */

    final user = await User.getInstance();
    final db = await Bookmark.getInstance();

    final record = await user.getUserLog();
    final article = await db.getArticle();
    final artist = await db.getArtist();
    final group = await db.getGroup();

    final uploadData = jsonEncode({
      'record': record.map((e) => e.result).toList(),
      'article': article.map((e) => e.result).toList(),
      'artist': artist.map((e) => e.result).toList(),
      'group': group.map((e) => e.result).toList(),
    });

    try {
      final res = await http.post(
        '$api/bookmarks/v2/upload',
        headers: _vHeader(),
        body: jsonEncode({
          'user': userId,
          'data': uploadData,
        }),
      );

      // final prefs = await SharedPreferences.getInstance();
      // await prefs.setBool('upload_bookmark_179', true);

      return res.statusCode == 200;
    } catch (e, st) {
      Logger.error('[API-upload] E: $e\n'
          '$st');
    }
    return false;
  }

  static String? _userId;
  static Future<String> _getUserAppId() async {
    if (_userId == null) {
      final prefs = await MultiPreferences.getInstance();
      _userId = await prefs.getString('fa_userid');
    }
    return _userId!;
  }

  // https://koromo.xyz/api/record/recent?count=10&limit=180
  static Future<dynamic> record(
      [int offset = 0, int count = 10, int limit = 0]) async {
    final gg = await http
        .get('$api/record/recent?offset=$offset&count=$count&limit=$limit');

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple3<int, int, int>(
              (e as List<dynamic>)[0] as int, (e)[1] as int, (e)[2] as int))
          .toList();
      return result;
    } catch (e, st) {
      Logger.error('[API-record] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> recordU(
      [int offset = 0, int count = 10, int limit = 0]) async {
    final gg = await http.get(
      '$api/record/recent_u?offset=$offset&count=$count&limit=$limit',
      headers: _vwHeader(),
    );

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple4<int, int, int, String>(
              (e as List<dynamic>)[0] as int,
              (e)[1] as int,
              (e)[2] as int,
              (e)[3] as String))
          .toList();
      return result;
    } catch (e, st) {
      Logger.error('[API-record] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> userRecent(String userAppId,
      [int count = 10, int limit = 0]) async {
    final gg = await http.get(
      '$api/record/user_recent?userid=$userAppId&count=$count&limit=$limit',
      headers: _vwHeader(),
    );

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple3<int, int, int>(
              (e as List<dynamic>)[0] as int, (e)[1] as int, (e)[2] as int))
          .toList();
      return result;
    } catch (e, st) {
      Logger.error('[API-record] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> searchComment(String param) async {
    final gg = await http.get(
      '$api/excomment/find?q=${Uri.encodeFull(param)}',
      headers: _vwHeader(),
    );

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple4<int, DateTime, String, String>(
              int.parse((e as Map<String, dynamic>)['id'] as String),
              DateTime.parse((e)['time'] as String),
              (e)['author'] as String,
              (e)['body'] as String))
          .toList();
      return result;
    } catch (e, st) {
      Logger.error('[API-searchComment] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> searchCommentAuthor(String author) async {
    final gg = await http.get(
      '$api/excomment/author?q=${Uri.encodeFull(author)}',
      headers: _vwHeader(),
    );

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body)['result'] as List<dynamic>)
          .map((e) => Tuple4<int, DateTime, String, String>(
              int.parse((e as Map<String, dynamic>)['id'] as String),
              DateTime.parse((e)['time'] as String),
              (e)['author'] as String,
              (e)['body'] as String))
          .toList();
      return result;
    } catch (e, st) {
      Logger.error('[API-searchComment] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> searchMessage(String type, String what) async {
    final gg = await http.get(
      '${Settings.searchMessageAPI}/$type/${Uri.encodeFull(what)}',
      headers: _vwHeader(),
    );

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body) as List<dynamic>);
      return result;
    } catch (e, st) {
      Logger.error('[API-searchMessage] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> searchMessageWord(int articleId, String what) async {
    final gg = await http.get(
      '${Settings.searchMessageAPI}/wcontains/$articleId/${Uri.encodeFull(what)}',
      headers: _vwHeader(),
    );

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    try {
      final result = (jsonDecode(gg.body) as List<dynamic>);
      return result;
    } catch (e, st) {
      Logger.error('[API-searchMessageWord] E: $e\n'
          '$st');

      return 900;
    }
  }

  static Future<dynamic> restoreBookmark(String userAppId) async {
    try {
      final res = await http.get(
        '$api/bookmarks/v2/restore?user=$userAppId',
        headers: _vHeader(),
      );

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as Map<String, dynamic>;
    } catch (e, st) {
      Logger.error('[API-restore] E: $e\n'
          '$st');
    }
    return false;
  }

  static Future<List<dynamic>?> bookmarkLists() async {
    try {
      final res = await http.get(
        '$api/bookmarks/v2/bookmarks',
        headers: _vHeader(),
      );

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as List<dynamic>;
    } catch (e, st) {
      Logger.error('[API-bookmarks] E: $e\n'
          '$st');
    }
    return null;
  }

  static Future<List<dynamic>?> versionsBookmark(String userAppId) async {
    try {
      final res = await http.get(
        '$api/bookmarks/v2/versions?user=$userAppId',
        headers: _vHeader(),
      );

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as List<dynamic>;
    } catch (e, st) {
      Logger.error('[API-versions] E: $e\n'
          '$st');
    }
    return null;
  }

  static Future<dynamic> resotreBookmarkWithVersion(
      String userAppId, String vid) async {
    try {
      final res = await http.get(
        '$api/bookmarks/v2/restore_v?user=$userAppId&vid=$vid',
        headers: _vHeader(),
      );

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body)['result'] as Map<String, dynamic>;
    } catch (e, st) {
      Logger.error('[API-restore_v] E: $e\n'
          '$st');
    }
    return false;
  }

  static Map<String, String> _vHeader() {
    final vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    final vValid = getValid(vToken.toString());

    return {
      'v-token': vToken.toString(),
      'v-valid': vValid,
      'Content-Type': 'application/json'
    };
  }

  static Map<String, String> _vwHeader() {
    final vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    final vValid = wsalt.getValid(vToken.toString());

    return {
      'v-token': vToken.toString(),
      'v-valid': vValid,
      'Content-Type': 'application/json'
    };
  }
}
