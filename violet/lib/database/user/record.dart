// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:synchronized/synchronized.dart';
import 'package:violet/database/user/user.dart';
import 'package:violet/log/log.dart';

////////////////////////////////////////////////////////////////////////
///
///         User Record
///
////////////////////////////////////////////////////////////////////////

// // Trivial Log
// class UserLog {
//   Map<String, dynamic> result;
//   UserLog({this.result});

//   int id() => result['Id'];
//   String message() => result['Message'];
//   String datetime() => result['DateTime'];
//   String type() => result['Type'];
// }

// // Specific Log
// class UserActivity {
//   Map<String, dynamic> result;
//   UserActivity({this.result});

//   int id() => result['Id'];
//   String message() => result['Message'];
//   String datetime() => result['DateTime'];

//   // 1: Startup Application
//   // 2: Close Application
//   // 3: Suspend Application
//   // 100: Search
//   // 101: Info View
//   // 120: Viewer Open
//   // 121: Viewer Close
//   int type() => result['Type'];
// }

class ArticleReadLog {
  Map<String, dynamic> result;
  ArticleReadLog({required this.result});

  int id() => result['Id'];
  String articleId() => result['Article'];
  String datetimeStart() => result['DateTimeStart'];
  String? datetimeEnd() => result['DateTimeEnd'];
  int? lastPage() => result['LastPage'];
  // 0: Read on search, 1: Read on bookmark
  int type() => result['Type'];
}

class User {
  static late final User _instance;
  static Future<void> load() async {
    var db = await CommonUserDatabase.getInstance();
    var ee = await db.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='ArticleReadLog';");
    if (ee.isEmpty || ee[0].isEmpty) {
      try {
        await db.execute('''CREATE TABLE ArticleReadLog (
              Id integer primary key autoincrement, 
              Article text, 
              DateTimeStart text,
              DateTimeEnd text,
              LastPage integer,
              Type integer);
              ''');
      } catch (e, st) {
        Logger.error('[Record-Instance] E: $e\n'
            '$st');
      }
    }
    _instance = User();
  }

  static Future<User> getInstance() async {
    return _instance;
  }

  List<ArticleReadLog>? cachedReadLog;
  Lock userLogLock = Lock();
  Future<List<ArticleReadLog>> getUserLog() async {
    await userLogLock.synchronized(() async {
      cachedReadLog ??= (await (await CommonUserDatabase.getInstance())
              .query('SELECT * FROM ArticleReadLog ORDER BY Id DESC'))
          // TODO: 왜 Article에 null이 들어가는지 확인 필요
          .where((e) => e['Article'] != null)
          .map((x) => ArticleReadLog(result: x))
          .toList();
    });
    return cachedReadLog!;
  }

  Future<void> insertUserLog(int article, int type,
      [DateTime? datetime]) async {
    datetime ??= DateTime.now();
    final db = await CommonUserDatabase.getInstance();
    final log = ArticleReadLog(result: {
      'Article': article.toString(),
      'Type': type,
      'DateTimeStart': datetime.toString(),
    });
    final id = await db.insert('ArticleReadLog', log.result);
    log.result['Id'] = id;
    cachedReadLog!.insert(0, log);
  }

  Future<void> updateUserLog(int article, int lastpage, [DateTime? end]) async {
    end ??= DateTime.now();
    final db = await CommonUserDatabase.getInstance();
    var latestLog = cachedReadLog!.first.result;
    latestLog['DateTimeEnd'] = end.toString();
    latestLog['LastPage'] = lastpage;
    await db.update('ArticleReadLog', latestLog, 'Id=?', [latestLog['Id']]);
  }
}
