// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/settings/settings.dart';

typedef DoubleIntCallback = Future Function(int, int);

class SyncInfoRecord {
  final String type;
  final int timestamp;
  final String url;
  final int size;

  SyncInfoRecord({
    required this.type,
    required this.timestamp,
    required this.url,
    this.size = 0,
  });

  String getDBDownloadUrl(String type) =>
      url + SyncManager.createRawdbPostfix(type);
  String getDBDownloadUrliOS(String type) =>
      url + SyncManager.createRawdbPostfixiOS(type);

  DateTime getDateTime() {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }
}

class SyncManager {
  static String syncInfoURL(String branch){
    return 'https://raw.githubusercontent.com/violet-dev/sync-data/'+(branch)+'/syncversion.txt';
  }

  static bool firstSync = false;
  static bool syncRequire = false; // database sync require
  static bool chunkRequire = false;
  static const ignoreUserAcceptThreshold = 1024 * 1024 * 10; // 10MB
  static List<SyncInfoRecord>? _rows;
  static int requestSize = 0;
  
  static Future<void> checkSyncLatest() async {
    try {
      var ls = const LineSplitter();
      var infoRaw = (await http.get(syncInfoURL('master'))).body;
      var lines = ls.convert(infoRaw);

      final prefs = await SharedPreferences.getInstance();
      var latest = prefs.getInt('synclatest');
      var lastDB = prefs.getString('databasesync');

      if (latest == null) {
        syncRequire = firstSync = true;
        latest = 0;
      } else if (lastDB != null &&
          DateTime.now().difference(DateTime.parse(lastDB)).inDays > 7) {
          syncRequire = true;
      }

      // lines: [old ... latest]
      // _rows: [latest ... old]
      _rows = [];

      /*
        syncversion은 

        ...
        chunk 1640992742 https://github.com/violet-dev/chunk/releases/download/1640992742/data-637765895426855402.json 31519
        db 1640997991 https://github.com/violet-dev/db/releases/download/2022.01.01/rawdata
        chunk 1640998430 https://github.com/violet-dev/chunk/releases/download/1640998430/data-637765952304854006.json 47546
        chunk 1640998430 https://github.com/violet-dev/chunk/releases/download/1640998430/data-637765952304854006.db 45056
        chunk 1641003001 https://github.com/violet-dev/chunk/releases/download/1641003001/data-637765998015030026.json 30911
        chunk 1641003001 https://github.com/violet-dev/chunk/releases/download/1641003001/data-637765998015030026.db 32768
        ...

        와 같은 형식으로 아래쪽이 항상 최신 청크다. 따라서 reversed 탐색을 시도한다.
      */
      for (var element in lines.reversed) {
        if (element.startsWith('#')) continue;

        var split = element.split(' ');
        var type = split[0];
        var timestamp = int.parse(split[1]);
        var url = split[2];
        var size = 0;
        if (type == 'chunk') size = int.parse(split[3]);

        // We require only json files when synchronize with chunk.
        if (type == 'chunk' && !url.endsWith('.json')) continue;

        //
        // 마지막으로 동기화한 시간보다 작은 경우 해당 청크는 무시한다.
        //
        if (type == 'chunk' && timestamp <= latest) continue;

        requestSize += size;
        _rows!.add(SyncInfoRecord(
          type: type,
          timestamp: timestamp,
          url: url,
          size: size,
        ));
      }

      /*
        너무 많은 청크를 다운로드해야하는 경우 동기화를 추천한다.
        그 이유는 다운로드해야하는 파일이 너무 많아지기 때문이며, 
        또한 데이터베이스의 무결성이 훼손될 가능성이 있기 때문이다.
      */
      if (requestSize > ignoreUserAcceptThreshold) syncRequire = true;
      if (_rows!.any((element) => element.type == 'chunk')) chunkRequire = true;
    } catch (e, st) {
      Logger.error('[Sync-check] E: $e\n'
          '$st');
    }
  }


  static Future<void> checkSync() async {
    for(int i = 0;i < 100;i++){
      try {
        var ls = const LineSplitter();
        var infoRaw = (await http.get(syncInfoURL('d2bd5ae068efb26eb4689e5d6281a590e59fc4e2'))).body;
        var lines = ls.convert(infoRaw);

        final prefs = await SharedPreferences.getInstance();
        var latest = prefs.getInt('synclatest');
        var lastDB = prefs.getString('databasesync');

        if (latest == null) {
          syncRequire = firstSync = true;
          latest = 0;
        } else if (lastDB != null &&
            DateTime.now().difference(DateTime.parse(lastDB)).inDays > 7) {
            syncRequire = true;
        }

        // lines: [old ... latest]
        // _rows: [latest ... old]
        _rows = [];

        /*
          syncversion은 

          ...
          chunk 1640992742 https://github.com/violet-dev/chunk/releases/download/1640992742/data-637765895426855402.json 31519
          db 1640997991 https://github.com/violet-dev/db/releases/download/2022.01.01/rawdata
          chunk 1640998430 https://github.com/violet-dev/chunk/releases/download/1640998430/data-637765952304854006.json 47546
          chunk 1640998430 https://github.com/violet-dev/chunk/releases/download/1640998430/data-637765952304854006.db 45056
          chunk 1641003001 https://github.com/violet-dev/chunk/releases/download/1641003001/data-637765998015030026.json 30911
          chunk 1641003001 https://github.com/violet-dev/chunk/releases/download/1641003001/data-637765998015030026.db 32768
          ...

          와 같은 형식으로 아래쪽이 항상 최신 청크다. 따라서 reversed 탐색을 시도한다.
        */
        for (var element in lines.reversed) {
          if (element.startsWith('#')) continue;

          var split = element.split(' ');
          var type = split[0];
          var timestamp = int.parse(split[1]);
          var url = split[2];
          var size = 0;
          if (type == 'chunk') size = int.parse(split[3]);

          // We require only json files when synchronize with chunk.
          if (type == 'chunk' && !url.endsWith('.json')) continue;

          //
          // 마지막으로 동기화한 시간보다 작은 경우 해당 청크는 무시한다.
          //
          if (type == 'chunk' && timestamp <= latest) continue;

          requestSize += size;
          _rows!.add(SyncInfoRecord(
            type: type,
            timestamp: timestamp,
            url: url,
            size: size,
          ));
        }

        /*
          너무 많은 청크를 다운로드해야하는 경우 동기화를 추천한다.
          그 이유는 다운로드해야하는 파일이 너무 많아지기 때문이며, 
          또한 데이터베이스의 무결성이 훼손될 가능성이 있기 때문이다.
        */
        if (requestSize > ignoreUserAcceptThreshold) syncRequire = true;
        if (_rows!.any((element) => element.type == 'chunk')) chunkRequire = true;
      } catch (e, st) {
        continue;
        Logger.error('[Sync-check] E: $e\n'
            '$st');
      }
    }
  }

