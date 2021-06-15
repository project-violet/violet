// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

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
  BookmarkGroup({this.result});

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
          } catch (e, st) {
            Logger.error('[Bookmark Instance] E: ' +
                e.toString() +
                '\n' +
                st.toString());
          }
        }
        _instance = Bookmark();
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
    bookmarkSet.add(int.parse(article));
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
    bookmarkArtistSet[isgroup].add(artist);
  }

  Future<void> createGroup(String name, String description, Color color,
      [DateTime datetime]) async {
    datetime ??= DateTime.now();
    var groups = await getGroup();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkGroup', {
      'Name': name,
      'Description': description,
      'DateTime': DateTime.now().toString(),
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
    print(from.toString() + "|" + to.toString());
    var groups = await getGroup();
    void swap(int x, int y) {
      var tmp = groups[x];
      groups[x] = groups[y];
      groups[y] = tmp;
    }

    groups.forEach((element) {
      print(element.gorder());
    });

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

    groups.forEach((element) {
      print(element.gorder());
    });
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
    await db.delete('BookmarkArticle', 'Article=?', [id.toString()]);
    bookmarkSet.remove(id);
  }

  Map<int, HashSet<String>> bookmarkArtistSet;
  Future<bool> isBookmarkArtist(String name, int type) async {
    await lock.synchronized(() async {
      if (bookmarkArtistSet == null) {
        var artist = await getArtist();
        bookmarkArtistSet = Map<int, HashSet<String>>();
        bookmarkArtistSet[0] = HashSet<String>();
        bookmarkArtistSet[1] = HashSet<String>();
        bookmarkArtistSet[2] = HashSet<String>();
        bookmarkArtistSet[3] = HashSet<String>();
        bookmarkArtistSet[4] = HashSet<String>();
        artist.forEach((element) {
          bookmarkArtistSet[element.type()].add(element.artist());
        });
      }
    });

    return bookmarkArtistSet[type].contains(name);
  }

  Future<void> bookmarkArtist(String name, int type, [int group = 1]) async {
    if (await isBookmarkArtist(name, type)) return;
    bookmarkArtistSet[type].add(name);
    await insertArtist(name, type, null, group);
  }

  Future<void> unbookmarkArtist(String name, int type) async {
    if (!await isBookmarkArtist(name, type)) return;
    var db = await CommonUserDatabase.getInstance();
    await db.delete('BookmarkArtist', 'Artist=? AND IsGroup=?', [name, type]);
    bookmarkArtistSet[type].remove(name);

    print('delete $name, $type');
  }
}
