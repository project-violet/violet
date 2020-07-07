// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:violet/database.dart';

class CommonUserDatabase extends DataBaseManager {
  static DataBaseManager _instance;

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      var dir = await getApplicationDocumentsDirectory();
      _instance = DataBaseManager.create('${dir.path}/user.db');
    }
    return _instance;
  }
}

////////////////////////////////////////////////////////////////////////
///
///         Bookmark
///
////////////////////////////////////////////////////////////////////////

class BookmarkGroup {
  Map<String, dynamic> result;
  BookmarkGroup({this.result});

  int id() => result['Id'];
  String name() => result['Name'];
  String datetime() => result['DateTime'];
  String description() => result['Description'];
  int color() => result['DateTime'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkGroup', result, 'Id=?', [id()]);
  }
}

class BookmarkArticle {
  Map<String, dynamic> result;
  BookmarkArticle({this.result});

  int id() => result['Id'];
  String article() => result['Article'];
  String datetime() => result['DateTime'];
  int group() => result['GroupId'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkArticle', result, 'Id=?', [id()]);
  }
}

class BookmarkArtist {
  Map<String, dynamic> result;
  BookmarkArtist({this.result});

  int id() => result['Id'];
  String artist() => result['Artist'];
  int isGroup() => result['IsGroup'];
  String datetime() => result['DateTime'];
  int group() => result['GroupId'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkArtist', result, 'Id=?', [id()]);
  }
}

class Bookmark {
  static Bookmark _instance;
  static Lock lock = Lock();
  static Future<Bookmark> getInstance() async {
    await lock.synchronized(() async {
      if (_instance == null) {
        var db = await CommonUserDatabase.getInstance();
        var ee = await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='BookmarkGroup';");
        if (ee == null || ee.length == 0 || ee[0].length == 0) {
          try {
            await db.execute(
                'CREATE TABLE BookmarkGroup (Id integer primary key autoincrement, Name text, DateTime text, Description text, Color integer, Gorder integer)');
            await db.execute('''CREATE TABLE BookmarkArticle (
              Id integer primary key autoincrement, 
              Article text, 
              DateTime text,
              GroupId integer,
              FOREIGN KEY(GroupId) REFERENCES BookmarkGroup(Id));
              ''');
            await db.execute('''CREATE TABLE BookmarkArtist (
              Id integer primary key autoincrement, 
              Artist text, 
              IsGroup integer,
              DateTime text, 
              GroupId integer,
              FOREIGN KEY(GroupId) REFERENCES BookmarkGroup(Id));
              ''');

            // Insert default bookmark group.
            await db.insert('BookmarkGroup', {
              'Name': 'violet_default', // 미분류
              'Description': 'Unclassified bookmarks.',
              'DateTime': DateTime.now().toString(),
              'Color': Colors.grey.value,
              'Gorder': 1,
            });
          } catch (e) {}
        }
        _instance = new Bookmark();
      }
    });
    return _instance;
  }

  Future<void> insertArticle(String article,
      [DateTime datetime, int group = 1]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkArticle', {
      'Article': article,
      'DateTime': datetime.toString(),
      'GroupId': group,
    });
  }

  Future<void> insertArtist(String artist, int isgroup,
      [DateTime datetime, int group = 1]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkArtist', {
      'Artist': artist,
      'IsGroup': isgroup,
      'DateTime': datetime.toString(),
      'GroupId': group,
    });
  }

  Future<void> createGroup(
      String name, String description, Color color, int order,
      [DateTime datetime]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkGroup', {
      'Name': name,
      'Description': description,
      'DateTime': DateTime.now().toString(),
      'Color': color.value,
      'Gorder': order
    });
  }

  Future<void> deleteGroup(BookmarkGroup group) async {
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkGroup', 'Id=?', [group.id().toString()]);
    //
  }

  Future<List<BookmarkGroup>> getGroup() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkGroup'))
        .map((x) => BookmarkGroup(result: x))
        .toList();
  }

  Future<List<BookmarkArticle>> getArticle() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkArticle'))
        .map((x) => BookmarkArticle(result: x))
        .toList();
  }

  Future<List<BookmarkArtist>> getArtist() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkArtist'))
        .map((x) => BookmarkArtist(result: x))
        .toList();
  }

  Future<void> modfiyGroup(BookmarkGroup group) async {
    await lock.synchronized(() async {
      await (await CommonUserDatabase.getInstance())
          .update('BookmarkGroup', group.result, 'Id=?', [group.id()]);
    });
  }

  HashSet<int> bookmarkSet;
  Future<bool> isBookmark(int id) async {
    await lock.synchronized(() async {
      if (bookmarkSet == null) {
        var article = await getArticle();
        bookmarkSet = HashSet<int>();
        article.forEach((element) {
          bookmarkSet.add(int.parse(element.article()));
        });
      }
    });

    return bookmarkSet.contains(id);
  }

  Future<void> bookmark(int id) async {
    if (await isBookmark(id)) return;
    bookmarkSet.add(id);
    await insertArticle(id.toString());
  }

  Future<void> unbookmark(int id) async {
    if (!await isBookmark(id)) return;
    var db = await CommonUserDatabase.getInstance();
    db.delete('BookmarkArticle', 'Article=?', [id.toString()]);
    bookmarkSet.remove(id);
  }
}

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
  ArticleReadLog({this.result});

  int id() => result['Id'];
  String articleId() => result['Article'];
  String datetimeStart() => result['DateTimeStart'];
  String datetimeEnd() => result['DateTimeEnd'];
  int lastPage() => result['LastPage'];
  // 0: Read on search, 1: Read on bookmark
  int type() => result['Type'];
}

class User {
  static User _instance;
  static Lock lock = Lock();
  static Future<User> getInstance() async {
    await lock.synchronized(() async {
      if (_instance == null) {
        var db = await CommonUserDatabase.getInstance();
        var ee = await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='ArticleReadLog';");
        if (ee == null || ee.length == 0 || ee[0].length == 0) {
          try {
            await db.execute('''CREATE TABLE ArticleReadLog (
              Id integer primary key autoincrement, 
              Article text, 
              DateTimeStart text,
              DateTimeEnd text,
              LastPage integer,
              Type integer);
              ''');
          } catch (e) {}
        }
        _instance = new User();
      }
    });
    return _instance;
  }

  Future<List<ArticleReadLog>> getUserLog() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM ArticleReadLog'))
        .map((x) => ArticleReadLog(result: x))
        .toList()
        .reversed
        .toList();
  }

  Future<void> insertUserLog(int article, int type, [DateTime datetime]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('ArticleReadLog', {
      'Article': article.toString(),
      'Type': type,
      'DateTimeStart': datetime.toString(),
    });
  }

  Future<void> updateUserLog(int article, int lastpage, [DateTime end]) async {
    end ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    var rr = (await getUserLog())[0];
    var xx = Map<String, dynamic>.from(rr.result);
    xx['DateTimeEnd'] = end.toString();
    xx['LastPage'] = lastpage;
    await db.update('ArticleReadLog', xx, 'Id=?', [rr.id()]);
  }
}
