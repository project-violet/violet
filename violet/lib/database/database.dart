// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

class DataBaseManager {
  String dbPath;
  Database db;
  Lock lock = Lock();
  static DataBaseManager _instance;

  DataBaseManager({this.dbPath});

  static DataBaseManager create(String dbPath) {
    return new DataBaseManager(dbPath: dbPath);
  }

  @protected
  @mustCallSuper
  void dispose() async {
    // await close();
  }

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      _instance =
          create((await SharedPreferences.getInstance()).getString('db_path'));
    }
    return _instance;
  }

  static Future<void> reloadInstance() async {
    _instance =
        create((await SharedPreferences.getInstance()).getString('db_path'));
  }

  Future _open() async {
    db = await openDatabase(dbPath);
  }

  Future _close() async {
    await db.close();
  }

  Future<List<Map<String, dynamic>>> query(String str) async {
    List<Map<String, dynamic>> result;
    await lock.synchronized(() async {
      await _open();
      result = await db.rawQuery(str);
      await _close();
    });
    return result;
  }

  Future<void> execute(String str) async {
    await lock.synchronized(() async {
      await _open();
      await db.execute(str);
      await _close();
    });
  }

  Future<void> insert(String name, Map<String, dynamic> wh) async {
    await lock.synchronized(() async {
      await _open();
      await db.insert(name, wh);
      await _close();
    });
  }

  Future<void> update(String name, Map<String, dynamic> wh, String where,
      List<dynamic> args) async {
    await lock.synchronized(() async {
      await _open();
      await db.update(name, wh, where: where, whereArgs: args);
      await _close();
    });
  }

  Future<void> swap(String name, String key, String what, int key1, int key2,
      int s1, int s2) async {
    await lock.synchronized(() async {
      await _open();
      await db.rawUpdate("UPDATE $name SET $what=? WHERE $key=?", [s2, key1]);
      await db.rawUpdate("UPDATE $name SET $what=? WHERE $key=?", [s1, key2]);
      await _close();
    });
  }

  Future<void> delete(String name, String where, List<dynamic> args) async {
    await lock.synchronized(() async {
      await _open();
      await db.delete(name, where: where, whereArgs: args);
      await _close();
    });
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
