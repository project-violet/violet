import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

//import 'package:connectivity/connectivity.dart';
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
import 'package:violet/dialogs.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_downloader/flutter_downloader.dart';

import '../database.dart';

// class MyViewModel extends ChangeNotifier {
//   double _progress = 0;
//   get downloadProgress => _progress;

//   void startDownloading() async {
//     _progress = null;
//     notifyListeners();

//     // final url =
//     //     'https://github.com/iiccpp/downloader/releases/download/base_database/hitomidata.db';
//     // final request = Request('GET', Uri.parse(url));
//     // final StreamedResponse response = await Client().send(request);

//     // final contentLength = response.contentLength;
//     // // final contentLength = double.parse(response.headers['x-decompressed-content-length']);

//     // _progress = 0;
//     // notifyListeners();

//     // List<int> bytes = [];

//     // final file = await _getFile('song.mp3');
//     // response.stream.listen(
//     //   (List<int> newBytes) {
//     //     bytes.addAll(newBytes);
//     //     final downloadedLength = bytes.length;
//     //     _progress = downloadedLength / contentLength;
//     //     notifyListeners();
//     //   },
//     //   onDone: () async {
//     //     _progress = 0;
//     //     notifyListeners();
//     //     await file.writeAsBytes(bytes);
//     //   },
//     //   onError: (e) {
//     //     print(e);
//     //   },
//     //   cancelOnError: true,
//     // );

//   }

//   Future<File> _getFile(String filename) async {
//     final dir = await getApplicationDocumentsDirectory();
//     return File("${dir.path}/$filename");
//   }
// }

// void main() => runApp(MyApp());

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: Scaffold(
//         appBar: AppBar(title: Text('File download demo')),
//         body: BodyWidget(),
//         backgroundColor: Colors.white,
//       ),
//     );
//   }
// }

// class BodyWidget extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return ViewModelBuilder<MyViewModel>.reactive(
//       viewModelBuilder: () => MyViewModel(),
//       //onModelReady: (model) => model.(),,
//       builder: (context, model, child) => Stack(
//         children: <Widget>[
//           Center(
//             child: SizedBox(
//               width: 100,
//               height: 100,
//               child: CircularProgressIndicator(
//                 strokeWidth: 20,
//                 value: model.downloadProgress,
//               ),
//             ),
//           ),
//           Align(
//             alignment: Alignment.bottomCenter,
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: RaisedButton(
//                 child: Text('Download file'),
//                 onPressed: () {
//                   model.startDownloading();
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() {
    return new MyAppState();
  }
}

class MyAppState extends State<MyApp> {
  final imgUrl =
      "https://github.com/iiccpp/downloader/releases/download/base_database/hitomidata.db";
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

      // HttpClient client = new HttpClient();
      // client
      //     .getUrl(Uri.parse(imgUrl))
      //     .then((HttpClientRequest request) {
      //   // Optionally set up headers...
      //   // Optionally write to the request object...
      //   // Then call close.
      //   return request.close();
      // }).then((HttpClientResponse response) {
      //   // Process the response.
      //   //esponse.re
      // });

      setState(() {
        downloading = false;
        //baseString = "다운로드완료!\n앱을 재실행 해주세요!";
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
        insertSingle(languages, item.language());
        insertSingle(types, item.type());
        insertSingle(uploaders, item.uploader());
      }

      // var sk = tags.keys.toList(growable: true)
      //   ..sort((a, b) => tags[b].compareTo(tags[a]));
      // var sortedMap = new LinkedHashMap.fromIterable(sk,
      //     key: (k) => k, value: (k) => tags[k]);

      if (ll.length == 0) {
        var index = {
          "tags": tags,
          "artists": artists,
          "groups": groups,
          "series": series,
          "languages": languages,
          "types": types,
          "uploaders": uploaders
        };

        final directory = await getExternalStorageDirectory();
        final path = File('${directory.path}/index.json');
        path.writeAsString(jsonEncode(index));

        setState(() {
          baseString = '완료!\n앱을 재실행해 주세요!'; //\n' + jsonEncode(index);
        });
        break;
      }
      i++;
    }
  }

  // ReceivePort _port = ReceivePort();
  // Future<void> downloadFile2() async {
  //   WidgetsFlutterBinding.ensureInitialized();
  //   await FlutterDownloader.initialize(
  //       debug: true // optional: set false to disable printing logs to console
  //       );

  //   FlutterDownloader.registerCallback(downloadCallback);
  //   IsolateNameServer.registerPortWithName(
  //       _port.sendPort, 'downloader_send_port');
  //   _port.listen((dynamic data) {
  //     String id = data[0];
  //     DownloadTaskStatus status = data[1];
  //     int progress = data[2];
  //     setState(() {
  //       downloading = true;
  //       progressString = progress.toString() + "%";
  //     });
  //   });

  //   var dir = await getApplicationDocumentsDirectory();

  //   final taskId = await FlutterDownloader.enqueue(
  //     url: imgUrl,
  //     savedDir: "${dir.path}",
  //     fileName: "db.sql",
  //     showNotification:
  //         true, // show download progress in status bar (for Android)
  //     openFileFromNotification:
  //         true, // click on notification to open downloaded file (for Android)
  //   );

  //   (await SharedPreferences.getInstance()).setInt('db_exists', 1);
  // }

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
