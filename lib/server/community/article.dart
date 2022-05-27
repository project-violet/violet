// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:violet/log/log.dart';
import 'package:violet/server/community/session.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/server/wsalt.dart';

class VioletCommunityArticle {
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

  /* Id, ShortName, Name, Description */
  static Future<dynamic> getBoards() async {
    return await _getV('/community/board/list', '');
  }

  /* Id, TimeStamp, User, NickName, Comments, Title, View, UpVote, DownVote */
  static Future<dynamic> getArticleByPage(int board, int page) async {
    return await _getV('/community/board/page', 'board=$board&p=$page');
  }

  /* Body, Etc */
  static Future<dynamic> readArticle(int no) async {
    return await _getV('/community/article/read', 'no=$no');
  }

  /* */
  static Future<dynamic> writeArticle(VioletCommunitySession session, int board,
      String title, String body, String etc) async {
    return await _postV('/community/article/write', {
      'Session': session.session,
      'Board': board,
      'Title': title,
      'Body': body,
      'Etc': etc,
    });
  }

  /* Already Vote, etc */
  static Future<dynamic> voteArticle(
      VioletCommunitySession session, int article, int status) async {
    return await _postV('/community/article/vote', {
      'Session': session.session,
      'Article': article,
      'Status': status,
    });
  }

  /* Edit or Insert */
  static Future<dynamic> editArticle(VioletCommunitySession session, int id,
      int board, String title, String body, String etc) async {
    return await _postV('/community/article/edit', {
      'Session': session.session,
      'Board': board,
      'Title': title,
      'Body': body,
      'Etc': etc,
      'Id': id,
    });
  }

  /* Id, User, NickName, TimeStamp, Body, Parent */
  static Future<dynamic> readComment(int no) async {
    return await _getV('/community/comment/read', 'no=$no');
  }

  /* Edit or Insert */
  static Future<dynamic> writeComment(
      VioletCommunitySession session, int id, String body, String etc,
      [int parent = -1]) async {
    if (parent != -1) {
      return await _postV('/community/comment/write', {
        'Session': session.session,
        'Id': id,
        'Body': body,
        'Parent': parent,
        'Etc': etc,
      });
    }
    return await _postV('/community/comment/write',
        {'Session': session.session, 'Id': id, 'Body': body, 'Etc': etc});
  }

  static Future<String> getUserNickName(String id) async {
    return await _getV('/community/user/info', 'id=$id');
  }
}
