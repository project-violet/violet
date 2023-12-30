// This source code is a part of Project Violet.
// Copyright (C) 2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/server/v1/violet.dart';
import 'package:violet/server/wsalt.dart';

class VioletCommunitySession {
  static VioletCommunitySession? lastSession;
  final String session;
  final String id;

  VioletCommunitySession(this.session, this.id);

  static Future<VioletCommunitySession?> signIn(String id, String pw) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.post('${VioletServer.api}/community/sign/in',
          headers: {
            'v-token': vToken.toString(),
            'v-valid': vValid,
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'Id': id, 'Password': pw}));
      var bb = jsonDecode(res.body);
      if (bb['msg'] == 'success') {
        return lastSession = VioletCommunitySession(bb['session'], id);
      }
    } catch (e, st) {
      Logger.error('[API-signin] E: $e\n'
          '$st');
    }
    return null;
  }

  static Future<dynamic> checkId(String id) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res =
          await http.post('${VioletServer.api}/community/sign/util/checkid',
              headers: {
                'v-token': vToken.toString(),
                'v-valid': vValid,
                'Content-Type': 'application/json'
              },
              body: jsonEncode({'Id': id}));
      var bb = jsonDecode(res.body);
      return bb['msg'];
    } catch (e, st) {
      Logger.error('[API-checkid] E: $e\n'
          '$st');
    }
    return null;
  }

  static Future<dynamic> checkUserAppId(String userAppId) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.post(
          '${VioletServer.api}/community/sign/util/checkuserappid',
          headers: {
            'v-token': vToken.toString(),
            'v-valid': vValid,
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'UserAppId': userAppId}));
      var bb = jsonDecode(res.body);
      return bb['msg'];
    } catch (e, st) {
      Logger.error('[API-checkuserappid] E: $e\n'
          '$st');
    }
    return null;
  }

  static Future<dynamic> checkNickName(String nickName) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.post(
          '${VioletServer.api}/community/sign/util/checknickname',
          headers: {
            'v-token': vToken.toString(),
            'v-valid': vValid,
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'NickName': nickName}));
      var bb = jsonDecode(res.body);
      return bb['msg'];
    } catch (e, st) {
      Logger.error('[API-checknickname] E: $e\n'
          '$st');
    }
    return null;
  }

  static Future<dynamic> signUp(
      String id, String password, String userAppId, String nickName) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.post('${VioletServer.api}/community/sign/up',
          headers: {
            'v-token': vToken.toString(),
            'v-valid': vValid,
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'Id': id,
            'Password': password,
            'UserAppId': userAppId,
            'NickName': nickName,
            'Etc': 'Violet App $vToken $vValid',
          }));
      var bb = jsonDecode(res.body);
      return bb['msg'];
    } catch (e, st) {
      Logger.error('[API-signup] E: $e\n'
          '$st');
    }
    return null;
  }

  static Future<dynamic> getUserInfo(String id) async {
    var vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    var vValid = getValid(vToken.toString());

    try {
      var res = await http.get(
        '${VioletServer.api}/community/user/info?id=$id',
        headers: {
          'v-token': vToken.toString(),
          'v-valid': vValid,
          'Content-Type': 'application/json'
        },
      );
      var bb = jsonDecode(res.body);
      return bb['result'];
    } catch (e, st) {
      Logger.error('[API-userinfo] E: $e\n'
          '$st');
    }
    return null;
  }
}
