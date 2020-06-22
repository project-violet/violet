// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/database.dart';
import 'package:violet/dialogs.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_downloader/flutter_downloader.dart';

class DataBaseDownloadPage extends StatefulWidget {
  @override
  DataBaseDownloadPagepState createState() {
    return new DataBaseDownloadPagepState();
  }
}

class DataBaseDownloadPagepState extends State<DataBaseDownloadPage> {
  final imgUrl =
      "https://github.com/violet-dev/db/releases/download/2020.06.20/hitomidata.db";
  bool downloading = false;
  var baseString = "요청을 기다리는 중...";
  var progressString = "";
  var downString = "";
  var speedString = "";

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance
        .addPostFrameCallback((_) async => checkDownload());
    //downloadFile();
  }

  Future checkDownload() async {
    try {
      if ((await SharedPreferences.getInstance()).getInt('db_exists') == 1) {
        setState(() {
          downloading = false;
          baseString = "오류! 개발자에게 문의하세요";
        });
        return;
      }
    } catch (e) {}

    if (await Dialogs.yesnoDialog(context, '미리 다운로드해둔 데이터베이스가 있나요?') == true) {
      File file;
      file = await FilePicker.getFile(
        type: FileType.any,
        //allowedExtensions: ['db'],
      );

      if (file == null) {
        await Dialogs.okDialog(context, '오류! 선택된 파일이 없습니다!\n재시도해주세요.');
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        return;
      }

      setState(() {
        downloading = false;
        baseString = "데이터베이스 확인중...";
      });

      if (await DataBaseManager.create(file.path).test() == false) {
        await Dialogs.okDialog(
            context, '데이터베이스 파일이 아니거나 파일이 손상되었습니다!\n다시시도 해주세요!');
        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        return;
      }

      await (await SharedPreferences.getInstance()).setInt('db_exists', 1);
      await (await SharedPreferences.getInstance())
          .setString('db_path', file.path);

      await indexing();

      //setState(() {
      //  downloading = false;
      //  baseString = "완료!\n앱을 재실행 해주세요!";
      //});
      return;
    }

    if (await Dialogs.yesnoDialog(
            context, '데이터베이스 약 314MB를 다운로드해야 합니다. 다운로드할까요?') ==
        true) {
      //var connectivityResult = await (Connectivity().checkConnectivity());

      //if (connectivityResult == ConnectivityResult.mobile) {}

      downloadFile();
    } else {
      await Dialogs.okDialog(context, '데이터베이스가 없으면 계속할 수 없습니다.');
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
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
      Timer _timer = new Timer.periodic(
          Duration(seconds: 1),
          (Timer timer) => setState(() {
                speedString = (_tlatest / 1024).toString() + " KB/S";
                _tlatest = _tnu;
                _tnu = 0;
              }));
      await dio.download(imgUrl, "${dir.path}/db.sql",
          onReceiveProgress: (rec, total) {
        //print("Rec: $rec , Total: $total, Nu: $_nu");

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
        downloading = false;
      });

      await (await SharedPreferences.getInstance()).setInt('db_exists', 1);
      await (await SharedPreferences.getInstance())
          .setString('db_path', "${dir.path}/db.sql");

      await indexing();

      return;
    } catch (e) {
      print(e);
    }

    setState(() {
      downloading = false;
      baseString = "인터넷 연결을 확인하고 재시도해주세요!";
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

    int i = 0;
    while (true) {
      setState(() {
        baseString = '인덱싱 작업중... 작업수 [$i/13]';
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
            if (!tagArtist.containsKey(artist))
              tagArtist[artist] = Map<String, int>();
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag))
              tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.artists().split('|')) {
              if (!tagArtist[artist].containsKey(index))
                tagArtist[artist][index] = 0;
              tagArtist[artist][index] += 1;
            }
          }
        }

        if (item.groups() != null) {
          for (var artist in item.groups().split('|'))
            if (!tagGroup.containsKey(artist))
              tagGroup[artist] = Map<String, int>();
          for (var tag in item.tags().split('|')) {
            if (tag == null || tag == '') continue;
            if (!tagIndex.containsKey(tag))
              tagIndex[tag] = tagIndex.length;
            var index = tagIndex[tag].toString();
            for (var artist in item.groups().split('|')) {
              if (!tagGroup[artist].containsKey(index))
                tagGroup[artist][index] = 0;
              tagGroup[artist][index] += 1;
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
        
        final path2 = File('${directory.path}/tag_artist.json');
        path2.writeAsString(jsonEncode(tagArtist));
        final path3 = File('${directory.path}/tag_group.json');
        path3.writeAsString(jsonEncode(tagGroup));
        final path4 = File('${directory.path}/tag_index.json');
        path4.writeAsString(jsonEncode(tagIndex));

        setState(() {
          baseString = '완료!\n앱을 재실행해 주세요!'; //\n' + jsonEncode(index);
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
    return Scaffold(
      appBar: AppBar(
        title: Text("데이터베이스 다운로더"),
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
                        "다운로드 중... $progressString",
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
