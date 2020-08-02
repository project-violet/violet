// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EHSession {
  static EHSession tryLogin(String id, String pass) {
    return null;
  }

  static Future<String> requestString(String url) async {
    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies');
    return (await http.get(url, headers: {"Cookie": cookie})).body;
  }
}
