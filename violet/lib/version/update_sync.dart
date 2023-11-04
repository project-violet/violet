// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;

class UpdateSyncManager {
  static const String updateInfoURL =
      'https://raw.githubusercontent.com/project-violet/violet-app/master/version.json';

  static bool enableSensitiveUpdate = true;

  // Current version
  static const int majorVersion = 1;
  static const int minorVersion = 29;
  static const int patchVersion = 0;

  static String get currentVersion =>
      '$majorVersion.$minorVersion.$patchVersion';

  static bool updateRequire = false;
  static String latestVersion = '';
  static String version = '';
  static String updateMessage = '';
  static String updateUrl = '';

  static bool _checkIsNewVersion(List<int> ver) {
    //
    // Check Major Version Number
    //
    if (majorVersion < ver[0]) return true;

    //
    //  Check Minor Version Number
    //
    if (majorVersion == ver[0] && minorVersion < ver[1]) return true;

    //
    //  Check Patch Version Number
    //
    if (majorVersion == ver[0] &&
        minorVersion == ver[1] &&
        patchVersion < ver[2] &&
        enableSensitiveUpdate) return true;
    return false;
  }

  static Future<void> checkUpdateSync() async {
    try {
      var infoJson = await http.get(updateInfoURL);

      var info = jsonDecode(infoJson.body).cast<String, dynamic>();

      var ver = (info['version'] as String)
          .split('.')
          .map((e) => int.parse(e))
          .toList();
      if (_checkIsNewVersion(ver)) {
        updateRequire = true;
        version = info['version'] as String;
        updateMessage = info['message'] as String;
        updateUrl = info['download_link'] as String;
        print(info);
      }
      latestVersion = info['version'] as String;
    } catch (e, st) {
      Logger.error('[Update-check] E: $e\n'
          '$st');
    }
  }
}
