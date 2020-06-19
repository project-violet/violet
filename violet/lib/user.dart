// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/database.dart';

class CommonUserDatabase extends DataBaseManager {
  static DataBaseManager _instance;

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      var dir = await getApplicationDocumentsDirectory();
      _instance = DataBaseManager.create('$dir/user.db');
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
    await db.update('BookmarkGroup', result);
  }
}

class BookmarkArticle {
  Map<String, dynamic> result;
  BookmarkArticle({this.result});

  int id() => result['Id'];
  String article() => result['Article'];
  String datetime() => result['DateTime'];
  int group() => result['Group'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkArticle', result);
  }
}

class BookmarkArtist {
  Map<String, dynamic> result;
  BookmarkArtist({this.result});

  int id() => result['Id'];
  String artist() => result['Artist'];
  int isGroup() => result['IsGroup'];
  String datetime() => result['DateTime'];
  int group() => result['Group'];

  Future<void> update() async {
    var db = await CommonUserDatabase.getInstance();
    await db.update('BookmarkArtist', result);
  }
}

class Bookmark {
  static Bookmark _instance;
  static Future<Bookmark> getInstance() async {
    if (_instance == null) {
      var db = await CommonUserDatabase.getInstance();
      var ee = await db.query(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='Bookmark';");
      if (ee.length == 0) {
        await db.execute(
            'CREATE TABLE BookmarkGroup (Id integer primary key autoincrement, Name text, DateTime text, Description text, Color integer)');
        await db.execute('''CREATE TABLE BookmarkArticle (
              Id integer primary key autoincrement, 
              Article text, 
              DateTime text, 
              Group FOREIGN KEY(Id) REFERENCES BookmarkGroup(Id));
              ''');
        await db.execute('''CREATE TABLE BookmarkArtist (
              Id integer primary key autoincrement, 
              Artist text, 
              IsGroup integer,
              DateTime text, 
              Group FOREIGN KEY(Id) REFERENCES BookmarkGroup(Id));
              ''');

        // Insert default bookmark group.
        await db.insert('BookmarkGroup', {
          'Name': 'violet_default', // 미분류
          'Description': 'Unclassified bookmarks.',
          'DateTime': DateTime.now().toString(),
          'Color': Colors.grey.value
        });
      }
    }
    return _instance;
  }

  Future<void> insertArticle(String article,
      [DateTime datetime, int group = 0]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkArtist', {
      'Article': article,
      'DateTime': datetime.toString(),
      'Group': group,
    });
  }

  Future<void> insertArtist(String artist, int isgroup,
      [DateTime datetime, int group = 0]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkArtist', {
      'Artist': artist,
      'IsGroup': isgroup,
      'DateTime': datetime.toString(),
      'Group': group,
    });
  }

  Future<void> createGroup(String name, String description, Color color,
      [DateTime datetime]) async {
    datetime ??= DateTime.now();
    var db = await CommonUserDatabase.getInstance();
    await db.insert('BookmarkGroup', {
      'Name': 'violet_default',
      'Description': 'Unclassified bookmarks.',
      'DateTime': DateTime.now().toString(),
      'Color': color.value
    });
  }

  Future<List<BookmarkGroup>> getGroups() async {
    return (await (await CommonUserDatabase.getInstance())
            .query('SELECT * FROM BookmarkGroup'))
        .map((x) => BookmarkGroup(result: x))
        .toList();
  }

  Future<List<BookmarkArticle>> getArticles() async {
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
}

////////////////////////////////////////////////////////////////////////
///
///         User Record
///
////////////////////////////////////////////////////////////////////////

class UserRecord {

}