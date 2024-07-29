// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:synchronized/synchronized.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/user.dart';
import 'package:violet/log/log.dart';

class DownloadItemModel {
  Map<String, dynamic> result;
  DownloadItemModel({required this.result});

  int id() => result['Id'];

  // 0: Complete
  // 1: Pending
  // 2: Extracting
  // 3: Downloading
  // 4: Post Processing
  // 5: Fail
  // 6: Stop
  // 7: Error-Unknown
  // 8: Error-Not Support
  // 9: Error-Login
  // 10: Error
  // 11: Nothing to download
  int state() => result['State'];
  String? path() => result['Path']; // directory
  String? files() => result['Files']; // files path
  String? info() => result['Info'];
  String? dateTime() => result['DateTime'];
  String? extractor() => result['Extractor'];
  String url() => result['URL'];
  String? errorMsg() => result['ErrorMsg'];
  String? thumbnail() => result['Thumbnail']; // file path
  String? thumbnailHeader() => result['ThumbnailHeader'];

  QueryResult? queryResult;

  bool download = false;

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('DownloadItem', result, 'Id=?', [id()]);
  }

  Future<void> test() async {
    var db = await CommonUserDatabase.getInstance();
    await db.query('SELECT * FROM DownloadItem WHERE Id=${id()}');
  }

  Future<void> delete() async {
    var db = await CommonUserDatabase.getInstance();
    await db.delete('DownloadItem', 'Id=?', [id()]);
  }

  List<String> rawFiles() {
    if (files() == null || files() == '') return [];
    return (jsonDecode(files()!) as List<dynamic>)
        .map((e) => e as String)
        .toList();
  }

  List<String> filesWithoutThumbnail() {
    var rfiles = rawFiles();
    rfiles.removeWhere(
        (element) => element.split('/').last.startsWith('thumbnail'));
    return rfiles;
  }

  String? tryThumbnailFile() {
    if (files() != null) {
      var rfiles = (jsonDecode(files()!) as List<dynamic>)
          .map((e) => e as String)
          .toList();
      if (rfiles
          .where((e) => e.split('/').last.startsWith('thumbnail'))
          .isNotEmpty) {
        return rfiles.firstWhere(
            (element) => element.split('/').last.startsWith('thumbnail'));
      }
    }
    return null;
  }
}

class Download {
  static Download? _instance;
  static Lock lock = Lock();
  static Future<Download> getInstance() async {
    await lock.synchronized(() async {
      if (_instance == null) {
        final db = await CommonUserDatabase.getInstance();
        final rows = await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='DownloadItem';");
        if (rows.isEmpty || rows[0].isEmpty) {
          try {
            await db.execute('''CREATE TABLE DownloadItem (
              Id integer primary key autoincrement, 
              State integer,
              Path text,
              Files text,
              Info text,
              DateTime text,
              Extractor text,
              URL text,
              ErrorMsg text,
              Thumbnail text,
              ThumbnailHeader text
              );
              ''');
          } catch (e, st) {
            Logger.error('[Download-Instance] E: $e\n'
                '$st');
          }
        }
        _instance = Download();
        await _instance!.init();
      }
    });
    return _instance!;
  }

  HashSet<int> _downloadedChecker = HashSet<int>();
  Map<int, DownloadItemModel> _downloadedItems = <int, DownloadItemModel>{};
  Future<void> init() async {
    var items = await getDownloadItems();
    for (var item in items) {
      int? no = int.tryParse(item.url());
      if (no != null && item.state() == 0) {
        _downloadedChecker.add(no);
        _downloadedItems[no] = item;
      }
    }
  }

  Future<void> refresh() async {
    _downloadedChecker = HashSet<int>();
    _downloadedItems = <int, DownloadItemModel>{};
    await init();
  }

  bool isDownloadedArticle(int id, bool checkFileEixsts) {
    if (!checkFileEixsts) {
      return _downloadedChecker.contains(id);
    }

    return _isDownloadedFileExists(id);
  }

  final Map<int, bool> _isDownloadedFileExistsCache = <int, bool>{};
  bool _isDownloadedFileExists(int id) {
    if (_isDownloadedFileExistsCache.containsKey(id)) {
      return _isDownloadedFileExistsCache[id]!;
    }

    final item = _downloadedItems[id]!;

    // _isDownloadedFileExists 메서드가 호출되었다는 것은 state가
    // extraction을 마치고 다운로드가 시작되기 직전 후라는 것임
    final files = jsonDecode(item.files()!) as List<dynamic>;

    final exists = File(files[0] as String).existsSync();
    _isDownloadedFileExistsCache[id] = exists;
    return exists;
  }

  void appendDownloaded(int id, DownloadItemModel item) {
    _downloadedChecker.add(id);
    _downloadedItems[id] = item;
  }

  DownloadItemModel? getDownloadedArticle(int id) => _downloadedItems[id];

  Future<List<DownloadItemModel>> getDownloadItems() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM DownloadItem'))
        .map((x) => DownloadItemModel(result: x))
        .toList();
  }

  Future<DownloadItemModel> createNew(String url) async {
    var rr = {'URL': url, 'State': 1, 'DateTime': DateTime.now().toString()};
    var db = await CommonUserDatabase.getInstance();
    await db.insert('DownloadItem', rr);
    var ll = (await db
        .query('SELECT * FROM DownloadItem ORDER BY Id DESC LIMIT 1'))[0];
    return DownloadItemModel(result: ll);
  }

  Future<void> clear() async {
    var db = await CommonUserDatabase.getInstance();
    await db.delete('DownloadItem', 'Id=?', [1]);
    await db.delete('DownloadItem', 'Id=?', [0]);
  }
}
