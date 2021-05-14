// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart' as sync;

class LogEvent {
  DateTime dateTime;
  bool isError;
  bool isWarning;
  String title;
  String message;
  String detail;

  LogEvent({
    this.dateTime,
    this.isError = false,
    this.isWarning = false,
    this.title,
    this.message,
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
  static File logFile;
  static List<LogEvent> events = <LogEvent>[];

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
    var message =
        (msg.startsWith('[') ? msg.substring(msg.indexOf(']') + 1) : msg)
            .trim();
    events.add(LogEvent(
      dateTime: DateTime.now().toUtc(),
      isError: false,
      isWarning: false,
      message:
          message.length > 500 ? message.substring(0, 500) + '...' : message,
      detail: message.length > 500 ? message : null,
      title: '[Info] (${DateFormat('kk:mm').format(DateTime.now())}) ' +
          (msg.startsWith('[') ? msg.split('[')[1].split(']')[0] : ''),
    ));
    await log('[Info] ' + msg);
  }

  static Future<void> error(String msg) async {
    var message =
        (msg.startsWith('[') ? msg.substring(msg.indexOf(']') + 1) : msg)
            .trim();
    events.add(LogEvent(
      dateTime: DateTime.now().toUtc(),
      isError: true,
      isWarning: false,
      message:
          message.length > 500 ? message.substring(0, 500) + '...' : message,
      detail: message.length > 500 ? message : null,
      title: '[Error] (${DateFormat('kk:mm').format(DateTime.now())}) ' +
          (msg.startsWith('[') ? msg.split('[')[1].split(']')[0] : ''),
    ));
    await log(
        '[Error] [This message will be sent to the fc-crashlytics] ' + msg);
  }

  static Future<void> warning(String msg) async {
    var message =
        (msg.startsWith('[') ? msg.substring(msg.indexOf(']') + 1) : msg)
            .trim();
    events.add(LogEvent(
      dateTime: DateTime.now().toUtc(),
      isError: false,
      isWarning: true,
      message:
          message.length > 500 ? message.substring(0, 500) + '...' : message,
      detail: message.length > 500 ? message : null,
      title: '[Warning] (${DateFormat('kk:mm').format(DateTime.now())}) ' +
          (msg.startsWith('[') ? msg.split('[')[1].split(']')[0] : ''),
    ));
    await log('[Warning] ' + msg);
  }

  static Future<void> showLogs() async {
    (await logFile.readAsLines()).forEach((element) {
      print(element);
    });
  }

  static Future<void> exportLog() async {
    final ext = await getExternalStorageDirectory();
    final dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    final extpath = '${ext.path}/log-${dateFormat.format(DateTime.now())}.log';
    await logFile.copy(extpath);
  }
}
