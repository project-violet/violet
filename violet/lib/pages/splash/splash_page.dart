// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:io';
import 'package:circular_check_box/circular_check_box.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/update_sync.dart';

class SplashPage extends StatefulWidget {
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool showFirst = false;
  bool animateBox = false;
  bool languageBox = false;

  final imgSize = {
    'global': '320MB',
    'ko': '76MB',
    'en': '100MB',
    'jp': '165MB',
    'zh': '85MB',
  };

  final imgZipSize = {
    'global': '32MB',
    'ko': '9MB',
    'en': '10MB',
    'jp': '18MB',
    'zh': '9MB',
  };

  startTime() async {
    var _duration = new Duration(milliseconds: 600);
    return new Timer(_duration, navigationPage);
  }

  Future<void> navigationPage() async {
    await UpdateSyncManager.checkUpdateSync();

    if ((await SharedPreferences.getInstance()).getInt('db_exists') == 1)
      Navigator.of(context).pushReplacementNamed('/AfterLoading');
    else {
      await Future.delayed(Duration(milliseconds: 1400));
      setState(() {
        showFirst = true;
      });
      await Future.delayed(Duration(milliseconds: 400));
      setState(() {
        animateBox = true;
      });
      await Future.delayed(Duration(milliseconds: 200));
      setState(() {
        languageBox = true;
      });
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        scale1 = 1.03;
      });
    }
  }

  Future<void> checkAuth() async {
    if (await Permission.storage.isUndetermined) {
      if (await Permission.storage.request() == PermissionStatus.denied) {
        await Dialogs.okDialog(context, "파일 권한을 허용하지 않으면 다운로드 기능을 이용할 수 없습니다.");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    startTime();
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          AfterLoadingPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(0.0, 1.0);
        var end = Offset.zero;
        var curve = Curves.ease;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  bool userlangCheck = true;
  bool globalCheck = false;
  double scale1 = 1.0;
  double scale2 = 1.0;

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return new Scaffold(
      body: Stack(
        children: <Widget>[
          AnimatedPositioned(
            duration: Duration(milliseconds: 1000),
            curve: Curves.ease,
            top: showFirst ? 130 : height / 2 - 50,
            left: width / 2 - 50,
            child: new Image.asset(
              'assets/images/logo.png',
              width: 100,
              height: 100,
            ),
          ),
          Visibility(
            visible: showFirst,
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(top: 140),
                child: Card(
                  elevation: 100,
                  color: Colors.purple.shade50,
                  child: AnimatedOpacity(
                    opacity: animateBox ? 1.0 : 0,
                    duration: Duration(milliseconds: 500),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 500),
                      curve: Curves.ease,
                      width: animateBox ? 300 : 300,
                      height: animateBox ? 300 : 0,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 900),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            horizontalOffset: 50.0,
                            child: FadeInAnimation(
                              child: widget,
                            ),
                          ),
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  MdiIcons.database,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                Container(
                                  padding: EdgeInsets.all(4),
                                ),
                                Expanded(
                                    child: Text(
                                  Translations.of(context).trans('welcome'),
                                  maxLines: 4,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                            ),
                            AnimatedContainer(
                              transform: Matrix4.identity()
                                ..translate(300 / 2, 50 / 2)
                                ..scale(scale1)
                                ..translate(-300 / 2, -50 / 2),
                              duration: Duration(milliseconds: 300),
                              child: Card(
                                elevation: 4,
                                child: InkWell(
                                  customBorder: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(3.0))),
                                  child: ListTile(
                                    leading: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                        maxWidth: 44,
                                        maxHeight: 44,
                                      ),
                                      child: CircularCheckBox(
                                        value: userlangCheck,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.padded,
                                        onChanged: (bool value) {
                                          setState(() {
                                            scale1 = 1.03;
                                            scale2 = 1.0;
                                            if (userlangCheck) return;
                                            userlangCheck = !userlangCheck;
                                            globalCheck = false;
                                          });
                                        },
                                      ),
                                    ),
                                    dense: true,
                                    title: Text(
                                        Translations.of(context)
                                            .trans('dbuser'),
                                        style: TextStyle(fontSize: 14)),
                                    subtitle: Text(
                                        '${imgZipSize['ko']}${Translations.of(context).trans('dbdownloadsize')}',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  onTapDown: (detail) {
                                    setState(() {
                                      scale1 = 0.95;
                                    });
                                  },
                                  onTap: () {
                                    setState(() {
                                      scale1 = 1.03;
                                      scale2 = 1.0;
                                      if (userlangCheck) return;
                                      userlangCheck = !userlangCheck;
                                      globalCheck = false;
                                    });
                                  },
                                  onLongPress: () async {
                                    setState(() {
                                      if (userlangCheck)
                                        scale1 = 1.03;
                                      else
                                        scale1 = 1.0;
                                    });
                                    await Dialogs.okDialog(
                                        context,
                                        Translations.of(context)
                                            .trans('dbusermsg')
                                            .replaceFirst(
                                                '%s',
                                                imgSize[Translations.of(context)
                                                    .locale
                                                    .languageCode]));
                                  },
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              transform: Matrix4.identity()
                                ..translate(300 / 2, 50 / 2)
                                ..scale(scale2)
                                ..translate(-300 / 2, -50 / 2),
                              child: Card(
                                elevation: 4,
                                child: InkWell(
                                  customBorder: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(3.0))),
                                  child: ListTile(
                                    leading: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                        maxWidth: 44,
                                        maxHeight: 44,
                                      ),
                                      child: CircularCheckBox(
                                        value: globalCheck,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.padded,
                                        onChanged: (bool value) {
                                          setState(() {
                                            scale2 = 1.03;
                                            scale1 = 1.0;
                                            if (globalCheck) return;
                                            globalCheck = !globalCheck;
                                            userlangCheck = false;
                                          });
                                        },
                                      ),
                                    ),
                                    dense: true,
                                    title: Text(
                                        Translations.of(context)
                                            .trans('dballname'),
                                        style: TextStyle(fontSize: 14)),
                                    subtitle: Text(
                                        '${imgZipSize['global']}${Translations.of(context).trans('dbdownloadsize')}',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  onTapDown: (detail) {
                                    setState(() {
                                      scale2 = 0.95;
                                    });
                                  },
                                  onTap: () {
                                    setState(() {
                                      scale2 = 1.03;
                                      scale1 = 1.0;
                                      if (globalCheck) return;
                                      globalCheck = !globalCheck;
                                      userlangCheck = false;
                                    });
                                  },
                                  onLongPress: () async {
                                    setState(() {
                                      if (globalCheck)
                                        scale2 = 1.03;
                                      else
                                        scale2 = 1.0;
                                    });
                                    await Dialogs.okDialog(
                                        context,
                                        Translations.of(context)
                                            .trans('dballmsg')
                                            .replaceFirst(
                                                '%s', imgSize['global']));
                                  },
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(0, 0, 16, 0),
                                child: RaisedButton(
                                  textColor: Colors.white,
                                  child: SizedBox(
                                    width: 90,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        Text(Translations.of(context)
                                            .trans('download')),
                                        Icon(Icons.keyboard_arrow_right),
                                      ],
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (globalCheck) {
                                      if (!await Dialogs.yesnoDialog(
                                          context,
                                          Translations.of(context)
                                              .trans('dbwarn'),
                                          Translations.of(context)
                                              .trans('warning'))) {
                                        return;
                                      }
                                    }
                                    Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DataBaseDownloadPage(
                                                  dbType: globalCheck
                                                      ? 'global'
                                                      : Translations.of(context)
                                                          .locale
                                                          .languageCode,
                                                  isExistsDataBase: false,
                                                )));
                                  },
                                  color: Colors.purple.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: languageBox ? 1.0 : 0.0,
            duration: Duration(milliseconds: 700),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 100),
                child: GestureDetector(
                  child: SizedBox(
                    child: Text(Translations.of(context).trans('dbalready'),
                        style: TextStyle(
                            color: Colors.purpleAccent.shade100,
                            fontSize: 12.0)),
                  ),
                  onTap: () async {
                    var path = await getFile();

                    if (path == '') return;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => DataBaseDownloadPage(
                              dbType: globalCheck
                                  ? 'global'
                                  : Translations.of(context)
                                      .locale
                                      .languageCode,
                              isExistsDataBase: true,
                              dbPath: path,
                            )));
                  },
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: languageBox ? 1.0 : 0.0,
            duration: Duration(milliseconds: 700),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 40),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8.0))),
                  child: SizedBox(
                    width: 150,
                    height: 50,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.language,
                          size: 35,
                          color: Colors.white70,
                        ),
                        Text('  Language',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold))
                      ],
                    ),
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Color(0x7FB200ED),
    );
  }

  Future<String> getFile() async {
    File file;
    file = await FilePicker.getFile(
      type: FileType.any,
    );

    if (file == null) {
      await Dialogs.okDialog(
          context, Translations.of(context).trans('dbalreadyerr'));
      return '';
    }

    return file.path;
  }
}
