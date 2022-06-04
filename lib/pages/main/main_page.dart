// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:badges/badges.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:connectivity/connectivity.dart';
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
import 'package:violet/pages/main/info/lab/recent_record_u.dart';
import 'package:violet/pages/main/info/lab/search_message.dart';
import 'package:violet/pages/main/patchnote/patchnote_page.dart';
import 'package:violet/pages/main/views/views_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';
import 'package:violet/version/update_sync.dart';
import 'package:violet/widgets/toast.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with AutomaticKeepAliveClientMixin<MainPage> {
  @override
  bool get wantKeepAlive => true;
  // int count = 0;
  // bool ee = false;
  int _current = 0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 200)).then((value) async {
      // final prefs = await SharedPreferences.getInstance();
      // var latestDB = SyncManager.getLatestDB().getDateTime();
      // var lastDB = prefs.getString('databasesync');
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
    });
  }

  List<Widget>? _cachedGroups;
  bool _shouldReload = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    final cardList = [
      const DiscordCard(),
      const ContactCard(),
      const GithubCard(),
    ];

    if (_cachedGroups == null || _shouldReload) {
      _shouldReload = false;
      _cachedGroups = <Widget>[
        Container(height: 16),
        _BuildGroupWidget(
          name: Translations.of(context).trans('userstat'),
          content: const _StatAreaWidget(),
        ),
        CarouselSlider(
          options: CarouselOptions(
            height: 70,
            aspectRatio: 16 / 9,
            viewportFraction: 1.0,
            initialPage: 0,
            enableInfiniteScroll: false,
            reverse: false,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 10),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
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
              margin:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _current == index
                    ? Settings.themeWhat
                        ? const Color.fromRGBO(255, 255, 255, 0.9)
                        : const Color.fromRGBO(0, 0, 0, 0.9)
                    : Settings.themeWhat
                        ? const Color.fromRGBO(255, 255, 255, 0.4)
                        : const Color.fromRGBO(0, 0, 0, 0.4),
              ),
            );
          }).toList(),
        ),
        _BuildGroupWidget(
          name: Translations.of(context).trans('versionmanagement'),
          content: const _VersionAreaWidget(),
        ),
        _BuildGroupWidget(
          name: Translations.of(context).trans('service'),
          content: const _ServiceAreaWidget(),
        ),
        Container(height: 32)
      ];
    }

    return Container(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: statusBarHeight),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _cachedGroups!,
        ),
      ),
    );
  }

  // @dependent: android [
  final ReceivePort _port = ReceivePort();

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  void updateCheckAndDownload() {
    bool updateContinued = false;
    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      if (UpdateSyncManager.updateRequire) {
        var bb = await showYesNoDialog(context,
            '${Translations.of(context).trans('newupdate')} ${UpdateSyncManager.updateMessage} ${Translations.of(context).trans('wouldyouupdate')}');
        if (bb == false) return;
      } else {
        return;
      }

      if (!await Permission.storage.isGranted) {
        if (await Permission.storage.request() == PermissionStatus.denied) {
          await showOkDialog(context,
              'If you do not allow file permissions, you cannot continue :(');
          return;
        }
      }
      updateContinued = true;
      var ext = (await getExternalStorageDirectory())!;
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
        savedDir: ext.path,
        fileName: UpdateSyncManager.updateUrl.split('/').last,
        showNotification:
            true, // show download progress in status bar (for Android)
        openFileFromNotification:
            true, // click on notification to open downloaded file (for Android)
      );
    }).then((value) async {
      if (updateContinued) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('usevioletserver_check') != null) return;

      var bb = await showYesNoDialog(
          context, Translations.of(context).trans('violetservermsg'));
      if (bb == false) {
        await prefs.setBool('usevioletserver_check', false);
        return;
      }

      await Settings.setUseVioletServer(true);
      await prefs.setBool('usevioletserver_check', false);
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }
  // @dependent: android ]
}

class _VersionAreaWidget extends StatefulWidget {
  const _VersionAreaWidget({Key? key}) : super(key: key);

  @override
  State<_VersionAreaWidget> createState() => _VersionAreaWidgetState();
}

