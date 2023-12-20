// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

class CookiesManager {
  String? dbPath;
  Database? db;
  static CookiesManager? _instance;

  CookiesManager({this.dbPath});

  static CookiesManager create(String dbPath) {
    return CookiesManager(dbPath: dbPath);
  }

  @protected
  @mustCallSuper
  void dispose() async {
    print('close: ${dbPath!}');
    if (db != null) db!.close();
  }

  static Future<CookiesManager> getInstance(String dbPath) async {
    if (_instance == null) {
      _instance = create(dbPath);
      await _instance!.open();
    }
    return _instance!;
  }

  static Future<void> reloadInstance(String dbPath) async {
    _instance = create(dbPath);
  }

  Future open() async {
    db ??= await openDatabase(dbPath!);
  }

  Future checkOpen() async {
    if(db != null){
      if (!db!.isOpen) db = await openDatabase(dbPath!);
    } else if(db == null){
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
}
