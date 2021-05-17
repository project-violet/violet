// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

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
      await _instance.open();
    }
    return _instance;
  }

  static Future<void> reloadInstance() async {
    _instance =
        create((await SharedPreferences.getInstance()).getString('db_path'));
  }

  Future open() async {
    db = await openDatabase(dbPath);
  }

  Future close() async {
    await db.close();
  }

  Future<List<Map<String, dynamic>>> query(String str) async {
    List<Map<String, dynamic>> result;
    result = await db.rawQuery(str);
    return result;
  }

  Future<void> execute(String str) async {
    await db.execute(str);
  }

  Future<void> insert(String name, Map<String, dynamic> wh) async {
    await db.insert(name, wh);
  }

  Future<void> update(String name, Map<String, dynamic> wh, String where,
      List<dynamic> args) async {
    await db.update(name, wh, where: where, whereArgs: args);
  }

  Future<void> swap(String name, String key, String what, int key1, int key2,
      int s1, int s2) async {
    await db.transaction((txn) async {
      await txn.rawUpdate("UPDATE $name SET $what=? WHERE $key=?", [s2, key1]);
      await txn.rawUpdate("UPDATE $name SET $what=? WHERE $key=?", [s1, key2]);
    });
  }

  Future<void> delete(String name, String where, List<dynamic> args) async {
    await db.delete(name, where: where, whereArgs: args);
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
