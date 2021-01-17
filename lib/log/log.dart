// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart' as sync;

class Logger {
  // Since isolates handle all asynchronous operations linearly,
  // there is no need for mutual exclusion.
  static sync.Lock lock = sync.Lock();
  static File logFile;

  static Future<void> init() async {
    var dir = await getApplicationDocumentsDirectory();
    logFile = File(join(dir.path, 'log.txt'));
    if (!await logFile.exists()) {
      await logFile.create();
    }
  }

  static Future<void> log(String msg) async {
    print(msg);
    await lock.synchronized(() async {
      await logFile.writeAsString('[${DateTime.now().toUtc()}] ' + msg + '\n',
          mode: FileMode.append);
    });
  }

  static Future<void> info(String msg) async {
    await log('[Info] ' + msg);
  }

  static Future<void> error(String msg) async {
    await log(
        '[Error] [This message will be sent to the fc-crashlytics] ' + msg);
  }

  static Future<void> warning(String msg) async {
    await log('[Warning] ' + msg);
  }

  static Future<void> showLogs() async {
    (await logFile.readAsLines()).forEach((element) {
      print(element);
    });
  }
}
