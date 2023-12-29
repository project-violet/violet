// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart' as sync;

class LogEvent {
  DateTime? dateTime;
  bool isError;
  bool isWarning;
  String title;
  String message;
  String? detail;

  LogEvent({
    this.dateTime,
    this.isError = false,
    this.isWarning = false,
    required this.title,
    required this.message,
    this.detail,
  }) {
    dateTime ??= DateTime.now();
  }

  LogEvent copy() => LogEvent(
        dateTime: dateTime,
        isError: isError,
        isWarning: isWarning,
        title: title,
        message: message,
        detail: detail,
      );
}

class Logger {
  // Since isolates handle all asynchronous operations linearly,
  // there is no need for mutual exclusion.
  static sync.Lock lock = sync.Lock();
  static late File logFile;
  static List<LogEvent> events = <LogEvent>[];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      logFile = File('log.txt');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      logFile = File(join(dir.path, 'log.txt'));
    }

    if(prefs.getBool('deleteoldlogatstart') == true){
      if(await logFile.exists()){
        print('Deleting old log');
        await logFile.delete();
      }
    }

    if (!await logFile.exists()) {
      await logFile.create();
    }
  }

  static Future<void> log(String msg) async {
    print(msg);

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      await lock.synchronized(() async {
        await logFile.writeAsString('[${DateTime.now().toUtc()}] $msg\n',
            mode: FileMode.append);
      });
    }
  }

  static Future<void> _logMessage(
    String msg,
    String prefix,
    bool isError,
    bool isWarning,
  ) async {
    var message =
        (msg.startsWith('[') ? msg.substring(msg.indexOf(']') + 1) : msg)
            .trim();
    events.add(LogEvent(
      dateTime: DateTime.now().toUtc(),
      isError: isError,
      isWarning: isWarning,
      message:
          message.length > 500 ? '${message.substring(0, 500)}...' : message,
      detail: message.length > 500 ? message : null,
      title:
          '[$prefix] (${DateFormat('kk:mm').format(DateTime.now())}) ${msg.startsWith('[') ? msg.split('[')[1].split(']')[0] : ''}',
    ));
    await log('[$prefix] $msg');
  }

  static Future<void> info(String msg) async {
    await _logMessage(msg, 'Info', false, false);
  }

  static Future<void> error(String msg) async {
    await _logMessage(msg, 'Error', true, false);
  }

  static Future<void> warning(String msg) async {
    await _logMessage(msg, 'Warning', false, true);
  }

  static Future<void> showLogs() async {
    for (var element in (await logFile.readAsLines())) {
      print(element);
    }
  }

  static Future<void> exportLog() async {
    final ext = Platform.isIOS
        ? await getApplicationSupportDirectory()
        : await getExternalStorageDirectory();
    // final dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    // final extpath = '${ext.path}/log-${dateFormat.format(DateTime.now())}.log';
    final extpath = '${ext!.path}/log.txt';
    await logFile.copy(extpath);
  }
}
