// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:synchronized/synchronized.dart';
import 'package:violet/database/user/user.dart';
import 'package:violet/log/log.dart';

////////////////////////////////////////////////////////////////////////
///
///         Bookmark
///
////////////////////////////////////////////////////////////////////////

class BookmarkGroup {
  Map<String, dynamic> result;
  BookmarkGroup({required this.result});

  int id() => result['Id'];
  String name() => result['Name'];
  String datetime() => result['DateTime'];
  String description() => result['Description'];
  int color() => result['DateTime'];
  int gorder() => result['Gorder'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkGroup', result, 'Id=?', [id()]);
  }

  Future<void> swap(BookmarkGroup target) async {
    var db = await CommonUserDatabase.getInstance();
    await db.swap('BookmarkGroup', 'Id', 'Gorder', id(), target.id(), gorder(),
        target.gorder());
    var tid = gorder();

    var xx = Map<String, dynamic>.from(result);
    var yy = Map<String, dynamic>.from(target.result);
    xx['Gorder'] = target.gorder();
    result = xx;
    yy['Gorder'] = tid;
    target.result = yy;
  }
}

class BookmarkArticle {
  Map<String, dynamic> result;
  BookmarkArticle({required this.result});

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
  BookmarkArtist({required this.result});

  int id() => result['Id'];
  String artist() => result['Artist'];
  // 0: artist
  // 1: group
  // 2: uploader
  // 3: series
  // 4: character
  int type() => result['IsGroup']; // backward compatibility
  String datetime() => result['DateTime'];
  int group() => result['GroupId'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkArtist', result, 'Id=?', [id()]);
  }
}

class BookmarkUser {
  Map<String, dynamic> result;
  BookmarkUser({required this.result});

  int id() => result['Id'];
  String user() => result['User'];
  String datetime() => result['DateTime'];
  int group() => result['GroupId'];
  String? title() => result['Title'];
  String? subtitle() => result['Subtitle'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkUser', result, 'Id=?', [id()]);
  }
}

class HistoryUser {
  Map<String, dynamic> result;
  HistoryUser({required this.result});

  int id() => result['Id'];
  String user() => result['User'];
  String datetime() => result['DateTime'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('HistoryUser', result, 'Id=?', [id()]);
  }
}

class BookmarkCropImage {
  Map<String, dynamic> result;
  BookmarkCropImage({required this.result});

  int id() => result['Id'];
  String datetime() => result['DateTime'];
  int article() => result['Article'];
  int page() => result['Page'];
  double aspectRatio() => result['AspectRatio'];
  String area() => result['Area'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkCropImage', result, 'Id=?', [id()]);
  }

  Map<String, dynamic> toJson() => {
        'article': article(),
        'page': page(),
        'aspectRatio': aspectRatio(),
        'area': area(),
      };
}

