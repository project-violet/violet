// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/network/wrapper.dart' as http;

class EHSession {
  static EHSession? tryLogin(String id, String pass) {
    return null;
  }

  static Future<String> requestString(String url) async {
    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies');
    return (await http.get(url, headers: {'Cookie': cookie ?? ''})).body;
  }

  static Future<String?> requestRedirect(String url) async {
    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies');
    Request req = Request('Get', Uri.parse(url))..followRedirects = false;
    req.headers['Cookie'] = cookie ?? '';
    Client baseClient = Client();
    StreamedResponse response = await baseClient.send(req);
    return response.headers['location'];
  }

  static Future<String> postComment(String url, String content) async {
    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies');
    return (await http.post(url,
            headers: {'Cookie': cookie ?? ''},
            body: 'commenttext_new=${Uri.encodeFull(content)}'))
        .body;
  }
}
