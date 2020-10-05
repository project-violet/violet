// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:badges/badges.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/card/artist_collection_card.dart';
import 'package:violet/pages/main/card/contact_card.dart';
import 'package:violet/pages/main/card/discord_card.dart';
import 'package:violet/pages/main/card/github_card.dart';
import 'package:violet/pages/main/card/update_card.dart';
import 'package:violet/pages/main/card/update_log_card.dart';
import 'package:violet/pages/main/card/views_card.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/version/update_sync.dart';

class MainPage2 extends StatefulWidget {
  @override
  _MainPage2State createState() => _MainPage2State();
}

class _MainPage2State extends State<MainPage2>
    with AutomaticKeepAliveClientMixin<MainPage2> {
  @override
  bool get wantKeepAlive => true;
  // int count = 0;
  // bool ee = false;
  int _current = 0;
  bool _syncAvailable = false;

  @override
  void initState() {
    super.initState();
    updateCheckAndDownload();

    Future.delayed(Duration(milliseconds: 200)).then((value) async {
      var latestDB = UpdateSyncManager.rawlangDB[Settings.databaseType].item1;
      var lastDB =
          (await SharedPreferences.getInstance()).getString('databasesync');

      if (lastDB != null &&
          latestDB.difference(DateTime.parse(lastDB)).inHours < 1) {
        return;
      }

      setState(() {
        _syncAvailable = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double width = MediaQuery.of(context).size.width;

    final cardList = [
      DiscordCard(),
      ContactCard(),
      GithubCard(),
    ];

    return Container(
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(height: 16),
              _buildGroup('사용자 통계', _statArea()),
              CarouselSlider(
                options: CarouselOptions(
                  height: 70,
                  aspectRatio: 16 / 9,
                  viewportFraction: 1.0,
                  initialPage: 0,
                  enableInfiniteScroll: false,
                  reverse: false,
                  autoPlay: true,
                  autoPlayInterval: Duration(seconds: 10),
                  autoPlayAnimationDuration: Duration(milliseconds: 800),
                  autoPlayCurve: Curves.fastOutSlowIn,
                  enlargeCenterPage: true,
                  scrollDirection: Axis.horizontal,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _current = index;
                    });
                  },
                ),
                items: cardList.map((card) {
                  return Builder(
                    builder: (BuildContext context) => card,
                  );
                }).toList(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3].map((url) {
                  int index = [1, 2, 3].indexOf(url);
                  return Container(
                    width: 8.0,
                    height: 8.0,
                    margin:
                        EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _current == index
                          ? Settings.themeWhat
                              ? Color.fromRGBO(255, 255, 255, 0.9)
                              : Color.fromRGBO(0, 0, 0, 0.9)
                          : Settings.themeWhat
                              ? Color.fromRGBO(255, 255, 255, 0.4)
                              : Color.fromRGBO(0, 0, 0, 0.4),
                    ),
                  );
                }).toList(),
              ),
              // _buildGroup('데이터베이스', _databaseArea()),
              _buildGroup('버전관리', _versionArea()),
              _buildGroup('서비스', _serviceArea()),
              Container(height: 32)
            ],
          ),
        ),
      ),
    );
  }

  _databaseArea() {
    return [
      Row(
        children: [
          Text(Settings.databaseType.toUpperCase() + '언어 데이터베이스',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Container()),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('로컬', style: TextStyle(color: Colors.grey)),
                  FutureBuilder(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Text(' ??');
                        }
                        return Text(
                          ' ' +
                              DateFormat('yyyy.MM.dd').format(DateTime.parse(
                                  snapshot.data.getString('databasesync'))),
                        );
                      }),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('최신', style: TextStyle(color: Colors.grey)),
                  Text(
                    ' ' +
                        DateFormat('yyyy.MM.dd').format(UpdateSyncManager
                            .rawlangDB[Settings.databaseType].item1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _buildDivider(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          RaisedButton(
            color: Settings.majorColor.withAlpha(220),
            onPressed: () {},
            child: Text('    스위칭    '),
            elevation: 3.0,
          ),
          Badge(
            showBadge: _syncAvailable,
            badgeContent: Text('N',
                style: TextStyle(color: Colors.white, fontSize: 12.0)),
            // badgeColor: Settings.majorAccentColor,
            child: RaisedButton(
              color: Settings.majorColor.withAlpha(220),
              onPressed: () {},
              child: Text('    동기화    '),
              elevation: 3.0,
            ),
          ),
        ],
      )
    ];
  }

  _statArea() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text("읽음"),
              Container(height: 8),
              FutureBuilder(future: Future.sync(
                () async {
                  return await (await User.getInstance()).getUserLog();
                },
              ), builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text('??',
                      style: TextStyle(
                          fontFamily: "Calibre-Semibold", fontSize: 18));
                }
                return Text(numberWithComma(snapshot.data.length),
                    style: TextStyle(
                        fontFamily: "Calibre-Semibold", fontSize: 18));
              }),
            ],
          ),
          Column(
            children: [
              Text("북마크"),
              Container(height: 8),
              FutureBuilder(future: Future.sync(
                () async {
                  return await (await Bookmark.getInstance()).getArticle();
                },
              ), builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text('??',
                      style: TextStyle(
                          fontFamily: "Calibre-Semibold", fontSize: 18));
                }
                return Text(numberWithComma(snapshot.data.length),
                    style: TextStyle(
                        fontFamily: "Calibre-Semibold", fontSize: 18));
              }),
            ],
          ),
          Column(
            children: [
              Text("다운로드"),
              Container(height: 8),
              FutureBuilder(future: Future.sync(
                () async {
                  return await (await Download.getInstance())
                      .getDownloadItems();
                },
              ), builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text('??',
                      style: TextStyle(
                          fontFamily: "Calibre-Semibold", fontSize: 18));
                }
                return Text(numberWithComma(snapshot.data.length),
                    style: TextStyle(
                        fontFamily: "Calibre-Semibold", fontSize: 18));
              }),
            ],
          ),
        ],
      )
    ];
  }

  _versionArea() {
    return [
      // Version Info
      Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('현재버전', style: TextStyle(color: Colors.grey)),
                  Text(
                      ' ${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}'),
                ],
              ),
              ' ${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}' !=
                      ' ${UpdateSyncManager.latestVersion}'
                  ? Row(
                      children: [
                        Text('최신버전', style: TextStyle(color: Colors.grey)),
                        Text(' ${UpdateSyncManager.latestVersion}'),
                      ],
                    )
                  : Row(
                      children: [
                        Text('최신버전입니다', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
            ],
          ),
          Expanded(child: Container()),
          Container(
            child: UpdateLogCard(),
            height: 50,
            width: 100,
          )
        ],
      ),
      // Database
      _buildDivider(),
      Row(
        children: [
          Text('데이터베이스', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Container()),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('로컬', style: TextStyle(color: Colors.grey)),
                  FutureBuilder(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Text(' ??');
                        }
                        return Text(
                          ' ' +
                              DateFormat('yyyy.MM.dd').format(DateTime.parse(
                                  snapshot.data.getString('databasesync'))),
                        );
                      }),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('최신', style: TextStyle(color: Colors.grey)),
                  Text(
                    ' ' +
                        DateFormat('yyyy.MM.dd').format(UpdateSyncManager
                            .rawlangDB[Settings.databaseType].item1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      Container(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          RaisedButton(
            color: Settings.majorColor.withAlpha(220),
            onPressed: () {},
            child: Text('    스위칭    '),
            elevation: 3.0,
          ),
          Badge(
            showBadge: _syncAvailable,
            badgeContent: Text('N',
                style: TextStyle(color: Colors.white, fontSize: 12.0)),
            // badgeColor: Settings.majorAccentColor,
            child: RaisedButton(
              color: Settings.majorColor.withAlpha(220),
              onPressed: () {},
              child: Text('    동기화    '),
              elevation: 3.0,
            ),
          ),
        ],
      )
    ];
  }

  _serviceArea() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Container(
            child: ArtistCollectionCard(),
            height: 50,
            width: 150,
          ),
          Container(
            child: ViewsCard(),
            height: 50,
            width: 150,
          ),
        ],
      )
    ];
  }

  _buildGroup(name, content) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(32, 20, 32, 0),
          alignment: Alignment.centerLeft,
          child: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Settings.majorColor,
              fontSize: 16.0,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.fromLTRB(32, 20, 32, 10),
          // margin: EdgeInsets.only(left: 30, top: 100, right: 30, bottom: 50),
          // height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            // color: Colors.white,
            color: Settings.themeWhat ? Colors.black26 : Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: Settings.themeWhat
                    ? Colors.black26
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: Settings.themeWhat ? 0 : 5,
                blurRadius: 7,
                offset: Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(children: content),
          ),
        ),
      ],
    );
  }

  Container _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12.0),
      width: double.infinity,
      height: 1.0,
      color: Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
    );
  }

  String numberWithComma(int param) {
    return new NumberFormat('###,###,###,###')
        .format(param)
        .replaceAll(' ', '');
  }

  ReceivePort _port = ReceivePort();

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }

  void updateCheckAndDownload() {
    bool updateContinued = false;
    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      if (UpdateSyncManager.updateRequire) {
        var bb = await Dialogs.yesnoDialog(
            context,
            Translations.of(context).trans('newupdate') +
                ' ' +
                UpdateSyncManager.updateMessage +
                ' ' +
                Translations.of(context).trans('wouldyouupdate'));
        if (bb == null || bb == false) return;
      } else
        return;

      if (!await Permission.storage.isGranted) {
        if (await Permission.storage.request() == PermissionStatus.denied) {
          await Dialogs.okDialog(context,
              'If you do not allow file permissions, you cannot continue :(');
          return;
        }
      }
      updateContinued = true;
      var ext = await getExternalStorageDirectory();
      bool once = false;
      IsolateNameServer.registerPortWithName(
          _port.sendPort, 'downloader_send_port');
      _port.listen((dynamic data) {
        String id = data[0];
        DownloadTaskStatus status = data[1];
        int progress = data[2];
        if (progress == 100 && !once) {
          OpenFile.open(
              '${ext.path}/${UpdateSyncManager.updateUrl.split('/').last}');
          once = true;
        }
        setState(() {});
      });

      FlutterDownloader.registerCallback(downloadCallback);
      final taskId = await FlutterDownloader.enqueue(
        url: UpdateSyncManager.updateUrl,
        savedDir: '${ext.path}',
        showNotification:
            true, // show download progress in status bar (for Android)
        openFileFromNotification:
            true, // click on notification to open downloaded file (for Android)
      );
    }).then((value) async {
      if (updateContinued) return;
      if ((await SharedPreferences.getInstance())
              .getBool('usevioletserver_check') !=
          null) return;

      var bb = await Dialogs.yesnoDialog(
          context, Translations.of(context).trans('violetservermsg'));
      if (bb == null || bb == false) return;

      await Settings.setUseVioletServer(true);
      await (await SharedPreferences.getInstance())
          .setBool('usevioletserver_check', false);
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    // TODO: implement dispose
    super.dispose();
  }
}
