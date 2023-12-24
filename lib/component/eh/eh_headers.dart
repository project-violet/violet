// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/curl.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/settings/settings.dart';

class EHSession {
  static EHSession? tryLogin(String id, String pass) {
    return null;
  }

  static Future<String> requestString(String url) async {
    final prefs = await MultiPreferences.getInstance();
    var cookie = await prefs.getString('eh_cookies');
    return (await http.get(url, headers: {'Cookie': cookie ?? ''})).body;
  }

  static Future<String?> requestRedirect(String url) async {
    final prefs = await MultiPreferences.getInstance();
    var _cookie = await prefs.getString('eh_cookies');
    if(_cookie == null){
      _cookie = '';
    }
    var cookie = _cookie;
    if(Platform.isLinux){
      try {
        final res = await StaticCurl.getHttp3Request(url,{ "Cookie": cookie },false);
        return res.headers['location'];
      } catch(e,st){
        Logger.warning('[getHttp3Request]$e\n'
            '$st');
      }
    }
    Request req = Request('Get', Uri.parse(url))..followRedirects = false;
    req.headers['Cookie'] = cookie ?? '';
    Client baseClient = Client();
    StreamedResponse response = await baseClient.send(req);
    return response.headers['location'];
  }

  static Future<String> postComment(String url, String content) async {
    final prefs = await MultiPreferences.getInstance();
    var cookie = await prefs.getString('eh_cookies');
    return (await http.post(url,
            headers: {'Cookie': cookie ?? ''},
            body: 'commenttext_new=${Uri.encodeFull(content)}'))
        .body;
  }
}
