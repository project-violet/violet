// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart' as sync;

enum ActLogType {
  none,
  // on/off
  appSuspense,
  appResume,
  // after loading
  pageSwipe,
  serviceButton,
  databaseSync,
  databaseSwitching,
  // search
  openSearch,
  searchWhat,
  searchTypeChange,
  filterOn,
  filterData,
  // bookmark
  articleBookmark,
  artistBookmark,
  openBookmarkGroup,
  moveBookmarkArticle,
  addBookmarkGroup,
  removeBookmarkGroup,
  // settings
  settingChange,
  // article
  openArticleInfo,
  openArtistInfo,
  downloadArticle,
  readArticle,
  // download
  readDownloadedArticle,
  // viewer
  viewStart,
  viewEnd,
  viewTab,
  viewTabReplace,
  viewBookmark,
  viewOpenArticleInfo,
  viewOpenSettingInfo,
  viewThumbnail,
  viewThumbnailJump,
  viewSlide,
  viewThumbBar,
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

  static Future<void> init() async {
    var dir = await getApplicationDocumentsDirectory();
    logFile = File(join(dir.path, 'act-log.txt'));
    if (!await logFile.exists()) {
      await logFile.create();
    }
    session = sha1.convert(utf8.encode(DateTime.now().toString())).toString();
  }

  static Future<void> log(ActLogEvent msg) async {
    print(msg);

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      await lock.synchronized(() async {
        events.add(msg);
        await logFile.writeAsString('$session ${jsonEncode(msg)}\n',
            mode: FileMode.append);
      });
    }
  }

  static Future<void> exportLog() async {
    final ext = await getExternalStorageDirectory();
    final extpath = '${ext!.path}/act-log.txt';
    await logFile.copy(extpath);
  }
}
