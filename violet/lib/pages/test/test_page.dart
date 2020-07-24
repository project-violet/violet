// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flare_dart/math/mat2d.dart';
import 'package:flare_flutter/flare.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/statistics.dart';
import 'package:violet/component/hitomi/title_cluster.dart';
import 'package:violet/component/hiyobi/hiyobi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/files.dart';
import 'package:violet/other/flare_artboard.dart';
import 'package:violet/pages/database_download/decompress.dart';
import 'package:violet/update_sync.dart';
import 'package:violet/pages/viewer/vertical_viewer_widget.dart';
import 'package:flutter_sidekick/flutter_sidekick.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;

class TestPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text('개발 도구 모음'),
        ),
        body: Center(
          child: Wrap(
            // mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            spacing: 8,
            runAlignment: WrapAlignment.center,
            children: <Widget>[
              RaisedButton(
                child: Text('데이터베이스 SQL Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => SqlTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('Signification Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => SignTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('인덱싱 Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => IndexingTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('이미지 Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => ImageTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('애니메이션 Test'),
                // child: Fireworks(),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => AnimationTestPage(
                        title: '애니메이션 Test',
                      ),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('검색 Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => SearchTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('Flare Hero Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => FlareHeroTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('Scroll Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => ScrollTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('Silver Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => SilverTestPage(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('Clustering Test'),
                onPressed: () async {
                  var qq = await (await DataBaseManager.getInstance()).query(
                      'SELECT * FROM HitomiColumnModel WHERE Artists LIKE "%michiking|%" ' +
                          'AND Language="korean" ORDER BY Id DESC LIMIT 150 OFFSET 0');
                  var titles = qq
                      .map((e) => QueryResult(result: e).title() as String)
                      .toList();
                  print(titles);
                  HitomiTitleCluster.doClustering(titles);
                },
              ),
              RaisedButton(
                child: Text('File Test'),
                onPressed: () {
                  Files.enumerate();
                },
              ),

              RaisedButton(
                child: Text('Hiyobi Test'),
                onPressed: () async {
                  print(await HiyobiManager.getImageList('1678359'));
                },
              ),

              RaisedButton(
                child: Text('Exhentai Test'),
                onPressed: () async {
                  var qq = await (await DataBaseManager.getInstance()).query(
                      'SELECT * FROM HitomiColumnModel WHERE Id=1678043' +
                          ' ORDER BY Id DESC LIMIT 1 OFFSET 0');
                  var qr = QueryResult(result: qq.first);
                  var ss = HentaiManager.exHentaiStream(
                      QueryResult(result: qq.first));

                  // for (int i = 0; i < (qr.files() as int); i++) {
                  //     print(element);
                  //   // print(ss.)
                  // }
                },
              ),

              RaisedButton(
                child: Text('Update Test'),
                onPressed: () async {
                  await UpdateSyncManager.checkUpdateSync();
                },
              ),
              RaisedButton(
                child: Text('Init Latest Database'),
                onPressed: () async {
                  // var dir = await getApplicationDocumentsDirectory();
                  // if (await Directory('${dir.path}/data').exists()) {
                  //   print('asdf');
                  //   await Directory('${dir.path}/data').delete(recursive: true);
                  // }
                  await (await SharedPreferences.getInstance())
                      .setString('databasesync', '20000101');
                },
              ),
              // RaisedButton(
              //   // child: Fireworks(),
              //   onPressed: () {
              //     print(Colors.black.toString());
              //   },
              // ),
              RaisedButton(
                child: Text('Parsing Test'),
                onPressed: () async {
                  // var res = await http.get('https://e-hentai.org/g/1660354/a75db0c661/');
                  // EHParser.getImagesUrl(res.body);
                  // var res = await http.get('https://e-hentai.org/s/f0a5929ebf/1660354-3');
                  // print(EHParser.getImagesAddress(res.body));
                  // var res = await http.get('https://e-hentai.org/g/1201400/48f9b8e20a/');
                  //  print(EHParser.getPagesUrl(res.body).length);
                  // print(EHParser.parseArticleData(res.body).comment);
                  var res = await http.get('https://e-hentai.org/',
                      headers: {'Cookie': 'sl=dm_2'});
                  print(EHParser.parseReulstPageExtendedListView(res.body)
                      .length);
                  EHParser.parseReulstPageExtendedListView(res.body)
                      .forEach((element) {
                    print(element.thumbnail);
                  });
                },
              ),
              RaisedButton(
                child: Text('DateTime Estimate Test'),
                onPressed: () async {
                  print(HitomiStatistics.estimateDateTime(1666884));
                },
              ),
              RaisedButton(
                child: Text('DPI Bypass Test'),
                onPressed: () async {
                  await VpnTest.asdf();
                },
              ),
              RaisedButton(
                child: Text('Unzip Test'),
                onPressed: () async {
                  var dir = await getApplicationDocumentsDirectory();
                  if (await Directory('${dir.path}/data2').exists())
                    await Directory('${dir.path}/data2')
                        .delete(recursive: true);
                  var pp = new P7zip();
                  await pp.decompress(["${dir.path}/db.sql.7z"],
                      path: "${dir.path}/data2");
                  print('asdf');
                },
              ),
              RaisedButton(
                child: Text('Raw Data Sync Test'),
                onPressed: () async {
                  var link =
                      'https://violet-test-4b8cd3e.s3.ap-northeast-2.amazonaws.com/rawdata-english.7z';
                  var ll =
                      'https://violet-test-4b8cd3e.s3.ap-northeast-2.amazonaws.com/tag-uploader.7z';

                  var dir = await getApplicationDocumentsDirectory();
                  // File('${dir.path}/rawdata-english.7z').deleteSync();
                  // File('${dir.path}/index.json').deleteSync();
                  // File('${dir.path}/tag_artist.json').deleteSync();
                  // File('${dir.path}/tag_group.json').deleteSync();
                  // File('${dir.path}/tag_uploader.json').deleteSync();
                  // File('${dir.path}/tag_index.json').deleteSync();
                  // Directory("${dir.path}/data").createSync();
                  print(dir.path);
                  Files.enumeratePath(dir.path);
                  // return;
                  // Dio dio = Dio();
                  // await dio.download(ll, "${dir.path}/tag-upload.7z",
                  //     onReceiveProgress: (rec, total) {
                  //   print(rec);
                  // });
                  // var pp = new P7zip();
                  // await pp.decompress(["${dir.path}/rawdata-english.7z"],
                  //     path: "${dir.path}/data");
                  // print(dir.path);
                  // Files.enumeratePath(dir.path);
                  return;

                  // bool once = false;
                  // IsolateNameServer.registerPortWithName(
                  //     _port.sendPort, 'downloader_send_port');
                  // _port.listen((dynamic data) {
                  //   String id = data[0];
                  //   DownloadTaskStatus status = data[1];
                  //   int progress = data[2];
                  //   print(progress);
                  //   if (progress == 100 && !once) {
                  //     once = true;
                  //   }
                  // });

                  // FlutterDownloader.registerCallback(downloadCallback);
                  // final taskId = await FlutterDownloader.enqueue(
                  //   url: link,
                  //   savedDir: '${dir.path}',
                  //   showNotification:
                  //       true, // show download progress in status bar (for Android)
                  //   openFileFromNotification:
                  //       true, // click on notification to open downloaded file (for Android)
                  // );
                },
              ),
              RaisedButton(
                child: Text('Image Cache Clear'),
                onPressed: () {
                  DefaultCacheManager().emptyCache();
                  imageCache.clear();
                },
              ),
              RaisedButton(
                child: Text('User DB Clear'),
                onPressed: () async {
                  var dir = await getApplicationDocumentsDirectory();
                  File('${dir.path}/user.db').deleteSync();
                },
              ),
              RaisedButton(
                child: Text('SystemUiOverlay Test'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => GeneratedCouponScreen(),
                    ),
                  );
                },
              ),
              RaisedButton(
                child: Text('Get Test'),
                onPressed: () async {
                  var articles = (await (await DataBaseManager.getInstance()).query(
                          "SELECT * FROM HitomiColumnModel WHERE Id=1685671 ORDER BY Id DESC LIMIT 1 OFFSET 0"))
                      .map((e) => QueryResult(result: e))
                      .toList();

                  print(articles[0].result.toString());
                },
              ),
              // RaisedButton(
              //   child: Text('Unzip Test'),
              //   onPressed: () async {
              //     try {
              //       File file;
              //       file = await FilePicker.getFile(
              //         type: FileType.any,
              //         // allowedExtensions: ['db'],
              //       // );
              //       // var pp = new P7zip();
              //       // await pp.compress([file.path], path: file.parent.path);
              //     } catch (e) {
              //       print(e);
              //     }
              //   },
              // ),
              Container(
                height: 10,
              ),
              Text('Project Violet은 Closed Source입니다.'),
              Text('Copyright (C) 2020 by dc-koromo'),
            ],
          ),
        ),
      ),
    );
  }

  ReceivePort _port = ReceivePort();

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }
}

