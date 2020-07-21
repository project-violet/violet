// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:synchronized/synchronized.dart';
import 'package:violet/database/user/user.dart';

class DownloadItemModel {
  Map<String, dynamic> result;
  DownloadItemModel({this.result});

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
  int state() => result['State'];
  String path() => result['Path']; // directory
  String files() => result['Files']; // files path
  String info() => result['Info'];
  String dateTime() => result['DateTime'];
  String extractor() => result['Extractor'];
  String url() => result['URL'];
  String errorMsg() => result['ErrorMsg'];
  String thumbnail() => result['Thumbnail']; // file path
  String thumbnailHeader() => result['ThumbnailHeader'];

  bool download = false;

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('DownloadItem', result, 'Id=?', [id()]);
  }
}

class Download {
  static Download _instance;
  static Lock lock = Lock();
  static Future<Download> getInstance() async {
    await lock.synchronized(() async {
      if (_instance == null) {
        var db = await CommonUserDatabase.getInstance();
        var ee = await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='DownloadItem';");
        if (ee == null || ee.length == 0 || ee[0].length == 0) {
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
          } catch (e) {}
        }
        _instance = new Download();
      }
    });
    return _instance;
  }

  Future<List<DownloadItemModel>> getDownloadItems() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM DownloadItem'))
        .map((x) => DownloadItemModel(result: x))
        .toList()
        .reversed
        .toList();
  }

  Future<DownloadItemModel> createNew(String url) async {
    var rr = {'URL': url, 'State': 1, 'DateTime': DateTime.now().toString()};
    var db = await CommonUserDatabase.getInstance();
    await db.insert('DownloadItem', rr);
    return DownloadItemModel(result: rr);
  }

  Future<void> clear() async {
    var db = await CommonUserDatabase.getInstance();
    await db.delete('DownloadItem', 'Id=?', [1]);
    await db.delete('DownloadItem', 'Id=?', [0]);
  }
}
