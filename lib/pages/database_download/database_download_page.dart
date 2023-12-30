// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/database_download/decompress.dart';
import 'package:violet/platform/misc.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';

typedef TagIndexingCallback = dynamic Function(QueryResult);

class DataBaseDownloadPage extends StatefulWidget {
  final String? dbType;
  final bool isSync;

  const DataBaseDownloadPage({
    super.key,
    this.dbType,
    this.isSync = false,
  });

  @override
  State<DataBaseDownloadPage> createState() => DataBaseDownloadPageState();
}

class DataBaseDownloadPageState extends State<DataBaseDownloadPage> {
  bool downloading = false;
  var baseString = '';
  var progressString = '';
  var downString = '';
  var speedString = '';

  var _showCloseAppButton = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance
        .addPostFrameCallback((_) async => checkDownload());
  }

  Future checkDownload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('db_exists') == 1) {
        var dbPath = Platform.isAndroid
            ? '${(await getApplicationDocumentsDirectory()).path}/data/data.db'
            : '${await getDatabasesPath()}/data.db';
        if (await File(dbPath).exists()) await File(dbPath).delete();
        var dir = await getApplicationDocumentsDirectory();
        if (await Directory('${dir.path}/data').exists()) {
          await Directory('${dir.path}/data').delete(recursive: true);
        }
      }
    } catch (e, st) {
      Logger.error('[DBDownload-Check] E: $e\n'
          '$st');
    }

    if (Platform.isAndroid) {
      downloadFileAndroid();
    } else if (Platform.isIOS) {
      // p7zip is not supported on IOS.
      // So, download raw database.
      downloadFileIOS();
    }
  }

  Future<void> downloadFileAndroid() async {
    try {
      await downloadFileAndroidWith('latest', true);
    } catch (e) {
      await downloadFileAndroidWith('old', false);
    }
  }

  Future<void> downloadFileIOS() async {
    try {
      await downloadFileIOSWith('latest', true);
    } catch (e) {
      await downloadFileIOSWith('old', false);
    }
  }

  Future<void> downloadFileAndroidWith(String target, bool _throw) async {
    Dio dio = Dio();
    int oneMega = 1024 * 1024;
    int nu = 0;
    int latest = 0;
    int tlatest = 0;
    int tnu = 0;

    try {
      var dir = await getApplicationDocumentsDirectory();
      if (await File('${dir.path}/db.sql.7z').exists()) {
        await File('${dir.path}/db.sql.7z').delete();
      }
      switch (target) {
        case 'latest':
          await SyncManager.checkSyncLatest(_throw);
          break;
        case 'old':
          await SyncManager.checkSyncOld(_throw);
          break;
        default:
          {
            try {
              await downloadFileAndroidWith('latest', true);
            } catch (e) {
              await downloadFileAndroidWith('old', false);
            }
            return;
          }
      }
      Timer timer = Timer.periodic(
          const Duration(seconds: 1),
          (Timer timer) => setState(() {
                final speed = tlatest / 1024;
                speedString = '${_formatNumberWithComma(speed)} KB/s';
                tlatest = tnu;
                tnu = 0;
              }));
      await dio.download(
          SyncManager.getLatestDB().getDBDownloadUrl(widget.dbType!),
          '${dir.path}/db.sql.7z', onReceiveProgress: (rec, total) {
        nu += rec - latest;
        tnu += rec - latest;
        latest = rec;
        if (nu <= oneMega) return;

        nu = 0;

        setState(
          () {
            downloading = true;
            final progressPercent = (rec / total) * 100;
            progressString = '${_formatNumberWithComma(progressPercent)}%';
            downString =
                '[${_formatNumberWithComma(rec)}/${_formatNumberWithComma(total)}]';
          },
        );
      });
      timer.cancel();

      setState(() {
        baseString = Translations.instance!.trans('dbdunzip');
        print(baseString);
        downloading = false;
      });

      final p7zip = P7zip();
      if (await Directory('${dir.path}/data2').exists()) {
        await Directory('${dir.path}/data2').delete(recursive: true);
      }
      await p7zip.decompress(
        ['${dir.path}/db.sql.7z'],
        path: '${dir.path}/data2',
      );
      Variables.databaseDecompressed = true;
      if (await Directory('${dir.path}/data').exists()) {
        await Directory('${dir.path}/data').delete(recursive: true);
      }
      await Directory('${dir.path}/data2').rename('${dir.path}/data');
      if (await Directory('${dir.path}/data2').exists()) {
        await Directory('${dir.path}/data2').delete(recursive: true);
      }

      await File('${dir.path}/db.sql.7z').delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('db_exists', 1);
      await prefs.setString('databasetype', widget.dbType!);
      await prefs.setString(
          'databasesync', SyncManager.getLatestDB().getDateTime().toString());
      await prefs.setInt('synclatest', SyncManager.getLatestDB().timestamp);

      await DataBaseManager.reloadInstance();

      if (Settings.useOptimizeDatabase) {
        try {
          await deleteUnused();
        } catch (e1, st1) {
          Logger.error('[deleteUnused] E: $e1\n'
              '$st1');
        }
        try {
          await indexing();
        } catch (e1, st1) {
          Logger.error('[indexing] E: $e1\n'
              '$st1');
        }
      }

      if (widget.isSync == true) {
        Navigator.pop(context);
      } else {
        setState(() {
          baseString = Translations.instance!.trans('dbdcomplete');
          _showCloseAppButton = true;
        });
      }

      return;
    } catch (e, st) {
      Logger.error('[DBDownload] E: $e\n'
          '$st');
      if (_throw) throw e;
    }

    setState(() {
      downloading = false;
      baseString = Translations.instance!.trans('dbdretry');
    });
  }

  Future<void> downloadFileIOSWith(String target, bool _throw) async {
    Dio dio = Dio();
    int oneMega = 1024 * 1024;
    int nu = 0;
    int latest = 0;
    int tlatest = 0;
    int tnu = 0;

    try {
      var dir = await getDatabasesPath();
      if (await File('$dir/data.db').exists()) {
        await File('$dir/data.db').delete();
      }
      switch (target) {
        case 'latest':
          await SyncManager.checkSyncLatest(_throw);
          break;
        case 'old':
          await SyncManager.checkSyncOld(_throw);
          break;
        default:
          {
            try {
              await downloadFileIOSWith('latest', true);
            } catch (e) {
              await downloadFileIOSWith('old', false);
            }
            return;
          }
      }

      Timer timer = Timer.periodic(
          const Duration(seconds: 1),
          (Timer timer) => setState(() {
                final speed = tlatest / 1024;
                speedString = '${_formatNumberWithComma(speed)} KB/s';
                tlatest = tnu;
                tnu = 0;
              }));
      await dio.download(
          SyncManager.getLatestDB().getDBDownloadUrliOS(widget.dbType!),
          '$dir/data.db', onReceiveProgress: (rec, total) {
        nu += rec - latest;
        tnu += rec - latest;
        latest = rec;
        if (nu <= oneMega) return;

        nu = 0;

        setState(
          () {
            downloading = true;
            final progressPercent = (rec / total) * 100;
            progressString = '${_formatNumberWithComma(progressPercent)}%';
            downString =
                '[${_formatNumberWithComma(rec)}/${_formatNumberWithComma(total)}]';
          },
        );
      });
      timer.cancel();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('db_exists', 1);
      await prefs.setString('databasetype', widget.dbType!);
      await prefs.setString(
          'databasesync', SyncManager.getLatestDB().getDateTime().toString());
      await prefs.setInt('synclatest', SyncManager.getLatestDB().timestamp);

      setState(() {
        downloading = false;
      });

      await DataBaseManager.reloadInstance();

      try {
        if (Settings.useOptimizeDatabase) await deleteUnused();
      } catch (e1, st1) {
        Logger.error('[deleteUnused] E: $e1\n'
            '$st1');
      }
      try {
        await indexing();
      } catch (e1, st1) {
        Logger.error('[indexing] E: $e1\n'
            '$st1');
      }

      if (widget.isSync == true) {
        Navigator.pop(context);
      } else {
        setState(() {
          baseString = Translations.instance!.trans('dbdcomplete');
          _showCloseAppButton = true;
        });
      }

      return;
    } catch (e, st) {
      Logger.error('[DBDownload] E: $e\n'
          '$st');
      if (_throw) throw e;
    }

    setState(() {
      downloading = false;
      baseString = Translations.instance!.trans('dbdretry');
    });
  }

  Future deleteUnused() async {
    var sql = HitomiManager.translate2query(
            '${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim().isNotEmpty).map((e) => '-$e').join(' ')}')
        .replaceAll(' AND ExistOnHitomi=1', '');
    await (await DataBaseManager.getInstance()).delete('HitomiColumnModel',
        'NOT (${sql.substring(sql.indexOf('WHERE') + 6)})', []);
  }

  void insert(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr as String == '') return;
    for (var tag in qr.split('|')) {
      if (tag != '') {
        if (!map.containsKey(tag)) map[tag] = 0;
        map[tag] = map[tag]! + 1;
      }
    }
  }

  void insertSingle(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr as String == '') return;
    if (qr != '') {
      if (!map.containsKey(qr)) map[qr] = 0;
      map[qr] = map[qr]! + 1;
    }
  }

  void tagIndexing(QueryResult item, Map<String, int> tagIndex,
      Map<String, Map<String, int>> tagMap, TagIndexingCallback callback) {
    if (callback(item) == null) return;

    for (var target in callback(item).split('|')) {
      if (target == '') continue;
      if (tagMap.containsKey(target)) continue;

      tagMap[target] = <String, int>{};
    }

    for (var tag in item.tags().split('|')) {
      if (tag == null || tag == '') continue;
      if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;

      var index = tagIndex[tag].toString();
      for (var target in callback(item).split('|')) {
        if (target == '') continue;
        if (!tagMap[target]!.containsKey(index)) {
          tagMap[target]![index] = 0;
        }
        tagMap[target]![index] = tagMap[target]![index]! + 1;
      }
    }
  }

  Future indexing() async {
    QueryManager qm;
    qm = QueryManager.queryPagination('SELECT * FROM HitomiColumnModel');
    qm.itemsPerPage = 50000;

    var tags = <String, int>{};
    var languages = <String, int>{};
    var artists = <String, int>{};
    var groups = <String, int>{};
    var types = <String, int>{};
    var uploaders = <String, int>{};
    var series = <String, int>{};
    var characters = <String, int>{};
    var classes = <String, int>{};

    var tagIndex = <String, int>{};
    var tagArtist = <String, Map<String, int>>{};
    var tagGroup = <String, Map<String, int>>{};
    var tagUploader = <String, Map<String, int>>{};
    var tagSeries = <String, Map<String, int>>{};
    var tagCharacter = <String, Map<String, int>>{};

    var seriesSeries = <String, Map<String, int>>{};
    var seriesCharacter = <String, Map<String, int>>{};

    var characterCharacter = <String, Map<String, int>>{};
    var characterSeries = <String, Map<String, int>>{};

    int i = 0;
    while (true) {
      setState(() {
        baseString = '${Translations.instance!.trans('dbdindexing')}[$i/13]';
      });

      var ll = await qm.next();
      for (var item in ll) {
        insert(tags, item.tags());
        insert(artists, item.artists());
        insert(groups, item.groups());
        insert(series, item.series());
        insert(characters, item.characters());
        insertSingle(languages, item.language());
        insertSingle(types, item.type());
        insertSingle(uploaders, item.uploader());
        insertSingle(classes, item.classname());

        if (item.tags() == null) continue;

        tagIndexing(item, tagIndex, tagArtist, (qr) => qr.artists());
        tagIndexing(item, tagIndex, tagGroup, (qr) => qr.groups());
        tagIndexing(item, tagIndex, tagSeries, (qr) => qr.series());
        tagIndexing(item, tagIndex, tagCharacter, (qr) => qr.characters());

        if (item.uploader() != null) {
          if (!tagUploader.containsKey(item.uploader())) {
            tagUploader[item.uploader()] = <String, int>{};
          }
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            if (!tagUploader[item.uploader()]!.containsKey(index)) {
              tagUploader[item.uploader()]![index] = 0;
            }
            tagUploader[item.uploader()]![index] =
                tagUploader[item.uploader()]![index]! + 1;
          }
        }

        if (item.series() != null && item.characters() != null) {
          for (var series in item.series().split('|')) {
            if (series == '') continue;
            if (!characterSeries.containsKey(series)) {
              characterSeries[series] = <String, int>{};
            }
            for (var character in item.characters().split('|')) {
              if (character == '') continue;
              if (!characterSeries[series]!.containsKey(character)) {
                characterSeries[series]![character] = 0;
              }
              characterSeries[series]![character] =
                  characterSeries[series]![character]! + 1;
            }
          }

          for (var character in item.series().split('|')) {
            if (character == '') continue;
            if (!seriesCharacter.containsKey(character)) {
              seriesCharacter[character] = <String, int>{};
            }
            for (var series in item.characters().split('|')) {
              if (series == '') continue;
              if (!seriesCharacter[character]!.containsKey(series)) {
                seriesCharacter[character]![series] = 0;
              }
              seriesCharacter[character]![series] =
                  seriesCharacter[character]![series]! + 1;
            }
          }
        }

        if (item.series() != null) {
          for (var series in item.series().split('|')) {
            if (series == '') continue;
            if (!seriesSeries.containsKey(series)) {
              seriesSeries[series] = <String, int>{};
            }
            for (var series2 in item.series().split('|')) {
              if (series2 == '' || series == series2) continue;
              if (!seriesSeries[series]!.containsKey(series2)) {
                seriesSeries[series]![series2] = 0;
              }
              seriesSeries[series]![series2] =
                  seriesSeries[series]![series2]! + 1;
            }
          }
        }

        if (item.characters() != null) {
          for (var character in item.characters().split('|')) {
            if (character == '') continue;
            if (!characterCharacter.containsKey(character)) {
              characterCharacter[character] = <String, int>{};
            }
            for (var character2 in item.characters().split('|')) {
              if (character2 == '' || character == character2) continue;
              if (!characterCharacter[character]!.containsKey(character2)) {
                characterCharacter[character]![character2] = 0;
              }
              characterCharacter[character]![character2] =
                  characterCharacter[character]![character2]! + 1;
            }
          }
        }
      }

      if (ll.isEmpty) {
        var index = {
          'tag': tags,
          'artist': artists,
          'group': groups,
          'series': series,
          'lang': languages,
          'type': types,
          'uploader': uploaders,
          'character': characters,
          'class': classes,
        };

        final directory = await getApplicationDocumentsDirectory();
        final path1 = File('${directory.path}/index.json');
        path1.writeAsString(jsonEncode(index));

        final path2 = File('${directory.path}/tag-artist.json');
        path2.writeAsString(jsonEncode(tagArtist));
        final path3 = File('${directory.path}/tag-group.json');
        path3.writeAsString(jsonEncode(tagGroup));
        final path4 = File('${directory.path}/tag-index.json');
        path4.writeAsString(jsonEncode(tagIndex));
        final path5 = File('${directory.path}/tag-uploader.json');
        path5.writeAsString(jsonEncode(tagUploader));
        final path6 = File('${directory.path}/tag-series.json');
        path6.writeAsString(jsonEncode(tagSeries));
        final path7 = File('${directory.path}/tag-character.json');
        path7.writeAsString(jsonEncode(tagCharacter));

        final path8 = File('${directory.path}/character-series.json');
        path8.writeAsString(jsonEncode(characterSeries));
        final path9 = File('${directory.path}/series-character.json');
        path9.writeAsString(jsonEncode(seriesCharacter));
        final path10 = File('${directory.path}/character-character.json');
        path10.writeAsString(jsonEncode(characterCharacter));
        final path11 = File('${directory.path}/series-series.json');
        path11.writeAsString(jsonEncode(seriesSeries));

        setState(() {
          baseString = Translations.instance!.trans('dbdcomplete');
          _showCloseAppButton = true;
        });
        break;
      }
      i++;
    }
  }

  static final _commaFormatter = NumberFormat('#,###.#');

  String _formatNumberWithComma(num param) {
    return _commaFormatter.format(param).replaceAll(' ', '');
  }

  Future<void> _exitApplication() async {
    if (Platform.isAndroid) {
      await PlatformMiscMethods.instance.finishMainActivity();
    } else if (Platform.isIOS) {
      exit(0);
    } else {
      ServicesBinding.instance.exitApplication(AppExitType.required);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (baseString == '') {
      baseString = Translations.of(context).trans('dbdwaitforrequest');
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.of(context).trans('dbdname')),
        backgroundColor: Colors.purple,
      ),
      body: Center(
        child: downloading
            ? SizedBox(
                height: 170.0,
                width: 240.0,
                child: Card(
                  color: Colors.black,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const CircularProgressIndicator(),
                      const SizedBox(
                        height: 20.0,
                      ),
                      Text(
                        "${Translations.of(context).trans('dbddownloading')} $progressString",
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        downString,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        speedString,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      )
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(baseString),
                  if (_showCloseAppButton) ...[
                    const SizedBox(height: 32.0),
                    ElevatedButton(
                      onPressed: _exitApplication,
                      child: Text(Translations.of(context).trans('exitTheApp')),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