class _VersionAreaWidgetState extends State<_VersionAreaWidget> {
  bool syncAvailable = false;
  late final FToast fToast;

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);

    Future.delayed(const Duration(milliseconds: 200)).then((value) async {
      if (SyncManager.syncRequire) {
        setState(() {
          syncAvailable = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var versionInfo = Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(Translations.of(context).trans('curversion'),
                    style: const TextStyle(color: Colors.grey)),
                const Text(
                    ' ${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}'),
              ],
            ),
            ' ${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}' !=
                    ' ${UpdateSyncManager.latestVersion}'
                ? Row(
                    children: [
                      Text(Translations.of(context).trans('latestversion'),
                          style: const TextStyle(color: Colors.grey)),
                      Text(' ${UpdateSyncManager.latestVersion}'),
                    ],
                  )
                : Row(
                    children: [
                      Text(Translations.of(context).trans('curlatestversion'),
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
          ],
        ),
        Expanded(child: Container()),
        SizedBox(
          height: 40,
          width: 105,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              primary: Settings.majorColor.withAlpha(220),
            ),
            onPressed: () {
              PlatformNavigator.navigateSlide(context, const PatchNotePage());
            },
            child: Text(Translations.of(context).trans('patchnote')),
          ),
        ),
      ],
    );
    var databaseInfo = Row(
      children: [
        Text(Translations.of(context).trans('database'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Container()),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(Translations.of(context).trans('local'),
                    style: const TextStyle(color: Colors.grey)),
                FutureBuilder(
                    future: SharedPreferences.getInstance(),
                    builder:
                        (context, AsyncSnapshot<SharedPreferences> snapshot) {
                      if (!snapshot.hasData) {
                        return const Text(' ??');
                      }
                      return Text(
                        ' ${DateFormat('yyyy.MM.dd').format(DateTime.parse(snapshot.data!.getString('databasesync')!))}',
                      );
                    }),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(Translations.of(context).trans('latest'),
                    style: const TextStyle(color: Colors.grey)),
                Text(
                  ' ${DateFormat('yyyy.MM.dd').format(SyncManager.getLatestDB().getDateTime())}',
                ),
              ],
            ),
          ],
        ),
      ],
    );
    return Column(
      children: [
        versionInfo,
        // Database
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12.0),
          width: double.infinity,
          height: 1.0,
          color:
              Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
        databaseInfo,
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
                          builder: (context) => const SplashPage(
                                switching: true,
                              )));
                    },
              child: Text(
                  '    ${Translations.of(context).trans('switching')}    '),
            ),
            Badge(
              showBadge: syncAvailable,
              badgeContent: const Text('N',
                  style: TextStyle(color: Colors.white, fontSize: 12.0)),
              // badgeColor: Settings.majorAccentColor,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Settings.majorColor.withAlpha(220),
                ),
                onPressed:
                    Variables.databaseDecompressed ? null : _onSyncPressed,
                child:
                    Text('    ${Translations.of(context).trans('sync')}    '),
              ),
            ),
          ],
        )
      ],
    );
  }

  _onSyncPressed() async {
    final prefs = await SharedPreferences.getInstance();
    var latestDB = SyncManager.getLatestDB().getDateTime();
    var lastDB = prefs.getString('databasesync');

    if (lastDB != null &&
        latestDB.difference(DateTime.parse(lastDB)).inHours < 1) {
      fToast.showToast(
        child: ToastWrapper(
          isCheck: true,
          msg: Translations.of(context).trans('thisislatestbookmark'),
        ),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
      );
      return;
    }

    var dir = await getApplicationDocumentsDirectory();

    try {
      await ((await openDatabase('${dir.path}/data/data.db')).close());
      await deleteDatabase('${dir.path}/data/data.db');
      await Directory('${dir.path}/data').delete(recursive: true);
    } catch (_) {}

    setState(() {
      syncAvailable = false;
    });

    await Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (context) => DataBaseDownloadPage(
                  dbType: Settings.databaseType,
                  isSync: true,
                )))
        .then((value) async {
      HitomiIndexs.init();
      final directory = await getApplicationDocumentsDirectory();
      final path = File('${directory.path}/data/index.json');
      final text = path.readAsStringSync();
      HitomiManager.tagmap = jsonDecode(text);
      await DataBaseManager.reloadInstance();

      fToast.showToast(
        child: ToastWrapper(
          isCheck: true,
          msg: Translations.of(context).trans('synccomplete'),
        ),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
      );
    });
  }
}

class _StatAreaWidget extends StatelessWidget {
  const _StatAreaWidget({Key? key}) : super(key: key);

