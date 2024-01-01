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
  static User? _instance;
  static Lock lock = Lock();
  static Future<User> getInstance() async {
    await lock.synchronized(() async {
      if (_instance == null) {
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
    });
    return _instance!;
  }

  Future<List<ArticleReadLog>> getUserLog() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM ArticleReadLog'))
        .map((x) => ArticleReadLog(result: x))
        .toList()
        .reversed
        .toList();
  }

  Future<void> insertUserLog(int article, int type,
      [DateTime? datetime]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('ArticleReadLog', {
      'Article': article.toString(),
      'Type': type,
      'DateTimeStart': datetime.toString(),
    });
  }

  Future<void> updateUserLog(int article, int lastpage, [DateTime? end]) async {
    end ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    var rr = (await getUserLog())[0];
    var xx = Map<String, dynamic>.from(rr.result);
    xx['DateTimeEnd'] = end.toString();
    xx['LastPage'] = lastpage;
    await db.update('ArticleReadLog', xx, 'Id=?', [rr.id()]);
  }
}
