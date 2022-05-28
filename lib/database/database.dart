// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

class DataBaseManager {
  String? dbPath;
  Database? db;
  Lock lock = Lock();
  static DataBaseManager? _instance;

  DataBaseManager({this.dbPath});

  static DataBaseManager create(String dbPath) {
    return DataBaseManager(dbPath: dbPath);
  }

  @protected
  @mustCallSuper
  void dispose() async {
    // await close();
  }

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      var dbPath = Platform.isAndroid
          ? '${(await getApplicationDocumentsDirectory()).path}/data/data.db'
          : '${await getDatabasesPath()}/data.db';
      _instance = create(dbPath);
    }
    return _instance!;
  }

  static Future<void> reloadInstance() async {
    var dbPath = Platform.isAndroid
        ? '${(await getApplicationDocumentsDirectory()).path}/data/data.db'
        : '${await getDatabasesPath()}/data.db';
    _instance = create(dbPath);
  }

  Future _open() async {
    db = await openDatabase(dbPath!);
  }

  Future _close() async {
    await db!.close();
  }

  Future<List<Map<String, dynamic>>> query(String str) async {
    List<Map<String, dynamic>> result = [];
    await lock.synchronized(() async {
      await _open();
      result = await db!.rawQuery(str);
      await _close();
    }, timeout: Duration(seconds: 5));
    return result;
  }

  Future<void> execute(String str) async {
    await lock.synchronized(() async {
      await _open();
      await db!.execute(str);
      await _close();
    }, timeout: Duration(seconds: 5));
  }

  Future<int> insert(String name, Map<String, dynamic> wh) async {
    int result = -1;
    await lock.synchronized(() async {
      await _open();
      result = await db!.insert(name, wh);
      await _close();
    }, timeout: Duration(seconds: 5));
    return result;
  }

  Future<void> update(String name, Map<String, dynamic> wh, String where,
      List<dynamic> args) async {
    await lock.synchronized(() async {
      await _open();
      await db!.update(name, wh, where: where, whereArgs: args);
      await _close();
    }, timeout: Duration(seconds: 5));
  }

  Future<void> swap(String name, String key, String what, int key1, int key2,
      int s1, int s2) async {
    await lock.synchronized(() async {
      await _open();
      await db!.rawUpdate('UPDATE $name SET $what=? WHERE $key=?', [s2, key1]);
      await db!.rawUpdate('UPDATE $name SET $what=? WHERE $key=?', [s1, key2]);
      await _close();
    }, timeout: Duration(seconds: 5));
  }

  Future<void> delete(String name, String where, List<dynamic> args) async {
    await lock.synchronized(() async {
      await _open();
      await db!.delete(name, where: where, whereArgs: args);
      await _close();
    }, timeout: Duration(seconds: 5));
  }

  Future<bool> test() async {
    try {
      final x = await query('SELECT count(*) FROM HitomiColumnModel');
      if ((x[0]['count(*)'] as int) < 5000) return false;
      return true;
    } catch (e) {
      return false;
    }
  }
}
