// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'package:circular_check_box/circular_check_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/pages/afterloading_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:violet/dialogs.dart';

class SplashPage extends StatefulWidget {
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Alignment align = Alignment.center;
  EdgeInsetsGeometry pp = EdgeInsets.only(top: 0.0);
  bool showFirst = false;
  bool animateBox = false;
  bool languageBox = false;

  startTime() async {
    var _duration = new Duration(milliseconds: 600);
    return new Timer(_duration, navigationPage);
  }

  Future<void> navigationPage() async {
    if ((await SharedPreferences.getInstance()).getInt('db_exists') == 1)
      Navigator.of(context).pushReplacementNamed('/AfterLoading');
    else {
      await Future.delayed(Duration(milliseconds: 1400));
      setState(() {
        align = Alignment.topCenter;
        pp = EdgeInsets.only(top: 130.0);
        showFirst = true;
      });
      await Future.delayed(Duration(milliseconds: 600));
      setState(() {
        animateBox = true;
      });
      await Future.delayed(Duration(milliseconds: 400));
      setState(() {
        languageBox = true;
      });
      // Navigator.of(context).pushReplacementNamed('/DatabaseDownload');
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
    SchedulerBinding.instance.addPostFrameCallback(
        (_) async => checkAuth().whenComplete(() => startTime()));
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          AfterLoadingPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(0.0, 1.0);
        var end = Offset.zero;
        var curve = Curves.ease;
        // var tween = Tween(begin: begin, end: end);
        // var offsetAnimation = animation.drive(tween);
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

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: Stack(
        children: <Widget>[
          AnimatedContainer(
            duration: Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            alignment: align,
            padding: pp,
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
                                'Violet 사용을 환영합니다. 이 앱을 사용하기 전에 먼저 데이터베이스를 다운로드해야 합니다.',
                                maxLines: 4,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                            ],
                          ),
                          // CircularCheckBox(
                          //     value: testCheck,
                          //     materialTapTargetSize: MaterialTapTargetSize.padded,
                          //     onChanged: (bool x) {
                          //       setState(() {
                          //         testCheck = !testCheck;
                          //       });
                          //     }),
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                          ),
                          Card(
                            elevation: 4,
                            child: InkWell(
                              customBorder: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3.0))),
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
                                        if (userlangCheck) return;
                                        userlangCheck = !userlangCheck;
                                        globalCheck = false;
                                      });
                                    },
                                  ),
                                ),
                                dense: true,
                                title: Text("한국어 데이터 베이스",
                                    style: TextStyle(fontSize: 14)),
                                subtitle: Text('79MB의 추가 저장공간 필요',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              onTap: () {
                                setState(() {
                                  if (userlangCheck) return;
                                  userlangCheck = !userlangCheck;
                                  globalCheck = false;
                                });
                              },
                              onLongPress: () async {
                                await Dialogs.okDialog(
                                    context,
                                    '사용자 언어와 n/a가 포함된 데이터베이스팩입니다. 이 데이터베이스는 현재 최신 데이터가 들어있지만, ' +
                                        '데이터베이스를 최신상태로 유지하려면 안내에 따라 데이터를 동기화해야합니다.');
                              },
                            ),
                          ),
                          Card(
                            elevation: 4,
                            child: InkWell(
                              customBorder: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3.0))),
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
                                        if (globalCheck) return;
                                        globalCheck = !globalCheck;
                                        userlangCheck = false;
                                      });
                                    },
                                  ),
                                ),
                                dense: true,
                                title: Text("모든 언어 데이터 베이스",
                                    style: TextStyle(fontSize: 14)),
                                subtitle: Text('314MB의 추가 저장공간 필요',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              onTap: () {
                                setState(() {
                                  if (globalCheck) return;
                                  globalCheck = !globalCheck;
                                  userlangCheck = false;
                                });
                              },
                              onLongPress: () async {
                                await Dialogs.okDialog(
                                    context,
                                    '모든 언어가 포함된 데이터베이스팩입니다. 이 데이터베이스는 현재 최신 데이터가 들어있지만, ' +
                                        '데이터베이스를 최신상태로 유지하려면 안내에 따라 데이터를 동기화해야합니다.');
                              },
                            ),
                          ),
                          Expanded(child: Container()),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 16, 0),
                              child: RaisedButton(
                                child: SizedBox(
                                  width: 60,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      Text('다음'),
                                      Icon(Icons.keyboard_arrow_right),
                                    ],
                                  ),
                                ),
                                onPressed: () {},
                                color: Colors.purple.shade200,
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
                        // Container(
                        //   padding: EdgeInsets.symmetric(vertical: 4),
                        // ),
                        // Container(width: 4,),
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
}
