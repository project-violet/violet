// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';
import 'package:violet/settings/path.dart';

class VioletChecker {
  static Future<bool> checkArticleDatabase() async {
    const testPrefix = '[Checker] checkArticleDatabase';
    Database? db;

    try {
      //
      //  0. get database path
      //
      var dbPath = (Platform.isAndroid || Platform.isLinux)
          ? '${(await DefaultPathProvider.getBaseDirectory())}/data/data.db'
          : '${(await DefaultPathProvider.getBaseDirectory())}/data.db';

      //
      // 1. check file exists
      //
      if (!await File(dbPath).exists()) {
        await Logger.error('$testPrefix\n'
            'database file not exists\n'
            'PATH:$dbPath');
        return true;
      }

      //
      // 2. load database
      //
      try {
        db = await openDatabase(dbPath);
      } catch (e, st) {
        await Logger.error('$testPrefix\n'
            'load database fail\n'
            'E: $e\n'
            '$st');
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
        await Logger.error('$testPrefix\n'
            'query fail\n'
            'E: $e\n'
            '$st');
        return true;
      }

      //
      // 4. check result is empty
      //
      if (results.isEmpty) {
        await Logger.error('$testPrefix\n'
            'query result is empty');
        return true;
      }

      await db.close();
      db = null;

      //
      // everything is fine
      //
      return false;
    } catch (e, st) {
      await Logger.error('$testPrefix\n'
          'unhandled\n'
          'E: $e\n'
          '$st');
      return true;
    } finally {
      if (db != null) {
        await db.close();
      }
    }
  }

  static Future<bool> checkUserDatabase() async {
    const testPrefix = '[Checker] checkUserDatabase';
    Database? db;

    try {
      //
      //  0. get database path
      //
      var dir = DefaultPathProvider.getDocumentsDirectory();
      var dbPath = '${dir}/user.db';

      //
      // 1. check file exists
      //
      if (!await File(dbPath).exists()) {
        await Logger.error('$testPrefix\n'
            'database file not exists\n'
            'PATH:$dbPath');
        return true;
      }

      //
      // 2. load database
      //
      try {
        db = await openDatabase(dbPath);
      } catch (e, st) {
        await Logger.error('$testPrefix\n'
            'load database fail\n'
            'E: $e\n'
            '$st');
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
        await Logger.error('$testPrefix\n'
            'query fail\n'
            'E: $e\n'
            '$st');
        return true;
      }

      //
      // 4. check result is empty
      //
      if (results.isEmpty || results[0].isEmpty) {
        await Logger.error('$testPrefix\n'
            'query result is empty');
        return true;
      }

      await db.close();
      db = null;

      //
      // everything is fine
      //
      return false;
    } catch (e, st) {
      await Logger.error('$testPrefix\n'
          'unhandled\n'
          'E: $e\n'
          '$st');
      return true;
    } finally {
      if (db != null) {
        await db.close();
      }
    }
  }
}
