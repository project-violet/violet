// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/network/wrapper.dart' as http;

class SyncInfoRecord {
  final String type;
  final int timestamp;
  final String url;
  final int size;

  SyncInfoRecord({this.type, this.timestamp, this.url, this.size = 0});
}

class SyncManager {
  static const String syncInfoURL = "https://koromo.xyz/version.txt";

  static bool syncRequire = false;
  static const ignoreUserAcceptThreshold = 1024 * 1024 * 10; // 10MB
  static List<SyncInfoRecord> _rows;
  static int requestSize = 0;

  static Future<void> checkSync() async {
    var ls = new LineSplitter();
    var infoRaw = (await http.get(syncInfoURL)).body;
    var lines = ls.convert(infoRaw);

    var latest = (await SharedPreferences.getInstance()).getInt('synclatest');

    if (latest == null) {
      syncRequire = true;
      latest = 0;
    }

    // lines: [old ... latest]
    // _rows: [latest ... old]
    _rows = List<SyncInfoRecord>();

    lines.reversed.forEach((element) {
      var split = element.split(' ');
      var type = split[0];
      var timestamp = int.parse(split[1]);
      var url = split[2];
      var size = 0;
      if (type == 'chunk') size = int.parse(split[3]);

      // We require only json files when synchronize with chunk.
      if (type == 'chunk' && !url.endsWith('.json')) return;
      if (timestamp <= latest) return;

      requestSize += size;
      _rows.add(SyncInfoRecord(
          type: type, timestamp: timestamp, url: url, size: size));
    });
  }

  static SyncInfoRecord getLatestDB() {
    for (int i = 0; i < _rows.length; i++)
      if (_rows[i].type == 'db') return _rows[i];

    throw Exception('not reachable, check sync server');
  }

  static Future<void> doChunkSync() async {
    for (int i = 0; i < _rows.length; i++) {
      // Larger timestamp, the more recent data is contained.
      // So, we need to update them in old order.
      var row = _rows[_rows.length - i - 1];

      // First, download json
      var raw = (await http.get(row.url)).body;
      var json = jsonDecode(raw);

      // Second, convert json to query
      var qlist = json as List<dynamic>;
      var quries = qlist
          .map((e) => QueryResult(result: e as Map<String, dynamic>))
          .toList();

      // Last, append datas
      var db = await DataBaseManager.getInstance();
      var dbraw = await openDatabase(db.dbPath);
      await dbraw.transaction((txn) async {
        final batch = txn.batch();
        for (var query in quries)
          batch.insert('HitomiColumnModel', query.result,
              conflictAlgorithm: ConflictAlgorithm.replace);
        await batch.commit();
      });
      await dbraw.close();
    }
  }
}
