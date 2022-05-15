// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:badges/badges.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart'; // @dependent: android
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/main/artist_collection/artist_collection_page.dart';
import 'package:violet/pages/main/card/contact_card.dart';
import 'package:violet/pages/main/card/discord_card.dart';
import 'package:violet/pages/main/card/github_card.dart';
import 'package:violet/pages/main/info/info_page.dart';
import 'package:violet/pages/main/info/lab/global_comments.dart';
import 'package:violet/pages/main/info/lab/recent_record.dart';
import 'package:violet/pages/main/info/lab/recent_record_u.dart';
import 'package:violet/pages/main/info/lab/recent_user_record.dart';
import 'package:violet/pages/main/info/lab/search_message.dart';
import 'package:violet/pages/main/info/lab/user_bookmark_page.dart';
import 'package:violet/pages/main/patchnote/patchnote_page.dart';
import 'package:violet/pages/main/views/views_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/server/wsalt.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';
import 'package:violet/version/update_sync.dart';
import 'package:violet/widgets/toast.dart';

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

    Future.delayed(Duration(milliseconds: 200)).then((value) async {
      // var latestDB = SyncManager.getLatestDB().getDateTime();
      // var lastDB =
      //     (await SharedPreferences.getInstance()).getString('databasesync');
      // if (lastDB != null &&
      //     latestDB.difference(DateTime.parse(lastDB)).inHours < 1) {
      //   return;
      // }

      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) return;

      await UpdateSyncManager.checkUpdateSync();

      setState(() {
        _shouldReload = true;
      });

      // Update is not available for iOS.
      if (!Platform.isIOS) {
        updateCheckAndDownload(); // @dependent: android
      }

      if (SyncManager.syncRequire) {
        setState(() {
          _shouldReload = true;
          _syncAvailable = true;
        });
      }
    });
  }

  List<Widget> _cachedGroups;
  bool _shouldReload = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    final cardList = [
      DiscordCard(),
      ContactCard(),
      GithubCard(),
    ];

    if (_cachedGroups == null || _shouldReload) {
      _shouldReload = false;
      _cachedGroups = <Widget>[
        Container(height: 16),
        _buildGroup(Translations.of(context).trans('userstat'), _statArea()),
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
                _shouldReload = true;
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
              margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
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
        _buildGroup(Translations.of(context).trans('versionmanagement'),
            _versionArea()),
        _buildGroup(Translations.of(context).trans('service'), _serviceArea()),
        Container(height: 32)
      ];
    }

    return Container(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: statusBarHeight),
        physics: BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _cachedGroups,
        ),
      ),
    );
  }

  // _databaseArea() {
  //   return [
  //     Row(
  //       children: [
  //         Text(Settings.databaseType.toUpperCase() + '언어 데이터베이스',
  //             style: TextStyle(fontWeight: FontWeight.bold)),
  //         Expanded(child: Container()),
  //         Column(
  //           children: [
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Text('로컬', style: TextStyle(color: Colors.grey)),
  //                 FutureBuilder(
  //                     future: SharedPreferences.getInstance(),
  //                     builder: (context, snapshot) {
  //                       if (!snapshot.hasData) {
  //                         return Text(' ??');
  //                       }
  //                       return Text(
  //                         ' ' +
  //                             DateFormat('yyyy.MM.dd').format(DateTime.parse(
  //                                 snapshot.data.getString('databasesync'))),
  //                       );
  //                     }),
  //               ],
  //             ),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Text('최신', style: TextStyle(color: Colors.grey)),
  //                 Text(
  //                   ' ' +
  //                       DateFormat('yyyy.MM.dd').format(UpdateSyncManager
  //                           .rawlangDB[Settings.databaseType].item1),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //     _buildDivider(),
  //     Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceAround,
  //       children: [
  //         RaisedButton(
  //           color: Settings.majorColor.withAlpha(220),
  //           onPressed: () {},
  //           child: Text('    스위칭    '),
  //           elevation: 3.0,
  //         ),
  //         Badge(
  //           showBadge: _syncAvailable,
  //           badgeContent: Text('N',
  //               style: TextStyle(color: Colors.white, fontSize: 12.0)),
  //           // badgeColor: Settings.majorAccentColor,
  //           child: RaisedButton(
  //             color: Settings.majorColor.withAlpha(220),
  //             onPressed: () {},
  //             child: Text('    동기화    '),
  //             elevation: 3.0,
  //           ),
  //         ),
  //       ],
  //     )
  //   ];
  // }

  _statArea() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(Translations.of(context).trans('readpresent')),
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
              Text(Translations.of(context).trans('bookmark')),
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
              Text(Translations.of(context).trans('download')),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(Translations.of(context).trans('curversion'),
                      style: TextStyle(color: Colors.grey)),
                  Text(
                      ' ${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}'),
                ],
              ),
              ' ${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}' !=
                      ' ${UpdateSyncManager.latestVersion}'
                  ? Row(
                      children: [
                        Text(Translations.of(context).trans('latestversion'),
                            style: TextStyle(color: Colors.grey)),
                        Text(' ${UpdateSyncManager.latestVersion}'),
                      ],
                    )
                  : Row(
                      children: [
                        Text(Translations.of(context).trans('curlatestversion'),
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
            ],
          ),
          Expanded(child: Container()),
          // Container(
          //   child: UpdateLogCard(),
          //   height: 50,
          //   width: 100,
          // )
          Container(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: Settings.majorColor.withAlpha(220),
              ),
              onPressed: () {
                PlatformNavigator.navigateSlide(context, PatchNotePage());
              },
              child: Text(Translations.of(context).trans('patchnote')),
            ),
            height: 40,
            width: 105,
          ),
        ],
      ),
      // Database
      _buildDivider(),
      Row(
        children: [
          Text(Translations.of(context).trans('database'),
              style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Container()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(Translations.of(context).trans('local'),
                      style: TextStyle(color: Colors.grey)),
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
                  Text(Translations.of(context).trans('latest'),
                      style: TextStyle(color: Colors.grey)),
                  Text(
                    ' ' +
                        DateFormat('yyyy.MM.dd')
                            .format(SyncManager.getLatestDB().getDateTime()),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              primary: Settings.majorColor.withAlpha(220),
            ),
            onPressed: Variables.databaseDecompressed
                ? null
                : () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => SplashPage(
                              switching: true,
                            )));
                  },
            child:
                Text('    ${Translations.of(context).trans('switching')}    '),
          ),
          Badge(
            showBadge: _syncAvailable,
            badgeContent: Text('N',
                style: TextStyle(color: Colors.white, fontSize: 12.0)),
            // badgeColor: Settings.majorAccentColor,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: Settings.majorColor.withAlpha(220),
              ),
              onPressed: Variables.databaseDecompressed
                  ? null
                  : () async {
                      var latestDB = SyncManager.getLatestDB().getDateTime();
                      var lastDB = (await SharedPreferences.getInstance())
                          .getString('databasesync');

                      if (lastDB != null &&
                          latestDB.difference(DateTime.parse(lastDB)).inHours <
                              1) {
                        FlutterToast(context).showToast(
                          child: ToastWrapper(
                            isCheck: true,
                            msg: Translations.of(context)
                                .trans('thisislatestbookmark'),
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );
                        return;
                      }

                      var dir = await getApplicationDocumentsDirectory();
                      try {
                        await ((await openDatabase('${dir.path}/data/data.db'))
                            .close());
                        await deleteDatabase('${dir.path}/data/data.db');
                        await Directory('${dir.path}/data')
                            .delete(recursive: true);
                      } catch (e) {}

                      setState(() {
                        _shouldReload = true;
                        _syncAvailable = false;
                      });

                      await Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (context) => DataBaseDownloadPage(
                                    dbType: Settings.databaseType,
                                    isSync: true,
                                  )))
                          .then((value) async {
                        HitomiIndexs.init();
                        final directory =
                            await getApplicationDocumentsDirectory();
                        final path = File('${directory.path}/data/index.json');
                        final text = path.readAsStringSync();
                        HitomiManager.tagmap = jsonDecode(text);
                        await DataBaseManager.reloadInstance();

                        FlutterToast(context).showToast(
                          child: ToastWrapper(
                            isCheck: true,
                            msg: Translations.of(context).trans('synccomplete'),
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );
                      });
                    },
              child: Text('    ${Translations.of(context).trans('sync')}    '),
            ),
          ),
        ],
      )
    ];
  }

  _serviceArea() {
    final buttonStyle = ElevatedButton.styleFrom(
      primary: Settings.majorColor.withAlpha(220),
      onPrimary: Colors.white,
      elevation: 3.0,
      minimumSize: const Size(30.0, 30.0),
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(16),
    );

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Tooltip(
            message: '작가별 모음',
            child: ElevatedButton(
              style: buttonStyle,
              onPressed: () {
                PlatformNavigator.navigateSlide(
                    context, ArtistCollectionPage());
              },
              child: const Icon(MdiIcons.star),
            ),
          ),
          Tooltip(
            message: '조회수 베스트',
            child: ElevatedButton(
              style: buttonStyle,
              onPressed: () {
                PlatformNavigator.navigateSlide(context, ViewsPage());
              },
              child: const Icon(MdiIcons.starShooting),
            ),
          ),
          Tooltip(
            message: '정보',
            child: ElevatedButton(
              style: buttonStyle,
              onPressed: () {
                PlatformNavigator.navigateSlide(context, InfoPage());
              },
              child: const Icon(MdiIcons.heart),
            ),
          ),
        ],
      ),
      Container(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Tooltip(
            message: '실시간 유저 레코드',
            child: ElevatedButton(
              style: buttonStyle,
              onPressed: () async {
                PlatformNavigator.navigateSlide(context, LabRecentRecordsU());
              },
              child: const Icon(MdiIcons.accessPointNetwork),
            ),
          ),
          // Tooltip(
          //   message: '유저 북마크 리스트',
          //   child: ElevatedButton(
          //     style: buttonStyle,
          //     onPressed: () async {
          //       if (await _checkMaterKey()) {
          //         Navigator.of(context).push(
          //             _buildServicePageRoute(() => LabUserBookmarkPage()));
          //       } else {
          //         await showOkDialog(
          //             context,
          //             'You must unlock this feature using the master key! ' +
          //                 '이 기능은 현재 인가된 사용자만 사용할 수 있습니다.');
          //       }
          //     },
          //     child: const Icon(MdiIcons.incognito),
          //   ),
          // ),
          Badge(
            showBadge: true,
            badgeContent: Text('N',
                style: TextStyle(color: Colors.white, fontSize: 12.0)),
            child: Tooltip(
              message: '댓글',
              child: ElevatedButton(
                style: buttonStyle,
                onPressed: () async {
                  PlatformNavigator.navigateSlide(context, LabGlobalComments());
                },
                child: const Icon(MdiIcons.commentTextMultiple),
              ),
            ),
          ),
          Badge(
            showBadge: true,
            badgeContent: Text('N',
                style: TextStyle(color: Colors.white, fontSize: 12.0)),
            // badgeColor: Settings.majorAccentColor,
            child: Tooltip(
              message: '대사 검색기',
              child: ElevatedButton(
                style: buttonStyle,
                onPressed: () async {
                  PlatformNavigator.navigateSlide(context, LabSearchMessage());
                },
                child: const Icon(MdiIcons.commentSearch),
              ),
            ),
          ),
          // Tooltip(
          //   message: '마스터 모드 해금',
          //   child: ElevatedButton(
          //     style: buttonStyle,
          //     onPressed: () async {
          //       if (await _checkMaterKey()) {
          //         await showOkDialog(context, 'Alread Unlocked!');
          //         return;
          //       }
          //       Widget yesButton = TextButton(
          //         style: TextButton.styleFrom(primary: Settings.majorColor),
          //         child: Text(Translations.of(context).trans('ok')),
          //         onPressed: () {
          //           Navigator.pop(context, true);
          //         },
          //       );
          //       Widget noButton = TextButton(
          //         style: TextButton.styleFrom(primary: Settings.majorColor),
          //         child: Text(Translations.of(context).trans('cancel')),
          //         onPressed: () {
          //           Navigator.pop(context, false);
          //         },
          //       );
          //       TextEditingController text = TextEditingController();
          //       var dialog = await showDialog(
          //         useRootNavigator: false,
          //         context: context,
          //         builder: (BuildContext context) => AlertDialog(
          //           contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
          //           title: Text('Input Master Key'),
          //           content: TextField(
          //             controller: text,
          //             autofocus: true,
          //           ),
          //           actions: [yesButton, noButton],
          //         ),
          //       );
          //       if (dialog == true) {
          //         if (getValid(text.text + 'saltff') == '605f372') {
          //           await showOkDialog(context, 'Successful!');
          //           await (await SharedPreferences.getInstance())
          //               .setString('labmasterkey', text.text);
          //         } else {
          //           await showOkDialog(context, 'Fail!');
          //         }
          //       }
          //     },
          //     child: const Icon(MdiIcons.keyChainVariant),
          //   ),
          // ),
        ],
      ),
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
          decoration: !Settings.themeFlat
              ? BoxDecoration(
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
                )
              : null,
          color: !Settings.themeFlat
              ? null
              : Settings.themeWhat
                  ? Settings.themeBlack
                      ? const Color(0xFF141414)
                      : Colors.black26
                  : Colors.white,
          child: !Settings.themeFlat
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Material(
                      color: Settings.themeWhat
                          ? Settings.themeBlack
                              ? const Color(0xFF141414)
                              : Colors.black38
                          : Colors.white,
                      child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Column(children: content))))
              : Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(children: content)),
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
    return NumberFormat('###,###,###,###').format(param).replaceAll(' ', '');
  }

  // @dependent: android [
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
        var bb = await showYesNoDialog(
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
          await showOkDialog(context,
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
        // String id = data[0];
        // DownloadTaskStatus status = data[1];
        int progress = data[2];
        if (progress == 100 && !once) {
          OpenFile.open(
              '${ext.path}/${UpdateSyncManager.updateUrl.split('/').last}');
          once = true;
        }
        setState(() {
          _shouldReload = true;
        });
      });

      if (await File(
              '${ext.path}/${UpdateSyncManager.updateUrl.split('/').last}')
          .exists()) {
        await File('${ext.path}/${UpdateSyncManager.updateUrl.split('/').last}')
            .delete();
      }

      FlutterDownloader.registerCallback(downloadCallback);
      await FlutterDownloader.enqueue(
        url: UpdateSyncManager.updateUrl,
        savedDir: '${ext.path}',
        fileName: UpdateSyncManager.updateUrl.split('/').last,
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

      var bb = await showYesNoDialog(
          context, Translations.of(context).trans('violetservermsg'));
      if (bb == null || bb == false) {
        await (await SharedPreferences.getInstance())
            .setBool('usevioletserver_check', false);
        return;
      }

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
  // @dependent: android ]
}
