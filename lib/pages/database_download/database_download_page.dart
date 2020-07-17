// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

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
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/dialogs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/database_download/decompress.dart';
import 'package:violet/update_sync.dart';

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
    downloadFile();
  }

  Future<void> downloadFile() async {
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
      await dio.download(UpdateSyncManager.rawlangDB[widget.dbType].item2,
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
      await (await SharedPreferences.getInstance()).setString('databasesync',
          UpdateSyncManager.rawlangDB[widget.dbType].item1.toString());

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

        final path2 = File('${directory.path}/tag_artist.json');
        path2.writeAsString(jsonEncode(tagArtist));
        final path3 = File('${directory.path}/tag_group.json');
        path3.writeAsString(jsonEncode(tagGroup));
        final path4 = File('${directory.path}/tag_index.json');
        path4.writeAsString(jsonEncode(tagIndex));
        final path5 = File('${directory.path}/tag_uploader.json');
        path5.writeAsString(jsonEncode(tagUploader));

        setState(() {
          baseString = Translations.instance.trans('dbdcomplete');
        });
        break;
      }
      i++;
    }
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
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
                        downString,
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        speedString,
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      )
                    ],
                  ),
                ),
              )
            : Text(baseString),
      ),
    );
  }
}
