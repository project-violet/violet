// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:connectivity/connectivity.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/version/update_sync.dart';

class UpdateManager {
  static Future<void> updateCheck(BuildContext context) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) return;

    await UpdateSyncManager.checkUpdateSync();

    // Update is not available for iOS.
    if (!Platform.isIOS) {}
  }
}