  static SyncInfoRecord getLatestDB() {
    if (_rows != null) {
      for (int i = 0; i < _rows!.length; i++) {
        if (_rows![i].type == 'db') return _rows![i];
      }
    }

    //
    //  syncversion.txt에 데이터베이스 정보가 없는 경우라면 동기화 방지를 위해
    //  1970년 01월 01일 00:00:00를 리턴한다.
    //
    return SyncInfoRecord(
      type: 'db',
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(0).millisecondsSinceEpoch ~/ 1000,
      url: '',
    );
  }

  static int getSyncRequiredChunkCount() {
    if (_rows == null) return 0;
    return _rows!.where((element) => element.type == 'chunk').toList().length;
  }

  static Future<void> doChunkSync(DoubleIntCallback progressCallback) async {
    // Only chunk
    var filteredIter =
        _rows!.where((element) => element.type == 'chunk').toList();

    // Download Jsons
    var res = <Response>[];

    //
    //  너무 많은 동시 다운로드 작업으로 인해 connection fail이 발생할 수 있다.
    //  따라서 16개씩 나누어서 동시 다운로드한다.
    //
    for (var i = 0; i < filteredIter.length / 16; i++) {
      var starts = i * 16;
      var ends = min((i + 1) * 16, filteredIter.length);

      var resi = await Future.wait(filteredIter
          .sublist(starts, ends)
          .map((e) => http.get(e.url).then((value) async {
                await progressCallback(0, filteredIter.length);
                return value;
              })));

      res.addAll(resi);
    }
    var jsons = res.map((e) => utf8.decode(e.bodyBytes)).toList();

    // Update Database
    try {
      for (int i = 0; i < filteredIter.length; i++) {
        // Larger timestamp, the more recent data is contained.
        // So, we need to update them in old order.
        var row = filteredIter[filteredIter.length - i - 1];
        if (row.type != 'chunk') continue;

        // First, parse json
        var json = jsonDecode(jsons[filteredIter.length - i - 1]);

        // Second, convert json to query
        var qlist = json as List<dynamic>;
        var quries = qlist
            .map((e) => QueryResult(result: e as Map<String, dynamic>))
            .toList();

        // Third, filtering records with language
        var lang = translateToLanguage(Settings.databaseType);
        if (lang != '') {
          quries = quries.where((element) {
            var ll = element.language() as String;
            return (ll == lang) || (ll == 'n/a');
          }).toList();
        }

        // Last, append datas
        var db = await DataBaseManager.getInstance();
        var dbraw = await openDatabase(db.dbPath!);
        await dbraw.transaction((txn) async {
          final batch = txn.batch();
          for (var query in quries) {
            batch.insert('HitomiColumnModel', query.result,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit();
        });
        await dbraw.close();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('synclatest', row.timestamp);
      }

      if (Settings.useOptimizeDatabase && filteredIter.isNotEmpty) {
        final sql = HitomiManager.translate2query(
          '${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}',
          filter: false,
        );

        await (await DataBaseManager.getInstance()).delete('HitomiColumnModel',
            'NOT (${sql.substring(sql.indexOf('WHERE') + 6)})', []);
      }
    } catch (e, st) {
      // If an error occurs, stops synchronization immediately.
      Logger.error('[Sync-chunk] E: $e\n'
          '$st');
      FirebaseCrashlytics.instance.recordError(e, st);
    }
  }

  static String createRawdbPostfix(String lang) {
    switch (lang) {
      case 'global':
        return '.7z';
      case 'ko':
        return '-korean.7z';
      case 'zh':
        return '-chinese.7z';
      case 'ja':
        return '-japanese.7z';
      case 'en':
        return '-english.7z';
    }

    throw Exception('not reachable');
  }

  static String createRawdbPostfixiOS(String lang) {
    switch (lang) {
      case 'global':
        return '.db';
      case 'ko':
        return '-korean.db';
      case 'zh':
        return '-chinese.db';
      case 'ja':
        return '-japanese.db';
      case 'en':
        return '-english.db';
    }

    throw Exception('not reachable');
  }

  static String translateToLanguage(String lang) {
    switch (lang) {
      case 'global':
        return '';
      case 'ko':
        return 'korean';
      case 'zh':
        return 'chinese';
      case 'ja':
        return 'japanese';
      case 'en':
        return 'english';
    }

    throw Exception('not reachable');
  }
}
