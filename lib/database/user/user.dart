// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:violet/database/database.dart';
import 'package:violet/settings/path.dart';

class CommonUserDatabase extends DataBaseManager {
  static DataBaseManager? _instance;

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      var dir = await DefaultPathProvider.getDocumentsDirectory();
      _instance = DataBaseManager.create('${dir}/user.db');
      await _instance!.open();
    }
    return _instance!;
  }
}