  String numberWithComma(int param) {
    return NumberFormat('###,###,###,###').format(param).replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                ), builder:
                    (context, AsyncSnapshot<List<ArticleReadLog>> snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('??',
                        style: TextStyle(
                            fontFamily: 'Calibre-Semibold', fontSize: 18));
                  }
                  return Text(numberWithComma(snapshot.data!.length),
                      style: const TextStyle(
                          fontFamily: 'Calibre-Semibold', fontSize: 18));
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
                ), builder:
                    (context, AsyncSnapshot<List<BookmarkArticle>> snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('??',
                        style: TextStyle(
                            fontFamily: 'Calibre-Semibold', fontSize: 18));
                  }
                  return Text(numberWithComma(snapshot.data!.length),
                      style: const TextStyle(
                          fontFamily: 'Calibre-Semibold', fontSize: 18));
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
                ), builder:
                    (context, AsyncSnapshot<List<DownloadItemModel>> snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('??',
                        style: TextStyle(
                            fontFamily: 'Calibre-Semibold', fontSize: 18));
                  }
                  return Text(numberWithComma(snapshot.data!.length),
                      style: const TextStyle(
                          fontFamily: 'Calibre-Semibold', fontSize: 18));
                }),
              ],
            ),
          ],
        )
      ],
    );
  }
}

class _ServiceAreaWidget extends StatelessWidget {
  const _ServiceAreaWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      primary: Settings.majorColor.withAlpha(220),
      onPrimary: Colors.white,
      elevation: 3.0,
      minimumSize: const Size(30.0, 30.0),
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(16),
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Tooltip(
              message: '작가별 모음',
              child: ElevatedButton(
                style: buttonStyle,
                onPressed: () {
                  PlatformNavigator.navigateSlide(
                      context, const ArtistCollectionPage());
                },
                child: const Icon(MdiIcons.star),
              ),
            ),
            Tooltip(
              message: '조회수 베스트',
              child: ElevatedButton(
                style: buttonStyle,
                onPressed: () {
                  PlatformNavigator.navigateSlide(context, const ViewsPage());
                },
                child: const Icon(MdiIcons.starShooting),
              ),
            ),
            Tooltip(
              message: '정보',
              child: ElevatedButton(
                style: buttonStyle,
                onPressed: () {
                  PlatformNavigator.navigateSlide(context, const InfoPage());
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
                  PlatformNavigator.navigateSlide(
                      context, const LabRecentRecordsU());
                },
                child: const Icon(MdiIcons.accessPointNetwork),
              ),
            ),
            Badge(
              showBadge: true,
              badgeContent: const Text('N',
                  style: TextStyle(color: Colors.white, fontSize: 12.0)),
              child: Tooltip(
                message: '댓글',
                child: ElevatedButton(
                  style: buttonStyle,
                  onPressed: () async {
                    PlatformNavigator.navigateSlide(
                        context, const LabGlobalComments());
                  },
                  child: const Icon(MdiIcons.commentTextMultiple),
                ),
              ),
            ),
            Badge(
              showBadge: true,
              badgeContent: const Text('N',
                  style: TextStyle(color: Colors.white, fontSize: 12.0)),
              // badgeColor: Settings.majorAccentColor,
              child: Tooltip(
                message: '대사 검색기',
                child: ElevatedButton(
                  style: buttonStyle,
                  onPressed: () async {
                    PlatformNavigator.navigateSlide(
                        context, const LabSearchMessage());
                  },
                  child: const Icon(MdiIcons.commentSearch),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BuildGroupWidget extends StatelessWidget {
  final String name;
  final Widget content;

  const _BuildGroupWidget({
    Key? key,
    required this.name,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
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
          margin: const EdgeInsets.fromLTRB(32, 20, 32, 10),
          // margin: EdgeInsets.only(left: 30, top: 100, right: 30, bottom: 50),
          // height: double.infinity,
          width: double.infinity,
          decoration: !Settings.themeFlat
              ? BoxDecoration(
                  // color: Colors.white,
                  color: Settings.themeWhat ? Colors.black26 : Colors.white,
                  borderRadius: const BorderRadius.only(
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
                      offset: const Offset(0, 3), // changes position of shadow
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
                          padding: const EdgeInsets.all(20.0), child: content)))
              : Padding(padding: const EdgeInsets.all(20.0), child: content),
        ),
      ],
    );
  }
}
