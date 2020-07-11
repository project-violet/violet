// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:convert';

import 'package:http/http.dart' as http;

class UpdateSyncManager {
  static const String updateInfoURL =
      "https://github.com/project-violet/violet-app/blob/master/version.json";

  static bool enableSensitiveUpdate = false;

  // Current version
  static const int majorVersion = 0;
  static const int minorVersion = 7;
  static const int patchVersion = 0;

  static bool updateRequire = false;
  static String version = "";
  static String updateMessage = "";

  static bool syncRequire = false;

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
    }
  }
}
