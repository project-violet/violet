// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';

class VioletChecker {
  static Future<bool> checkArticleDatabase() async {
    const testPrefix = '[Checker] checkArticleDatabase';
    Database db;

    try {
      //
      //  0. get database path
      //
      var dbPath = (await SharedPreferences.getInstance()).getString('db_path');

      //
      // 1. check file exists
      //
      if (!await File(dbPath).exists()) {
        await Logger.error(
            '$testPrefix\n' + 'database file not exists\n' + 'PATH:$dbPath');
        return true;
      }

      //
      // 2. load database
      //
      try {
        db = await openDatabase(dbPath);
      } catch (e, st) {
        await Logger.error('$testPrefix\n' +
            'load database fail\n' +
            'E: ' +
            e.toString() +
            '\n' +
            st.toString());
        return true;
      }

      //
      // 3. test qurey
      //
      const testQuery = 'SELECT * FROM HitomiColumnModel ORDER BY Id LIMIT 1';
      List<QueryResult> results;
      try {
        var queryResult = await db.rawQuery(testQuery);
        results = queryResult.map((e) => QueryResult(result: e)).toList();
      } catch (e, st) {
        await Logger.error('$testPrefix\n' +
            'query fail\n' +
            'E: ' +
            e.toString() +
            '\n' +
            st.toString());
        return true;
      }

      //
      // 4. check result is empty
      //
      if (results == null || results.length == 0) {
        await Logger.error('$testPrefix\n' + 'query result is empty');
        return true;
      }

      await db.close();
      db = null;

      //
      // everything is fine
      //
      return false;
    } catch (e, st) {
      await Logger.error('$testPrefix\n' +
          'unhandled\n' +
          'E: ' +
          e.toString() +
          '\n' +
          st.toString());

      return true;
    } finally {
      if (db != null) {
        await db.close();
      }
    }
  }

  static Future<bool> checkUserDatabase() async {
    const testPrefix = '[Checker] checkUserDatabase';
    Database db;

    try {
      //
      //  0. get database path
      //
      var dir = await getApplicationDocumentsDirectory();
      var dbPath = '${dir.path}/user.db';

      //
      // 1. check file exists
      //
      if (!await File(dbPath).exists()) {
        await Logger.error(
            '$testPrefix\n' + 'database file not exists\n' + 'PATH:$dbPath');
        return true;
      }

      //
      // 2. load database
      //
      try {
        db = await openDatabase(dbPath);
      } catch (e, st) {
        await Logger.error('$testPrefix\n' +
            'load database fail\n' +
            'E: ' +
            e.toString() +
            '\n' +
            st.toString());
        return true;
      }

      //
      // 3. test qurey
      //
      const testQuery =
          "SELECT name FROM sqlite_master WHERE type='table' AND name='BookmarkGroup';";
      List<Map<String, dynamic>> results;
      try {
        results = await db.rawQuery(testQuery);
      } catch (e, st) {
        await Logger.error('$testPrefix\n' +
            'query fail\n' +
            'E: ' +
            e.toString() +
            '\n' +
            st.toString());
        return true;
      }

      //
      // 4. check result is empty
      //
      if (results == null || results.length == 0 || results[0].length == 0) {
        await Logger.error('$testPrefix\n' + 'query result is empty');
        return true;
      }

      await db.close();
      db = null;

      //
      // everything is fine
      //
      return false;
    } catch (e, st) {
      await Logger.error('$testPrefix\n' +
          'unhandled\n' +
          'E: ' +
          e.toString() +
          '\n' +
          st.toString());

      return true;
    } finally {
      if (db != null) {
        await db.close();
      }
    }
  }

  static Future<bool> checkDownloadable() async {
    
  }
}
