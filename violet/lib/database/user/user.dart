// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:violet/database/database.dart';

class CommonUserDatabase extends DataBaseManager {
  static Lock instanceLock = Lock();
  static DataBaseManager? _instance;

  static Future<DataBaseManager> getInstance() async {
    await instanceLock.synchronized(() async {
      if (_instance == null) {
        var dir = await getApplicationDocumentsDirectory();
        _instance = DataBaseManager.create('${dir.path}/user.db');
        await _instance!.open();
      }
    });
    return _instance!;
  }
}
