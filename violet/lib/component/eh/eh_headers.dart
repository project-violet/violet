// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:http/http.dart' as http;

class EHSession {
  // ??
  static List<String> cookies = [];

  String cookie;

  static EHSession tryLogin(String id, String pass) {
    return null;
  }

  static Future<String> requestString(String url) async {
    return (await http.get(url, headers: {"Cookie": cookies[0]})).body;
  }
}
