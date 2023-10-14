// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  void dispose() async {
    print('close: ${dbPath!}');
    if (db != null) db!.close();
  }

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      String dbPath;

      if (Platform.isAndroid) {
        dbPath =
            '${(await getApplicationDocumentsDirectory()).path}/data/data.db';
      } else if (Platform.isIOS) {
        dbPath = '${await getDatabasesPath()}/data.db';
      } else {
        dbPath = '${File(Platform.resolvedExecutable).parent.path}/data.db';
      }

      _instance = create(dbPath);
      await _instance!.open();
    }
    return _instance!;
  }

  static Future<void> reloadInstance() async {
    String dbPath;

    if (Platform.isAndroid) {
      dbPath =
          '${(await getApplicationDocumentsDirectory()).path}/data/data.db';
    } else if (Platform.isIOS) {
      dbPath = '${await getDatabasesPath()}/data.db';
    } else {
      dbPath = '${File(Platform.resolvedExecutable).parent.path}/data.db';
    }

    _instance = create(dbPath);
  }

  Future open() async {
    if (Platform.isAndroid || Platform.isIOS) {
      db ??= await openDatabase(dbPath!);
    } else {
      db ??= await databaseFactoryFfi.openDatabase(dbPath!);
    }
  }

  Future checkOpen() async {
    if (!db!.isOpen) {
      if (Platform.isAndroid || Platform.isIOS) {
        db = await openDatabase(dbPath!);
      } else {
        db = await databaseFactoryFfi.openDatabase(dbPath!);
      }
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
