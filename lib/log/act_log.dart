// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart' as sync;
import 'package:violet/settings/path.dart';

enum ActLogType {
  none,
  // signal
  signal,
  // on/off
  appStart,
  appSuspense,
  appResume,
  appStop,
  // // after loading
  // pageSwipe,
  // serviceButton,
  // databaseSync,
  // databaseSwitching,
  // // search
  // openSearch,
  // searchWhat,
  // searchTypeChange,
  // filterOn,
  // filterData,
  // // bookmark
  // articleBookmark,
  // artistBookmark,
  // openBookmarkGroup,
  // moveBookmarkArticle,
  // addBookmarkGroup,
  // removeBookmarkGroup,
  // // settings
  // settingChange,
  // // article
  // openArticleInfo,
  // openArtistInfo,
  // downloadArticle,
  // readArticle,
  // // download
  // readDownloadedArticle,
  // // viewer
  // viewStart,
  // viewEnd,
  // viewTab,
  // viewTabReplace,
  // viewBookmark,
  // viewOpenArticleInfo,
  // viewOpenSettingInfo,
  // viewThumbnail,
  // viewThumbnailJump,
  // viewSlide,
  // viewThumbBar,
}

class ActLogEvent {
  DateTime? dateTime;
  String? detail;
  ActLogType type;

  ActLogEvent({
    this.dateTime,
    this.detail,
    required this.type,
  }) {
    dateTime ??= DateTime.now();
  }

  toJson() {
    return jsonEncode({
      'dt': dateTime.toString(),
      'type': type.toString(),
      'detail': detail,
    });
  }

  static ActLogEvent fromJson(String json) {
    final obj = jsonDecode(json);
    return ActLogEvent(
      type: ActLogType.values.byName((obj['type'] as String).split('.')[1]),
      dateTime: DateTime.parse(obj['dt']),
      detail: obj['detail'],
    );
  }
}

// this data is stored only on local storage
// for user data statistics
class ActLogger {
  // Since isolates handle all asynchronous operations linearly,
  // there is no need for mutual exclusion.
  static sync.Lock lock = sync.Lock();
  static late File logFile;

  /// this session is refreshed every app restarting.
  static late String session;
  static List<ActLogEvent> events = <ActLogEvent>[];

  static Timer? signalTimer;

  static Future<void> init() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      logFile = File('act-log.txt');
    } else {
      final dir = await DefaultPathProvider.getDocumentsDirectory();
      logFile = File(join(dir, 'act-log.txt'));
    }

    if (!await logFile.exists()) {
      await logFile.create();
    }

    session = sha1.convert(utf8.encode(DateTime.now().toString())).toString();
    await log(ActLogEvent(type: ActLogType.appStart));

    signalTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      log(ActLogEvent(type: ActLogType.signal));
    });
  }

  static Future<void> log(ActLogEvent msg) async {
    print('$session ${msg.toJson()}');

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      await lock.synchronized(() async {
        events.add(msg);
        await logFile.writeAsString('$session ${msg.toJson()}\n',
            mode: FileMode.append);
      });
    }
  }

  static Future<void> exportLog() async {
    final ext = await DefaultPathProvider.getExportDirectory();
    final extpath = '${ext}/act-log.txt';
    await logFile.copy(extpath);
  }
}
