// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/pages/afterloading_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:violet/dialogs.dart';

class SplashPage extends StatefulWidget {
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  startTime() async {
    var _duration = new Duration(seconds: 2);
    return new Timer(_duration, navigationPage);
  }

  Future<void> navigationPage() async {
    if ((await SharedPreferences.getInstance()).getInt('db_exists') == 1)
      Navigator.of(context).pushReplacementNamed('/AfterLoading');
    else
      Navigator.of(context).pushReplacementNamed('/Test');
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

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Center(
        child: new Image.asset(
          'assets/images/logo.png',
          width: 100,
          height: 100,
        ),
      ),
      backgroundColor: Color(0x7FB200ED),
    );
  }
}
