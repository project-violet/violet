// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/network/wrapper.dart' as http;

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
