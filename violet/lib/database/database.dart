// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DataBaseManager {
  String? dbPath;
  Database? db;
  static DataBaseManager? _instance;

  DataBaseManager({this.dbPath});

  static DataBaseManager create(String dbPath) {
    return DataBaseManager(dbPath: dbPath);
  }

  @protected
  @mustCallSuper
  Future<void> dispose() async {
    print('close: ${dbPath!}');
    await db?.close();
    db = null;
  }

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      var dbPath = Platform.isAndroid
          ? '${(await getApplicationDocumentsDirectory()).path}/data/data.db'
          : '${await getDatabasesPath()}/data.db';
      _instance = create(dbPath);
      await _instance!.open();
    }
    return _instance!;
  }

  static Future<void> reloadInstance() async {
    final db = _instance?.db;
    _instance?.db = null;
    await db?.close();
  }

  Future<void> open() async {
    db ??= await openDatabase(dbPath!);
  }

  Future<void> checkOpen() async {
    if (!(db?.isOpen ?? false)) {
      db = await openDatabase(dbPath!);
    }
  }

  Future<List<Map<String, dynamic>>> query(String str) async {
    List<Map<String, dynamic>> result = [];
    await checkOpen();
    result = await db!.rawQuery(str);
    return result;
  }

  Future<void> execute(String str) async {
    await checkOpen();
    await db!.execute(str);
  }

  Future<int> insert(String name, Map<String, dynamic> wh) async {
    int result = -1;
    await checkOpen();
    result = await db!.insert(name, wh);
    return result;
  }

  Future<void> update(String name, Map<String, dynamic> wh, String where,
      List<dynamic> args) async {
    await checkOpen();
    await db!.update(name, wh, where: where, whereArgs: args);
  }

  Future<void> swap(String name, String key, String what, int key1, int key2,
      int s1, int s2) async {
    await checkOpen();
    await db!.transaction((txn) async {
      await txn.rawUpdate('UPDATE $name SET $what=? WHERE $key=?', [s2, key1]);
      await txn.rawUpdate('UPDATE $name SET $what=? WHERE $key=?', [s1, key2]);
    });
  }

  Future<void> delete(String name, String where, List<dynamic> args) async {
    await checkOpen();
    await db!.delete(name, where: where, whereArgs: args);
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
