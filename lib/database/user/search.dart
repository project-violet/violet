// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:synchronized/synchronized.dart';
import 'package:violet/database/user/user.dart';
import 'package:violet/log/log.dart';

////////////////////////////////////////////////////////////////////////
///
///         Search Log
///
////////////////////////////////////////////////////////////////////////

class SearchLog {
  Map<String, dynamic> result;
  SearchLog({required this.result});

  int id() => result['Id'];
  String? searchWhat() => result['SearchWhat'];
  String datetime() => result['DateTime'];
}

class SearchLogDatabase {
  static SearchLogDatabase? _instance;
  static Lock lock = Lock();
  static Future<SearchLogDatabase> getInstance() async {
    await lock.synchronized(() async {
      if (_instance == null) {
        final db = await CommonUserDatabase.getInstance();
        final rows = await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='SearchLog';");
        if (rows.isEmpty || rows[0].isEmpty) {
          try {
            await db.execute('''CREATE TABLE SearchLog (
              Id integer primary key autoincrement, 
              SearchWhat text, 
              DateTime text);
              ''');
          } catch (e, st) {
            Logger.error('[Record-Instance] E: $e\n'
                '$st');
          }
        }
        _instance = SearchLogDatabase();
      }
    });
    return _instance!;
  }

  Future<List<SearchLog>> getSearchLog() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM SearchLog'))
        .map((x) => SearchLog(result: x))
        .toList()
        .reversed
        .toList();
  }

  Future<void> insertSearchLog(String? searchWhat, [DateTime? datetime]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('SearchLog', {
      'SearchWhat': searchWhat,
      'DateTime': datetime.toString(),
    });
  }
}