class SqlTestPage extends StatefulWidget {
  @override
  _SqlTestPageState createState() => _SqlTestPageState();
}

class _SqlTestPageState extends State<SqlTestPage> {
  TextEditingController textEditingController = new TextEditingController();
  TextEditingController textEditingController1 = new TextEditingController();
  DataBaseManager latest;
  String status = "대기중";

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text('데이터베이스 SQL 테스트'),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Container(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: TextField(
                    minLines: 1,
                    maxLines: 15,
                    autocorrect: false,
                    controller: textEditingController,
                    decoration: InputDecoration(
                      hintText: 'SQL 구문 입력',
                      filled: true,
                      fillColor: Colors.orange.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.0),
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      child: RaisedButton(
                        child: Text('Test Simple'),
                        onPressed: () {
                          setState(() {
                            textEditingController.text =
                                "SELECT * FROM HitomiColumnModel\nWHERE Tags LIKE '%female:ahegao|%' AND\nTags NOT LIKE '%feamle:big breasts|%'\nORDER BY Id DESC LIMIT 10 OFFSET 20";
                          });
                        },
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      child: RaisedButton(
                        child: Text('Test Medium'),
                        onPressed: () {
                          setState(() {
                            textEditingController.text =
                                "SELECT Uploader, count(*) as c FROM HitomiColumnModel GROUP BY Uploader ORDER BY c DESC LIMIT 10 OFFSET 1";
                          });
                        },
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      child: RaisedButton(
                        child: Text('Test Slow'),
                        onPressed: () {
                          setState(() {
                            textEditingController.text =
                                "SELECT Uploader, count(*) as c FROM HitomiColumnModel GROUP BY Uploader ORDER BY c DESC LIMIT 10 OFFSET 1";
                          });
                        },
                      ),
                    ),
                    Container(
                      //margin: EdgeInsets.only(right: 4),
                      child: RaisedButton(
                        child: Text('실행'),
                        onPressed: () async {
                          try {
                            setState(() {
                              status = '쿼리중...';
                            });
                            var dt = DateTime.now();
                            latest = await DataBaseManager.getInstance();
                            var text =
                                await latest.query(textEditingController.text);

                            //var text =
                            //    (await (await DataBaseManager.getInstance())
                            //        .query(textEditingController.text));

                            JsonEncoder encoder =
                                new JsonEncoder.withIndent('  ');
                            String prettyprint = encoder.convert(text);
                            setState(() {
                              textEditingController1.text = prettyprint;
                              status = '쿼리 완료 ' +
                                  (DateTime.now()
                                              .difference(dt)
                                              .inMilliseconds /
                                          1000)
                                      .toString() +
                                  '초';
                            });
                          } on Exception catch (e) {
                            setState(() {
                              textEditingController1.text = e.toString();
                              status = '쿼리 오류';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                  margin: EdgeInsets.fromLTRB(20, 8, 0, 0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [Text(status)])),
              Container(
                margin: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: TextField(
                  //readOnly: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  controller: textEditingController1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignTestPage extends StatefulWidget {
  @override
  _SignTestPageState createState() => _SignTestPageState();
}

class _SignTestPageState extends State<SignTestPage> {
  @override
  Widget build(BuildContext context) {
    double c_width = MediaQuery.of(context).size.width * 1 - 40;

    return Container(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text('서명 테스트'),
        ),
        body: SingleChildScrollView(
            child: Column(
          children: <Widget>[
            Container(
              margin: EdgeInsets.fromLTRB(20, 10, 0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: c_width,
                    child: new Column(
                      children: <Widget>[
                        new Text(
                            "Project Violet은 내부적으로 앱 실행 때마다 네트워크를 통해 업데이트될 수 있는 커스텀 스크립트를 사용합니다."
                            "따라서 불분명한 스크립트 실행을 방지하기위함으로 비대칭키를 통해 스크립트의 서명을 확인합니다.",
                            textAlign: TextAlign.left),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        )),
      ),
    );
  }
}

class IndexingTestPage extends StatefulWidget {
  @override
  _IndexingTestPageState createState() => _IndexingTestPageState();
}

class _IndexingTestPageState extends State<IndexingTestPage> {
  QueryManager qm;
  String status = "";

  _IndexingTestPageState() {
    qm = QueryManager.queryPagination('SELECT * FROM HitomiColumnModel');
    qm.itemsPerPage = 50000;
    SchedulerBinding.instance.addPostFrameCallback((_) async => await update());
  }

  Future update() async {
    int i = 0;
    Map<String, int> tags = Map<String, int>();
    while (true) {
      //qm.curPage = 0;
      //sleep(Duration(seconds: 1));
      //await Future.delayed(Duration(seconds: 1));

      var ll = await qm.next();
      for (var item in ll) {
        if (item.tags() == null) continue;
        if (item.tags() as String == "") continue;
        for (var tag in (item.tags() as String).split('|'))
          if (tag != null && tag != '') {
            if (!tags.containsKey(tag)) tags[tag] = 0;
            tags[tag] += 1;
          }
      }

      var sk = tags.keys.toList(growable: true)
        ..sort((a, b) => tags[b].compareTo(tags[a]));
      var sortedMap = new LinkedHashMap.fromIterable(sk,
          key: (k) => k, value: (k) => tags[k]);

      if (ll.length == 0) {
        setState(() {
          status = '작업완료\n' + sortedMap.toString();
        });
        break;
      }
      i++;
      setState(() {
        status = '작업수 $i번\n' + sortedMap.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Scaffold(
        appBar: AppBar(
          title: Text('인덱싱 테스트'),
          backgroundColor: Colors.orange,
        ),
        body: SingleChildScrollView(
          child: Container(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[Text(status)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ImageTestPage extends StatefulWidget {
  @override
  _ImageTestPageState createState() => _ImageTestPageState();
}

class _ImageTestPageState extends State<ImageTestPage> {
  // VoidCallback openDialog(BuildContext context, String url, String refer) =>
  //     () {
  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           return Dialog(
  //             child: Container(
  //               child: PhotoView(
  //                 tightMode: true,
  //                 minScale: 0.1,
  //                 imageProvider: NetworkImage(
  //                   url,
  //                   headers: {
  //                     "Referer": "https://hitomi.la/reader/16440821.html/"
  //                   },
  //                 ),
  //                 heroAttributes: PhotoViewHeroAttributes(tag: url),
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //       //print('x');
  //       //showDialog(context: context, child: Dialog(child: Container(child: Text('asdf'),),));
  //     };

  // List<GalleryExampleItem> galleryItems;
  // List<GlobalKey> moveKey;

  // void open(BuildContext context, final int index) async {
  //   var w = GalleryPhotoViewWrapper(
  //     galleryItems: galleryItems,
  //     backgroundDecoration: const BoxDecoration(
  //       color: Colors.black,
  //     ),
  //     minScale: 2.0,
  //     maxScale: 4.0,
  //     totalPage: galleryItems.length,
  //     initialIndex: index,
  //     scrollDirection: Axis.horizontal,
  //   );
  //   await Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => w),
  //   );
  //   // 지금 인덱스랑 다르면 그쪽으로 이동시킴
  //   if (w.currentIndex != index)
  //     Scrollable.ensureVisible(moveKey[w.currentIndex].currentContext,
  //         alignment: 0.5);
  // }

  @override
  Widget build(BuildContext context) {
    var imgs = [
      //'https://aa.hitomi.la/webp/a/c0/1b955264f25fb240e84a2a227452a38e2980eedd12e6e6dfee0c72b06eedcc0a.webp',
      //'https://ba.hitomi.la/webp/e/7f/ec2c31db322578533e8d71d02a3364d9ca8bc75fb77230db3165d8f4731db7fe.webp',
      //'https://aa.hitomi.la/webp/d/b7/efd83a507953f7252931098791c9a85a315c327e593d83174e10c3a3c300bb7d.webp',
      //'https://ca.hitomi.la/webp/c/f5/70304459b4890da62c0b8a2b92dbf8a619a81015a1fcc192b33f0fda1a798f5c.webp',
      'https://i.imgur.com/V4W5OYF.jpg',
      'https://cdn.mos.cms.futurecdn.net/42E9as7NaTaAi4A6JcuFwG-650-80.jpg',
      'https://images.indianexpress.com/2019/12/banana_759-1.jpg',
      'https://media.nationalgeographic.org/assets/photos/218/954/a4b922dc-def3-4a5d-a6e0-ab5dce621fc2.jpg',
      'https://www.raisingarizonakids.com/wp-content/uploads/2019/08/SariScience-Bananas.jpg',
      'https://www.thespruceeats.com/thmb/k6XNwcfk3IAMfBoBMGAJ4aPLOb4=/960x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/vegan-chocolate-peanut-butter-banana-smoothie-1000994-bananas-cropped-e4bdab5174cf461baf30bcdb8193c3e0.jpg',
      //'https://image.dcinside.com/viewimage.php?id=3dafdf21f7d335ab67b1d1&no=24b0d769e1d32ca73ded81fa11d02831ecb95a6124af73c1834c571bf8e46ae03d8dbf637738d1d3e75b72a95475652892a6b1b3789c1da73058f9c7064ca30e47a2'
      //'https://aa.hitomi.la/webp/a/c0/1b955264f25fb240e84a2a227452a38e2980eedd12e6e6dfee0c72b06eedcc0a.webp',
      //'https://ba.hitomi.la/webp/e/7f/ec2c31db322578533e8d71d02a3364d9ca8bc75fb77230db3165d8f4731db7fe.webp',
      //'https://aa.hitomi.la/webp/d/b7/efd83a507953f7252931098791c9a85a315c327e593d83174e10c3a3c300bb7d.webp',
      //'https://aa.hitomi.la/webp/a/c0/1b955264f25fb240e84a2a227452a38e2980eedd12e6e6dfee0c72b06eedcc0a.webp',
    ];

    //var imgs = Future.wait(HitomiManager.getImageList('991015'));

    // List<Widget> ww = List<Widget>();
    // galleryItems = new List<GalleryExampleItem>();
    // moveKey = new List<GlobalKey>();
    // int i = 0;
    // for (var l in imgs) {
    //   galleryItems.add(GalleryExampleItem(
    //       id: l,
    //       url: l,
    //       headers: {"Referer": "https://hitomi.la/reader/16440821.html/"}));
    //   moveKey.add(new GlobalKey());
    //   int j = i;
    //   ww.add(
    //     Container(
    //       padding: EdgeInsets.all(2),
    //       decoration: BoxDecoration(
    //         color: const Color(0xff444444),
    //         // boxShadow: [
    //         //   BoxShadow(
    //         //     color: Colors.grey.withOpacity(0.9),
    //         //     spreadRadius: 5,
    //         //     blurRadius: 7,
    //         //     offset: Offset(0, 3), // changes position of shadow
    //         //   ),
    //         // ],
    //       ),
    //       child: GalleryExampleItemThumbnail(
    //         galleryExampleItem: galleryItems[j],
    //         onTap: () {
    //           print(j);
    //           open(context, j);
    //         },
    //         key: moveKey[j],
    //       ),
    //     ),
    //   );
    //   i++;
    // }
    //ww.add(Container(
    //  child: InkWell(
    //    onTap: () {
    //      //print('a');
    //      //openDialog(context, l, "https://hitomi.la/reader/16440821.html/")();{
    //      Navigator.push(
    //        context,
    //        MaterialPageRoute(
    //          builder: (context) => HeroPhotoViewWrapper(
    //            tag: l,
    //            imageProvider: NetworkImage(l, headers: {
    //              "Referer": "https://hitomi.la/reader/16440821.html/"
    //            }),
    //          ),
    //        ),
    //      );
    //    },
    //    child: Hero(
    //      tag: l,
    //      child: Image.network(
    //        l,
    //        headers: {"Referer": "https://hitomi.la/reader/16440821.html/"},
    //      ),
    //    ),
    //  ),
    //));
    // ww.add(Container(
    //     child: ExtendedImage.network(l,
    //         headers: {"Referer": "https://hitomi.la/reader/16440821.html/"},
    //         fit: BoxFit.fill,
    //         //enableLoadState: false,
    //         mode: ExtendedImageMode.gesture,
    //         initGestureConfigHandler: (state) {
    //   return GestureConfig(
    //     minScale: 1,
    //     animationMinScale: 0.9,
    //     maxScale: 3.0,
    //     animationMaxScale: 3.5,
    //     speed: 1.0,
    //     inertialSpeed: 100.0,
    //     initialScale: 1.0,
    //     inPageView: true,
    //     initialAlignment: InitialAlignment.center,

    //   );
    // },
    // )));
    // ww.add(Container(
    //   child: PhotoView(
    //     imageProvider: NetworkImage(
    //       l,
    //       headers: {"Referer": "https://hitomi.la/reader/16440821.html/"},
    //     ),
    //   ),
    // ));

    return Container(
      child: Scaffold(
        appBar: AppBar(
          title: Text('이미지 테스트'),
          backgroundColor: Colors.orange,
        ),
        body: ViewerWidget(
          id: "",
          urls: imgs,
          headers: {"Referer": "https://hitomi.la/reader/16440821.html/"},
        ),
        //Scrollbar(
        //  child: SingleChildScrollView(
        //    child: Container(
        //      child: Center(
        //        child: Column(
        //          mainAxisAlignment: MainAxisAlignment.center,
        //          children: ww,
        //        ),
        //      ),
        //    ),
        //  ),
        //),
      ),
    );
  }
}

// class HeroPhotoViewWrapper extends StatelessWidget {
//   const HeroPhotoViewWrapper({
//     this.imageProvider,
//     this.loadingBuilder,
//     this.backgroundDecoration,
//     this.minScale,
//     this.maxScale,
//     this.tag,
//   });

//   final ImageProvider imageProvider;
//   final LoadingBuilder loadingBuilder;
//   final Decoration backgroundDecoration;
//   final dynamic minScale;
//   final dynamic maxScale;
//   final String tag;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       constraints: BoxConstraints.expand(
//         height: MediaQuery.of(context).size.height,
//       ),
//       child: PhotoView(
//         imageProvider: imageProvider,
//         loadingBuilder: loadingBuilder,
//         backgroundDecoration: backgroundDecoration,
//         minScale: minScale,
//         maxScale: maxScale,
//         heroAttributes: PhotoViewHeroAttributes(tag: tag),
//       ),
//     );
//   }
// }

// class GalleryExampleItem {
//   GalleryExampleItem({this.id, this.url, this.headers, this.isSvg = false});

//   final String id;
//   final String url;
//   final Map<String, String> headers;
//   final bool isSvg;
// }

// class GalleryExampleItemThumbnail extends StatelessWidget {
//   const GalleryExampleItemThumbnail(
//       {Key key, this.galleryExampleItem, this.onTap})
//       : super(key: key);

//   final GalleryExampleItem galleryExampleItem;

//   final GestureTapCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       //padding: const EdgeInsets.symmetric(horizontal: 5.0),
//       child: GestureDetector(
//         onTap: onTap,
//         child: Hero(
//           tag: galleryExampleItem.id.toString(),
//           child:
//           //CachedNetworkImage(
//           //  imageUrl: galleryExampleItem.url,
//           //  httpHeaders: galleryExampleItem.headers,
//           //  placeholder: (c,u) => CircularProgressIndicator(),
//           //)
//          // FadeInImage.assetNetwork(placeholder: CircularProgressIndicator(), image: null)
//           Image.network(galleryExampleItem.url,
//               headers: galleryExampleItem.headers),
//         ),
//       ),
//     );
//   }
// }

// class GalleryPhotoViewWrapper extends StatefulWidget {
//   GalleryPhotoViewWrapper({
//     this.loadingBuilder,
//     this.backgroundDecoration,
//     this.minScale,
//     this.maxScale,
//     this.initialIndex,
//     @required this.galleryItems,
//     this.totalPage,
//     this.scrollDirection = Axis.horizontal,
//   }) : pageController = PageController(initialPage: initialIndex);

//   final LoadingBuilder loadingBuilder;
//   final Decoration backgroundDecoration;
//   final dynamic minScale;
//   final dynamic maxScale;
//   final int initialIndex;
//   final PageController pageController;
//   final List<GalleryExampleItem> galleryItems;
//   final Axis scrollDirection;
//   final int totalPage;
//   int currentIndex;

//   @override
//   State<StatefulWidget> createState() {
//     return _GalleryPhotoViewWrapperState();
//   }
// }

// class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper> {
//   @override
//   void initState() {
//     widget.currentIndex = widget.initialIndex;
//     super.initState();
//   }

//   void onPageChanged(int index) {
//     setState(() {
//       widget.currentIndex = index;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: widget.backgroundDecoration,
//         constraints: BoxConstraints.expand(
//           height: MediaQuery.of(context).size.height,
//         ),
//         child: Stack(
//           alignment: Alignment.bottomRight,
//           children: <Widget>[
//             PhotoViewGallery.builder(
//               scrollPhysics: const BouncingScrollPhysics(),
//               builder: _buildItem,
//               itemCount: widget.galleryItems.length,
//               loadingBuilder: widget.loadingBuilder,
//               backgroundDecoration: widget.backgroundDecoration,
//               pageController: widget.pageController,
//               onPageChanged: onPageChanged,
//               scrollDirection: widget.scrollDirection,
//               reverse: true,
//             ),
//             Container(
//               padding: const EdgeInsets.all(8.0),
//               child: Text(
//                 "${widget.currentIndex + 1}/${widget.totalPage}",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 14.0,
//                   decoration: null,
//                 ),
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }

//   PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
//     final GalleryExampleItem item = widget.galleryItems[index];
//     return item.isSvg
//         ? PhotoViewGalleryPageOptions.customChild(
//             child: Container(
//               width: 300,
//               height: 300,
//               // child: SvgPicture.asset(
//               //   item.resource,
//               //   height: 200.0,
//               // ),
//             ),
//             childSize: const Size(300, 300),
//             initialScale: PhotoViewComputedScale.contained,
//             minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
//             maxScale: PhotoViewComputedScale.covered * 1.1,
//             heroAttributes: PhotoViewHeroAttributes(tag: item.id),
//           )
//         : PhotoViewGalleryPageOptions(
//             imageProvider: NetworkImage(item.url, headers: item.headers),
//             initialScale: PhotoViewComputedScale.contained,
//             //minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
//             //maxScale: PhotoViewComputedScale.covered * 1.1,
//             minScale: PhotoViewComputedScale.contained * 1.0,
//             // 3만배 확대기능 지원!!
//             maxScale: PhotoViewComputedScale.contained * 30000.0,
//             heroAttributes: PhotoViewHeroAttributes(tag: item.id),
//           );
//   }
// }

// class AnimationTestPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(

//     );
//   }
// }

class AnimationTestPage extends StatefulWidget {
  AnimationTestPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _AnimationTestPageState createState() => new _AnimationTestPageState();
}

class _AnimationTestPageState extends State<AnimationTestPage>
    with FlareController {
  double _rockAmount = 0.5;
  double _speed = 1.0;
  double _rockTime = 0.0;
  bool _isPaused = false;

  ActorAnimation _rock;

  @override
  void initialize(FlutterActorArtboard artboard) {
    _rock = artboard.getAnimation("Untitled");
  }

  @override
  void setViewTransform(Mat2D viewTransform) {}

  @override
  bool advance(FlutterActorArtboard artboard, double elapsed) {
    _rockTime += elapsed * _speed;
    _rock.apply(_rockTime % _rock.duration, artboard, _rockAmount);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.grey,
      appBar: new AppBar(title: new Text(widget.title)),
      body: new Stack(
        children: [
          Positioned.fill(
              child: FlareActor("assets/flare/Cosmos.flr",
                  alignment: Alignment.center,
                  isPaused: _isPaused,
                  fit: BoxFit.cover,
                  animation: "walk",
                  controller: this)),
          Positioned.fill(
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                Container(
                    height: 200,
                    color: Colors.black.withOpacity(0.5),
                    child: new Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        new Text("Mix Amount",
                            style: TextStyle(color: Colors.white)),
                        new Slider(
                          value: _rockAmount,
                          min: 0.0,
                          max: 1.0,
                          divisions: null,
                          onChanged: (double value) {
                            setState(() {
                              _rockAmount = value;
                            });
                          },
                        ),
                        new Text("Speed",
                            style: TextStyle(color: Colors.white)),
                        new Slider(
                          value: _speed,
                          min: 0.2,
                          max: 3.0,
                          divisions: null,
                          onChanged: (double value) {
                            setState(() {
                              _speed = value;
                            });
                          },
                        ),
                        new Text("Paused",
                            style: TextStyle(color: Colors.white)),
                        new Checkbox(
                          value: _isPaused,
                          onChanged: (bool value) {
                            setState(() {
                              _isPaused = value;
                            });
                          },
                        )
                      ],
                    )),
              ]))
        ],
      ),
    );
  }
}

class SearchTestPage extends StatefulWidget {
  @override
  _SearchTestPageState createState() => _SearchTestPageState();
}

class _SearchTestPageState extends State<SearchTestPage> {
  bool selected = false;
  Widget chip(
      Tuple3<String, String, int> info /*, String label, Color color*/) {
    var fc = Chip(
      labelPadding: EdgeInsets.all(0.0),
      avatar: CircleAvatar(
        backgroundColor: Colors.grey.shade600,
        child: Text(info.item1[0].toUpperCase()),
      ),
      label: Text(
        ' ' + info.item2,
        style: TextStyle(
          color: Colors.white,
        ),
      ),
      backgroundColor: info.item1 == 'female'
          ? Colors.red
          : info.item1 == 'male' ? Colors.blue : Colors.grey,
      elevation: 6.0,
      //selected: selected,
      shadowColor: Colors.grey[60],
      padding: EdgeInsets.all(6.0),
      //onPressed: () {},
      // onSelected: (ss) {
      //   setState(() {
      //     selected = ss;
      //   });
      // },
    );
    return fc;
  }

  List<Tuple3<String, String, int>> initLists;

  @override
  Widget build(BuildContext context) {
    if (initLists == null) {
      initLists = List<Tuple3<String, String, int>>();
    }

    return Container(
      child: Scaffold(
        appBar: AppBar(
          title: Text('인덱싱 테스트'),
          backgroundColor: Colors.orange,
        ),
        body: SingleChildScrollView(
          child: Container(
            child: Center(
              child: SidekickTeamBuilder<Tuple3<String, String, int>>(
                  animationDuration: Duration(milliseconds: 300),
                  initialSourceList: initLists,
                  builder: (context, sourceBuilderDelegates,
                      targetBuilderDelegates) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        TextField(
                          onChanged: (str) async {
                            final rr =
                                await HitomiManager.queryAutoComplete(str);
                            print(rr.take(10));
                            setState(() {
                              initLists = rr.take(20).toList();
                            });
                          },
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: 50.0),
                          child: AnimatedContainer(
                            duration: Duration(seconds: 1),
                            child: Wrap(
                              spacing: 4.0,
                              runSpacing: -10.0,
                              // For each target child, there is a targetBuilderDelegate.
                              children:
                                  targetBuilderDelegates.map((builderDelegate) {
                                // We build the child using the build method of the delegate.
                                // This is how the Sidekicks are added automatically.
                                return builderDelegate.build(
                                    context,
                                    GestureDetector(
                                        // We can use the builderDelegate.state property
                                        // to trigger the move.
                                        // The element to move is determined by the message.
                                        // So it should be unique.
                                        onTap: () => builderDelegate.state
                                            .move(builderDelegate.message),
                                        child: chip(builderDelegate.message)),
                                    // You can set all the properties you would set on
                                    // a Sidekick.
                                    animationBuilder: (animation) =>
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: FlippedCurve(Curves.easeOut),
                                        ),
                                    flightShuttleBuilder: (
                                      context,
                                      animation,
                                      type,
                                      from,
                                      to,
                                    ) =>
                                        Card(
                                          child: chip(builderDelegate.message),
                                          color: Colors.transparent,
                                          elevation: 0,
                                        )
                                    // chip(builderDelegate.message,
                                    //     Colors.orange)
                                    //    buildShuttle(
                                    //  animation,
                                    //  builderDelegate.message,
                                    //),
                                    );
                              }).toList(),
                            ),
                          ),
                        ),
                        // Wrap(
                        //   runSpacing: -10,
                        //   children: <Widget>[
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //     chip('asdf', Colors.pink),
                        //   ],
                        // ),
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: 50.0),
                          child: AnimatedContainer(
                            duration: Duration(seconds: 1),
                            child: Wrap(
                              spacing: 4.0,
                              runSpacing: -4.0,
                              // For each target child, there is a targetBuilderDelegate.
                              children:
                                  sourceBuilderDelegates.map((builderDelegate) {
                                // We build the child using the build method of the delegate.
                                // This is how the Sidekicks are added automatically.
                                return builderDelegate.build(
                                    context,
                                    GestureDetector(
                                        // We can use the builderDelegate.state property
                                        // to trigger the move.
                                        // The element to move is determined by the message.
                                        // So it should be unique.
                                        onTap: () => builderDelegate.state
                                            .move(builderDelegate.message),
                                        child: chip(builderDelegate.message)),
                                    // You can set all the properties you would set on
                                    // a Sidekick.
                                    animationBuilder: (animation) =>
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: FlippedCurve(Curves.easeOut),
                                        ),
                                    flightShuttleBuilder: (
                                      context,
                                      animation,
                                      type,
                                      from,
                                      to,
                                    ) =>
                                        Card(
                                          child: chip(builderDelegate.message),
                                          color: Colors.transparent,
                                          elevation: 0,
                                        )
                                    //    buildShuttle(
                                    //  animation,
                                    //  builderDelegate.message,
                                    //),
                                    );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
            ),
          ),
        ),
      ),
    );
  }

  //Widget buildShuttle(
  //  Animation<double> animation,
  //  String message,
  //) {
  //  return AnimatedBuilder(
  //    animation: animation,
  //    builder: (_, __) {
  //      return Bubble(
  //        radius: Tween<double>(begin: 50.0, end: 30.0).evaluate(animation),
  //        fontSize: Tween<double>(begin: 20.0, end: 12.0).evaluate(animation),
  //        backgroundColor: ColorTween(begin: Colors.green, end: Colors.blue)
  //            .evaluate(animation),
  //        foregroundColor: Colors.white,
  //        child: Padding(
  //          padding: const EdgeInsets.all(2.0),
  //          child: Text(
  //            message,
  //            textAlign: TextAlign.center,
  //          ),
  //        ),
  //      );
  //    },
  //  );
  //}
}

class FlareHeroTestPage extends StatefulWidget {
  @override
  _FlareHeroTestPageState createState() => _FlareHeroTestPageState();
}

class _FlareHeroTestPageState extends State<FlareHeroTestPage> {
  FlutterActorArtboard artboardFront;
  FlutterActorArtboard artboardBack;
  final FlareControls heroFlareControls = FlareControls();

  @override
  void initState() {
    super.initState();

    (() async {
      var asset =
          await cachedActor(rootBundle, 'assets/flare/search_close.flr');
      asset.ref();
      artboardBack =
          asset.actor.artboard.makeInstance() as FlutterActorArtboard;
      artboardBack.initializeGraphics();
      artboardBack.advance(0);

      var asset2 =
          await cachedActor(rootBundle, 'assets/flare/search_close.flr');
      asset2.ref();
      artboardFront =
          asset2.actor.artboard.makeInstance() as FlutterActorArtboard;
      artboardFront.initializeGraphics();
      artboardFront.advance(0);
    })();
  }

  @override
  Widget build(BuildContext context) {
    //timeDilation = 5;
    return Container(
      color: Colors.white,
      // color: Colors.grey,
      child: MaterialApp(
        title: "Flare Bot",
        routes: {
          "/page1": (context) => Page1(
              artboardBack: artboardBack,
              artboardFront: artboardFront,
              heroControls: heroFlareControls),
          "/page2": (context) => Page2(
              artboardBack: artboardBack,
              artboardFront: artboardFront,
              heroControls: heroFlareControls),
        },
        home: Page1(
            artboardBack: artboardBack,
            artboardFront: artboardFront,
            heroControls: heroFlareControls),
      ),
    );
    ;
  }
}

class Page1 extends StatelessWidget {
  final FlutterActorArtboard artboardFront;
  final FlutterActorArtboard artboardBack;
  final FlareControls heroControls;
  const Page1({this.artboardFront, this.artboardBack, this.heroControls});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        heroControls.play("close2search");
        Navigator.pushNamed(context, "/page2");
      },
      child: Container(
        child: Align(
            alignment: Alignment.topCenter,
            child: Hero(
              tag: "tag",
              child: Container(
                width: 300,
                height: 300,
                child: Stack(
                  children: <Widget>[
                    //FlareArtboard(artboardBack),
                    FlareArtboard(artboardFront, controller: heroControls)
                  ],
                ),
              ),
            )),
      ),
    );
  }
}

class Page2 extends StatelessWidget {
  final FlutterActorArtboard artboardFront;
  final FlutterActorArtboard artboardBack;
  final FlareControls heroControls;

  Page2({this.artboardFront, this.artboardBack, this.heroControls});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        heroControls.play("search2close");
        Navigator.pushNamed(context, "/page1");
      },
      child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.white,
            width: 300,
            height: 300,
            child: Hero(
              tag: "tag",
              child: Stack(
                children: <Widget>[
                  //FlareArtboard(artboardBack),
                  FlareArtboard(artboardFront, controller: heroControls)
                ],
              ),
            ),
          )),
    );
  }
}

class ScrollTestPage extends StatefulWidget {
  ScrollTestPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _ScrollTestPageState createState() => new _ScrollTestPageState();
}

class _ScrollTestPageState extends State<ScrollTestPage> {
  int _counter = 0;
  ScrollController _hideButtonController;
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  var _isVisible;
  @override
  initState() {
    super.initState();
    _isVisible = true;
    _hideButtonController = new ScrollController();
    _hideButtonController.addListener(() {
      if (_hideButtonController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isVisible == true) {
          /* only set when the previous state is false
             * Less widget rebuilds 
             */
          print("**** ${_isVisible} up"); //Move IO away from setState
          setState(() {
            _isVisible = false;
          });
        }
      } else {
        if (_hideButtonController.position.userScrollDirection ==
            ScrollDirection.forward) {
          if (_isVisible == false) {
            /* only set when the previous state is false
               * Less widget rebuilds 
               */
            print("**** ${_isVisible} down"); //Move IO away from setState
            setState(() {
              _isVisible = true;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('asdf'),
      ),
      body: new Center(
          child: new CustomScrollView(
        controller: _hideButtonController,
        shrinkWrap: true,
        slivers: <Widget>[
          new SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: new SliverList(
              delegate: new SliverChildListDelegate(
                <Widget>[
                  const Text('I\'m dedicating every day to you'),
                  const Text('Domestic life was never quite my style'),
                  const Text('When you smile, you knock me out, I fall apart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('And I thought I was so smart'),
                  const Text('I realize I am crazy'),
                ],
              ),
            ),
          ),
        ],
      )),
      floatingActionButton: new Visibility(
        visible: _isVisible,
        child: new FloatingActionButton(
          onPressed: _incrementCounter,
          tooltip: 'Increment',
          child: new Icon(Icons.add),
        ),
      ),
    );
  }
}

class SilverTestPage extends StatefulWidget {
  @override
  _SilverTestPageState createState() => _SilverTestPageState();
}

class _SilverTestPageState extends State<SilverTestPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child:
          // CustomScrollView(
          //     // CustomScrollView는 children이 아닌 slivers를 사용하며, slivers에는 스크롤이 가능한 위젯이나 리스트가 등록가능함
          //     slivers: <Widget>[
          //       // 앱바 추가
          //       SliverAppBar(
          //         title: Text('asdfasdf'),
          //         // floating 설정. SliverAppBar는 스크롤 다운되면 화면 위로 사라짐.
          //         // true: 스크롤 업 하면 앱바가 바로 나타남. false: 리스트 최 상단에서 스크롤 업 할 때에만 앱바가 나타남
          //         floating: true,
          //         // flexibleSpace에 플레이스홀더를 추가
          //         flexibleSpace: Placeholder(),
          //         // 최대 높이
          //         expandedHeight: 200,
          //       ),
          //       // 리스트 추가
          //       SliverList(
          //         // 아이템을 빌드하기 위해서 delegate 항목을 구성함
          //         // SliverChildBuilderDelegate는 ListView.builder 처럼 리스트의 아이템을 생성해줌
          //         delegate: SliverChildBuilderDelegate(
          //             (context, index) => ListTile(title: Text('Item #$index')),
          //             childCount: 150),
          //       ),
          //     ],
          //   ),
          LayoutBuilder(
        builder: (context, constraints) {
          return CustomScrollView(
            controller: ScrollController(
                initialScrollOffset: constraints.maxHeight * 0.6),
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                floating: true,
                delegate: Delegate(constraints.maxHeight),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Container(
                      height: 100,
                      color: i.isOdd ? Colors.green : Colors.green[700]),
                  childCount: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class Delegate extends SliverPersistentHeaderDelegate {
  final double _maxExtent;

  Delegate(this._maxExtent);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    var t = shrinkOffset / maxExtent;
    return Material(
      elevation: 4,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
          ),
          Opacity(
            opacity: t,
            child: Container(
              color: Colors.deepPurple,
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scale: lerpDouble(16, 1, t),
                child: Text('scroll me down',
                    style: Theme.of(context)
                        .textTheme
                        .headline5
                        .copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => _maxExtent;
  @override
  double get minExtent => 64;
  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}

class VpnTest {
  static const platform = const MethodChannel("xyz.project.violet/dpitunnel");

  static Future<void> asdf() async {
    try {
      var x = await platform.invokeMethod('');
      print(x);
    } on PlatformException catch (e) {
      print(e.message);
    } catch (e) {
      print(e);
    }
    print('asdf');
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool showStatusBar = true;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<List<SystemUiOverlay>>(
      value: showStatusBar ? SystemUiOverlay.values : [],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: showStatusBar ? Colors.red : Colors.orange,
          systemNavigationBarColor: Colors.green.withOpacity(0.1),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
//          appBar: AppBar(title: Text('test')),
          body: FlatButton(
              onPressed: () {
                setState(() => showStatusBar = !showStatusBar);
              },
              child: Text('abc')),
        ),
      ),
    );
  }
}

class GeneratedCouponScreen extends StatefulWidget {
  @override
  _GeneratedCouponScreenState createState() => _GeneratedCouponScreenState();
}

class _GeneratedCouponScreenState extends State<GeneratedCouponScreen>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Stack(
            children: <Widget>[
              Transform.translate(
                offset: Offset(0, -_controller.value * 64),
                child: Container(
                  height: 56.0,
                  child: AppBar(
                    title: Text('Title'),
                    leading: Icon(
                      Icons.arrow_back,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onDoubleTap: () {
                  if (_controller.isCompleted) {
                    _controller.reverse();
                  } else {
                    _controller.forward();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 56.0),
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DATA WYDANIA:',
                                style: TextStyle(color: Colors.black),
                              ),
                              Text('10/09/2019',
                                  style: TextStyle(color: Colors.black))
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('UNIKALNY KOD:',
                                  style: TextStyle(color: Colors.black)),
                              Text('e-86-tC-9',
                                  style: TextStyle(color: Colors.black))
                            ],
                          )
                        ],
                      ),
                      Column(
                        children: [
                          SizedBox(height: 8.0),
                          Image.network(
                            'http://via.placeholder.com/640x360',
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