class Bookmark {
  static late final Bookmark _instance;
  static Future<void> load() async {
    final db = await CommonUserDatabase.getInstance();
    final ee = await db.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='BookmarkGroup';");
    if (ee.isEmpty || ee[0].isEmpty) {
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
      } catch (e, st) {
        Logger.error('[Bookmark Instance] E: $e\n'
            '$st');
      }
    }
    final ex = await db.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='BookmarkUser';");
    if (ex.isEmpty || ex[0].isEmpty) {
      await db.execute('''CREATE TABLE BookmarkUser (
              Id integer primary key autoincrement, 
              User text,
              Title text,
              Subtitle text,
              DateTime text, 
              GroupId integer,
              FOREIGN KEY(GroupId) REFERENCES BookmarkGroup(Id));
              ''');
    }
    final ex2 = await db.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='HistoryUser';");
    if (ex2.isEmpty || ex2[0].isEmpty) {
      await db.execute('''CREATE TABLE HistoryUser (
              Id integer primary key autoincrement, 
              User text,
              DateTime text);
              ''');
    }
    final ex3 = await db.query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='BookmarkCropImage';");
    if (ex3.isEmpty || ex3[0].isEmpty) {
      await db.execute('''CREATE TABLE BookmarkCropImage (
              Id integer primary key autoincrement, 
              Article integer,
              Page integer,
              Area text,
              AspectRatio double,
              DateTime text);
              ''');
    }
    _instance = Bookmark();
  }

  static Future<Bookmark> getInstance() async {
    return _instance;
  }

  Future<void> insertArticle(String article,
      [DateTime? datetime, int group = 1]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkArticle', {
      'Article': article,
      'DateTime': datetime.toString(),
      'GroupId': group,
    });
    bookmarkSet ??= HashSet<int>();
    bookmarkSet!.add(int.parse(article));
  }

  Future<void> insertArtist(String artist, int isgroup,
      [DateTime? datetime, int group = 1]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkArtist', {
      'Artist': artist,
      'IsGroup': isgroup,
      'DateTime': datetime.toString(),
      'GroupId': group,
    });
    bookmarkArtistSet![isgroup]!.add(artist);
  }

  Future<void> insertUser(String user,
      [DateTime? datetime, int group = 1]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkUser', {
      'User': user,
      'DateTime': datetime.toString(),
      'GroupId': group,
    });
    bookmarkUserSet!.add(user);
  }

  Future<void> historyUser(String user, [DateTime? datetime]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('HistoryUser', {
      'User': user,
      'DateTime': datetime.toString(),
    });
    historyUserSet!.add(user);
  }

  Future<void> insertCropImage(
      int articleId, int page, String area, double aspectRatio,
      [DateTime? datetime]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkCropImage', {
      'Article': articleId,
      'Page': page,
      'Area': area,
      'AspectRatio': aspectRatio,
      'DateTime': datetime.toString(),
    });
  }

  Future<int> createGroup(String name, String description, Color color,
      [DateTime? datetime]) async {
    datetime ??= DateTime.now();
    var groups = await getGroup();
    var db = await CommonUserDatabase.getInstance();
    return await db.insert('BookmarkGroup', {
      'Name': name,
      'Description': description,
      'DateTime': datetime.toString(),
      'Color': color.value,
      'Gorder': groups.last.gorder() + 1,
    });
  }

  Future<void> deleteGroup(BookmarkGroup group) async {
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkArticle', 'GroupId=?', [group.id().toString()]);
    await db.delete('BookmarkArtist', 'GroupId=?', [group.id().toString()]);
    await db.delete('BookmarkGroup', 'Id=?', [group.id().toString()]);
    bookmarkSet = null;
    //
  }

  Future<void> deleteUser(BookmarkUser user) async {
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkUser', 'Id=?', [user.id()]);
    bookmarkUserSet!.remove(user.user());
    //
  }

  Future<void> deleteCropBookmark(BookmarkCropImage cropImage) async {
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkCropImage', 'Id=?', [cropImage.id()]);
  }

  Future<void> fixGroup() async {
    var groups = (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkGroup'))
        .map((x) => BookmarkGroup(result: x))
        .toList();

    if (groups.length > 1) {
      if (groups[1].gorder() == 1) {
        for (int i = 1; i < groups.length; i++) {
          var rr = Map<String, dynamic>.from(groups[i].result);
          rr['Gorder'] = i + 1;
          groups[i].result = rr;
          await groups[i].update();
        }
      }
    }
  }

  Future<List<BookmarkGroup>> getGroup() async {
    fixGroup();
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkGroup ORDER BY Gorder ASC'))
        .map((x) => BookmarkGroup(result: x))
        .toList();
  }

  Future<void> positionSwap(int from, int to) async {
    print('$from|$to');
    var groups = await getGroup();
    void swap(int x, int y) {
      var tmp = groups[x];
      groups[x] = groups[y];
      groups[y] = tmp;
    }

    for (var element in groups) {
      print(element.gorder());
    }

    if (from < to) {
      for (; from < to; from++) {
        await groups[from].swap(groups[from + 1]);
        swap(from, from + 1);
      }
    } else if (from > to) {
      for (; from > to; from--) {
        await groups[from].swap(groups[from - 1]);
        swap(from, from - 1);
      }
    }

    for (var element in groups) {
      print(element.gorder());
    }
  }

  Future<List<BookmarkArticle>> getArticle() async {
    // TODO: 실제와 다른 테이블을 읽는 경우가 있는데 sqflite 에러인지
    // DB 손상인지 확인 필요. (Query Async Lock해도 동일한 버그 발생)
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

  Future<List<BookmarkUser>> getUser() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkUser'))
        .map((x) => BookmarkUser(result: x))
        .toList();
  }

  Future<List<HistoryUser>> getHistoryUser() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM HistoryUser'))
        .map((x) => HistoryUser(result: x))
        .toList();
  }

  Future<List<BookmarkCropImage>> getCropImages() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkCropImage'))
        .map((x) => BookmarkCropImage(result: x))
        .toList();
  }

  Future<void> modfiyGroup(BookmarkGroup group) async {
    await (await CommonUserDatabase.getInstance())
        .update('BookmarkGroup', group.result, 'Id=?', [group.id()]);
  }

  Future<void> modfiyUser(BookmarkUser user) async {
    await (await CommonUserDatabase.getInstance())
        .update('BookmarkUser', user.result, 'Id=?', [user.id()]);
  }

  HashSet<int>? bookmarkSet;
  Lock bookmarkSetLock = Lock();
  Future<bool> isBookmark(int id) async {
    await bookmarkSetLock.synchronized(() async {
      if (bookmarkSet == null) {
        final article = await getArticle();
        bookmarkSet = HashSet<int>();
        for (var element in article) {
          bookmarkSet!.add(int.parse(element.article()));
        }
      }
    });

    return bookmarkSet!.contains(id);
  }

  Future<void> bookmark(int id) async {
    if (await isBookmark(id)) return;
    bookmarkSet!.add(id);
    await insertArticle(id.toString());
  }

  Future<void> unbookmark(int id) async {
    if (!await isBookmark(id)) return;
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkArticle', 'Article=?', [id.toString()]);
    bookmarkSet!.remove(id);
  }

  Map<int, HashSet<String>>? bookmarkArtistSet;
  Future<bool> isBookmarkArtist(String name, int type) async {
    if (bookmarkArtistSet == null) {
      var artist = await getArtist();
      bookmarkArtistSet = <int, HashSet<String>>{};
      bookmarkArtistSet![0] = HashSet<String>();
      bookmarkArtistSet![1] = HashSet<String>();
      bookmarkArtistSet![2] = HashSet<String>();
      bookmarkArtistSet![3] = HashSet<String>();
      bookmarkArtistSet![4] = HashSet<String>();
      for (var element in artist) {
        bookmarkArtistSet![element.type()]!.add(element.artist());
      }
    }

    return bookmarkArtistSet![type]!.contains(name);
  }

  HashSet<String>? bookmarkUserSet;
  Future<bool> isBookmarkUser(String user) async {
    if (bookmarkUserSet == null) {
      var user = await getUser();
      bookmarkUserSet = HashSet<String>();
      for (var element in user) {
        bookmarkUserSet!.add(element.user());
      }
    }

    return bookmarkUserSet!.contains(user);
  }

  HashSet<String>? historyUserSet;
  Future<bool> isHistoryUser(String user) async {
    if (historyUserSet == null) {
      var user = await getHistoryUser();
      historyUserSet = HashSet<String>();
      for (var element in user) {
        historyUserSet!.add(element.user());
      }
    }

    return historyUserSet!.contains(user);
  }

  Future<void> bookmarkArtist(String name, int type, [int group = 1]) async {
    if (await isBookmarkArtist(name, type)) return;
    bookmarkArtistSet![type]!.add(name);
    await insertArtist(name, type, null, group);
  }

  Future<void> unbookmarkArtist(String name, int type) async {
    if (!await isBookmarkArtist(name, type)) return;
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkArtist', 'Artist=? AND IsGroup=?', [name, type]);
    bookmarkArtistSet![type]!.remove(name);

    print('delete $name, $type');
  }

  Future<void> bookmarkUser(String user, [int group = 1]) async {
    if (await isBookmarkUser(user)) return;
    bookmarkUserSet!.add(user);
    await insertUser(user, null, group);
  }

  Future<void> unbookmarkUser(String user) async {
    if (!await isBookmarkUser(user)) return;
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkUser', 'User=?', [user]);
    bookmarkUserSet!.remove(user);
  }

  Future<void> setHistoryUser(String user) async {
    if (await isHistoryUser(user)) return;
    historyUserSet!.add(user);
    await historyUser(user, null);
  }
}
