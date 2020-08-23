// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';

class UpdateSyncManager {
  static const String updateInfoURL =
      "https://raw.githubusercontent.com/project-violet/violet-app/master/version.json";

  static bool enableSensitiveUpdate = true;

  // Current version
  static const int majorVersion = 0;
  static const int minorVersion = 9;
  static const int patchVersion = 2;

  static bool updateRequire = false;
  static String version = "";
  static String updateMessage = "";
  static String updateUrl = "";

  static bool syncRequire = false;

  static Map<String, Tuple2<DateTime, String>> rawlangDB;

  static Future<void> checkUpdateSync() async {
    var infoJson = await http.get(updateInfoURL);
    var info = jsonDecode(infoJson.body).cast<String, dynamic>();

    var ver = (info["version"] as String)
        .split('.')
        .map((e) => int.parse(e))
        .toList();
    if (majorVersion < ver[0] ||
        (majorVersion == ver[0] && minorVersion < ver[1]) ||
        (majorVersion == ver[0] &&
            minorVersion == ver[1] &&
            patchVersion < ver[2] &&
            enableSensitiveUpdate)) {
      updateRequire = true;
      version = info["version"] as String;
      updateMessage = info["message"] as String;
      updateUrl = info["download_link"] as String;
      print(info);
    }

    var rawdb = (info["rawdb2"] as List<dynamic>);
    rawlangDB = Map<String, Tuple2<DateTime, String>>();
    rawdb.forEach((element) {
      var lang = element['language'];
      switch (lang) {
        case 'all':
          lang = 'global';
          break;
        case 'korean':
          lang = 'ko';
          break;
        case 'chinese':
          lang = 'zh';
          break;
        case 'japanese':
          lang = 'ja';
          break;
        case 'english':
          lang = 'en';
          break;
      }
      rawlangDB[lang] = Tuple2<DateTime, String>(
          DateTime.parse(element['date']), element['chunk']);
    });
  }
}
