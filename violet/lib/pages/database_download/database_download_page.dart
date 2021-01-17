// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/other/dialogs.dart';
import 'package:dio/dio.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/database_download/decompress.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';
import 'package:violet/version/update_sync.dart';

class DataBaseDownloadPage extends StatefulWidget {
  final bool isExistsDataBase;
  final String dbPath;
  final String dbType;
  final bool isSync;

  DataBaseDownloadPage(
      {this.isExistsDataBase, this.dbPath, this.dbType, this.isSync});

  @override
  DataBaseDownloadPagepState createState() {
    return new DataBaseDownloadPagepState();
  }
}

class DataBaseDownloadPagepState extends State<DataBaseDownloadPage> {
  bool downloading = false;
  var baseString = "";
  var progressString = "";
  var downString = "";
  var speedString = "";

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance
        .addPostFrameCallback((_) async => checkDownload());
  }

  Future checkDownload() async {
    try {
      if ((await SharedPreferences.getInstance()).getInt('db_exists') == 1) {
        if (await File(
                (await SharedPreferences.getInstance()).getString('db_path'))
            .exists())
          await File(
                  (await SharedPreferences.getInstance()).getString('db_path'))
              .delete();
        var dir = await getApplicationDocumentsDirectory();
        if (await Directory('${dir.path}/data').exists())
          await Directory('${dir.path}/data').delete(recursive: true);
      }
    } catch (e) {}

    if (Platform.isAndroid) {
      if (widget.isExistsDataBase) {
        setState(() {
          downloading = false;
          baseString = Translations.instance.trans('dbdcheck');
        });

        if (await DataBaseManager.create(widget.dbPath).test() == false) {
          await Dialogs.okDialog(
              context, Translations.instance.trans('dbdcheckerr'));
          await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          return;
        }

        await (await SharedPreferences.getInstance()).setInt('db_exists', 1);
        await (await SharedPreferences.getInstance())
            .setString('db_path', widget.dbPath);

        await indexing();

        return;
      }
      downloadFileAndroid();
    } else if (Platform.isIOS) {
      // p7zip is not supported on IOS.
      // So, download raw database.
      downloadFileIOS();
    }
  }

  Future<void> downloadFileAndroid() async {
    Dio dio = Dio();
    int _1mb = 1024 * 1024;
    int _nu = 0;
    int latest = 0;
    int _tlatest = 0;
    int _tnu = 0;

    try {
      var dir = await getApplicationDocumentsDirectory();
      if (await File("${dir.path}/db.sql.7z").exists())
        await File("${dir.path}/db.sql.7z").delete();
      Timer _timer = new Timer.periodic(
          Duration(seconds: 1),
          (Timer timer) => setState(() {
                speedString = (_tlatest / 1024).toString() + " KB/S";
                _tlatest = _tnu;
                _tnu = 0;
              }));
      await SyncManager.checkSync();
      await dio.download(
          SyncManager.getLatestDB().getDBDownloadUrl(widget.dbType),
          "${dir.path}/db.sql.7z", onReceiveProgress: (rec, total) {
        _nu += rec - latest;
        _tnu += rec - latest;
        latest = rec;
        if (_nu <= _1mb) return;

        _nu = 0;

        setState(
          () {
            downloading = true;
            progressString = ((rec / total) * 100).toStringAsFixed(0) + "%";
            downString = "[${numberWithComma(rec)}/${numberWithComma(total)}]";
          },
        );
      });
      _timer.cancel();

      setState(() {
        baseString = Translations.instance.trans('dbdunzip');
        print(baseString);
        downloading = false;
      });

      var pp = new P7zip();
      if (await Directory("${dir.path}/data2").exists())
        await Directory("${dir.path}/data2").delete(recursive: true);
      await pp.decompress(["${dir.path}/db.sql.7z"], path: "${dir.path}/data2");
      Variables.databaseDecompressed = true;
      if (await Directory('${dir.path}/data').exists())
        await Directory('${dir.path}/data').delete(recursive: true);
      await Directory("${dir.path}/data2").rename("${dir.path}/data");
      if (await Directory("${dir.path}/data2").exists())
        await Directory("${dir.path}/data2").delete(recursive: true);

      await File("${dir.path}/db.sql.7z").delete();

      await (await SharedPreferences.getInstance()).setInt('db_exists', 1);
      await (await SharedPreferences.getInstance())
          .setString('db_path', "${dir.path}/data/data.db");
      await (await SharedPreferences.getInstance())
          .setString('databasetype', widget.dbType);
      await (await SharedPreferences.getInstance()).setString(
          'databasesync', SyncManager.getLatestDB().getDateTime().toString());
      await (await SharedPreferences.getInstance())
          .setInt('synclatest', SyncManager.getLatestDB().timestamp);

      // await indexing();

      if (widget.isSync != null && widget.isSync == true)
        Navigator.pop(context);
      else
        setState(() {
          baseString = Translations.instance.trans('dbdcomplete');
        });

      return;
    } catch (e) {
      print(e);
    }

    setState(() {
      downloading = false;
      baseString = Translations.instance.trans('dbretry');
    });
  }

  Future<void> downloadFileIOS() async {
    Dio dio = Dio();
    int _1mb = 1024 * 1024;
    int _nu = 0;
    int latest = 0;
    int _tlatest = 0;
    int _tnu = 0;

    try {
      var dir = await getDatabasesPath();
      if (await File("$dir/data.db").exists())
        await File("$dir/data.db").delete();
      Timer _timer = new Timer.periodic(
          Duration(seconds: 1),
          (Timer timer) => setState(() {
                speedString = (_tlatest / 1024).toString() + " KB/S";
                _tlatest = _tnu;
                _tnu = 0;
              }));
      await SyncManager.checkSync();
      await dio.download(
          SyncManager.getLatestDB().getDBDownloadUrliOS(widget.dbType),
          "$dir/data.db", onReceiveProgress: (rec, total) {
        _nu += rec - latest;
        _tnu += rec - latest;
        latest = rec;
        if (_nu <= _1mb) return;

        _nu = 0;

        setState(
          () {
            downloading = true;
            progressString = ((rec / total) * 100).toStringAsFixed(0) + "%";
            downString = "[${numberWithComma(rec)}/${numberWithComma(total)}]";
          },
        );
      });
      _timer.cancel();

      await (await SharedPreferences.getInstance()).setInt('db_exists', 1);
      await (await SharedPreferences.getInstance())
          .setString('db_path', "$dir/data.db");
      await (await SharedPreferences.getInstance())
          .setString('databasetype', widget.dbType);
      await (await SharedPreferences.getInstance()).setString(
          'databasesync', SyncManager.getLatestDB().getDateTime().toString());
      await (await SharedPreferences.getInstance())
          .setInt('synclatest', SyncManager.getLatestDB().timestamp);

      setState(() {
        downloading = false;
      });

      await indexing();

      if (widget.isSync != null && widget.isSync == true)
        Navigator.pop(context);
      else
        setState(() {
          baseString = Translations.instance.trans('dbdcomplete');
        });

      return;
    } catch (e) {
      print(e);
    }

    setState(() {
      downloading = false;
      baseString = Translations.instance.trans('dbretry');
    });
  }

  void insert(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr as String == "") return;
    for (var tag in (qr as String).split('|'))
      if (tag != null && tag != '') {
        if (!map.containsKey(tag)) map[tag] = 0;
        map[tag] += 1;
      }
  }

  void insertSingle(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr as String == "") return;
    var str = qr as String;
    if (str != null && str != '') {
      if (!map.containsKey(str)) map[str] = 0;
      map[str] += 1;
    }
  }

  Future indexing() async {
    QueryManager qm;
    qm = QueryManager.queryPagination('SELECT * FROM HitomiColumnModel');
    qm.itemsPerPage = 50000;

    var tags = Map<String, int>();
    var languages = Map<String, int>();
    var artists = Map<String, int>();
    var groups = Map<String, int>();
    var types = Map<String, int>();
    var uploaders = Map<String, int>();
    var series = Map<String, int>();
    var characters = Map<String, int>();
    var classes = Map<String, int>();

    var tagIndex = Map<String, int>();
    var tagArtist = Map<String, Map<String, int>>();
    var tagGroup = Map<String, Map<String, int>>();
    var tagUploader = Map<String, Map<String, int>>();
    var tagSeries = Map<String, Map<String, int>>();
    var tagCharacter = Map<String, Map<String, int>>();

    var seriesSeries = Map<String, Map<String, int>>();
    var seriesCharacter = Map<String, Map<String, int>>();

    var characterCharacter = Map<String, Map<String, int>>();
    var characterSeries = Map<String, Map<String, int>>();

    int i = 0;
    while (true) {
      setState(() {
        baseString = Translations.instance.trans('dbdindexing') + '[$i/13]';
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

        if (item.artists() != null) {
          for (var artist in item.artists().split('|'))
            if (artist != '') if (!tagArtist.containsKey(artist))
              tagArtist[artist] = Map<String, int>();
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.artists().split('|')) {
              if (artist == '') continue;
              if (!tagArtist[artist].containsKey(index))
                tagArtist[artist][index] = 0;
              tagArtist[artist][index] += 1;
            }
          }
        }

        if (item.groups() != null) {
          for (var artist in item.groups().split('|'))
            if (artist != '') if (!tagGroup.containsKey(artist))
              tagGroup[artist] = Map<String, int>();
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.groups().split('|')) {
              if (artist == '') continue;
              if (!tagGroup[artist].containsKey(index))
                tagGroup[artist][index] = 0;
              tagGroup[artist][index] += 1;
            }
          }
        }

        if (item.uploader() != null) {
          if (!tagUploader.containsKey(item.uploader()))
            tagUploader[item.uploader()] = Map<String, int>();
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            if (!tagUploader[item.uploader()].containsKey(index))
              tagUploader[item.uploader()][index] = 0;
            tagUploader[item.uploader()][index] += 1;
          }
        }

        if (item.series() != null) {
          for (var artist in item.series().split('|'))
            if (artist != '') if (!tagSeries.containsKey(artist))
              tagSeries[artist] = Map<String, int>();
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.series().split('|')) {
              if (artist == '') continue;
              if (!tagSeries[artist].containsKey(index))
                tagSeries[artist][index] = 0;
              tagSeries[artist][index] += 1;
            }
          }
        }

        if (item.characters() != null) {
          for (var artist in item.characters().split('|'))
            if (artist != '') if (!tagCharacter.containsKey(artist))
              tagCharacter[artist] = Map<String, int>();
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag)) tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.characters().split('|')) {
              if (artist == '') continue;
              if (!tagCharacter[artist].containsKey(index))
                tagCharacter[artist][index] = 0;
              tagCharacter[artist][index] += 1;
            }
          }
        }

        if (item.series() != null && item.characters() != null) {
          for (var series in item.series().split('|')) {
            if (series == '') continue;
            if (!characterSeries.containsKey(series))
              characterSeries[series] = Map<String, int>();
            for (var character in item.characters().split('|')) {
              if (character == '') continue;
              if (!characterSeries[series].containsKey(character))
                characterSeries[series][character] = 0;
              characterSeries[series][character] += 1;
            }
          }

          for (var character in item.series().split('|')) {
            if (character == '') continue;
            if (!seriesCharacter.containsKey(character))
              seriesCharacter[character] = Map<String, int>();
            for (var series in item.characters().split('|')) {
              if (series == '') continue;
              if (!seriesCharacter[character].containsKey(series))
                seriesCharacter[character][series] = 0;
              seriesCharacter[character][series] += 1;
            }
          }
        }

        if (item.series() != null) {
          for (var series in item.series().split('|')) {
            if (series == '') continue;
            if (!seriesSeries.containsKey(series))
              seriesSeries[series] = Map<String, int>();
            for (var series2 in item.series().split('|')) {
              if (series2 == '' || series == series2) continue;
              if (!seriesSeries[series].containsKey(series2))
                seriesSeries[series][series2] = 0;
              seriesSeries[series][series2] += 1;
            }
          }
        }

        if (item.characters() != null) {
          for (var character in item.characters().split('|')) {
            if (character == '') continue;
            if (!characterCharacter.containsKey(character))
              characterCharacter[character] = Map<String, int>();
            for (var character2 in item.characters().split('|')) {
              if (character2 == '' || series == character2) continue;
              if (!characterCharacter[character].containsKey(character2))
                characterCharacter[character][character2] = 0;
              characterCharacter[character][character2] += 1;
            }
          }
        }
      }

      if (ll.length == 0) {
        var index = {
          "tag": tags,
          "artist": artists,
          "group": groups,
          "series": series,
          "lang": languages,
          "type": types,
          "uploader": uploaders,
          "character": characters,
          "class": classes,
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
          baseString = Translations.instance.trans('dbdcomplete');
        });
        break;
      }
      i++;
    }
  }

  String numberWithComma(int param) {
    return new NumberFormat('###,###,###,###')
        .format(param)
        .replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    if (baseString == '')
      baseString = Translations.of(context).trans('dbdwaitforrequest');
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.of(context).trans('dbdname')),
        backgroundColor: Colors.purple,
      ),
      body: Center(
        child: downloading
            ? Container(
                height: 170.0,
                width: 240.0,
                child: Card(
                  color: Colors.black,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(
                        height: 20.0,
                      ),
                      Text(
                        "${Translations.of(context).trans('dbddownloading')} $progressString",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        downString ?? '',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        speedString ?? '',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      )
                    ],
                  ),
                ),
              )
            : Text(baseString ?? ''),
      ),
    );
  }
}
