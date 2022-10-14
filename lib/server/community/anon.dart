// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/log/log.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/server/wsalt.dart';

class VioletCommunityAnonymous {
  static Future<dynamic> _getV(String api, String params) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());
    var gg =
        await http.get(Uri.parse('${VioletServer.api}$api?$params'), headers: {
      'v-token': vToken.toString(),
      'v-valid': vValid,
      'Content-Type': 'application/json'
    });

    if (gg.statusCode != 200) {
      return gg.statusCode;
    }

    return jsonDecode(gg.body);
  }

  static Future<dynamic> _postV(String api, Object body) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.post(Uri.parse(VioletServer.api + api),
          headers: {
            'v-token': vToken.toString(),
            'v-valid': vValid,
            'Content-Type': 'application/json'
          },
          body: jsonEncode(body));
      return res;
    } catch (e, st) {
      Logger.error('[API-postv] E: $e\n'
          '$st');
    }
    return null;
  }

  static String? _userAppId;
  static Future<String> _getUserAppId() async {
    if (_userAppId == null) {
      final prefs = await SharedPreferences.getInstance();
      _userAppId = prefs.getString('fa_userid');
    }
    return _userAppId!;
  }

  /* UserAppId, Body, TimeStamp */
  static Future<dynamic> getArtistComments(String artistName) async {
    // artistName = group:<name> | artist:<name>
    return await _getV(
        '/community/anon/artistcomment/read', 'name=$artistName');
  }

  static Future<dynamic> getArtistCommentsRecent(
      [int offset = 0, int count = 10]) async {
    // artistName = group:<name> | artist:<name>
    return await _getV(
        '/community/anon/artistcomment/recent', 'count=$count&offset=$offset');
  }

  static Future<dynamic> postArtistComment(
      int? parent, String artistName, String commentBody) async {
    if (parent == null) {
      return await _postV('/community/anon/artistcomment/write', {
        'UserAppId': await _getUserAppId(),
        'ArtistName': artistName,
        'Body': commentBody,
      });
    }

    return await _postV('/community/anon/artistcomment/write', {
      'UserAppId': await _getUserAppId(),
      'ArtistName': artistName,
      'Body': commentBody,
      'Parent': parent,
    });
  }
}
