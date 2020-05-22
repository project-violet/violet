import 'dart:async';
import 'package:flutter/material.dart';
import 'package:violet/pages/afterloading_page.dart';

class SplashPage extends StatefulWidget {
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  startTime() async {
    var _duration = new Duration(seconds: 2);
    return new Timer(_duration, navigationPage);
  }

  void navigationPage() {
    Navigator.of(context).pushReplacementNamed('/AfterLoading');
    //Navigator.of(context).push(_createRoute());
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
        // var tween = Tween(begin: begin, end: end);
        // var offsetAnimation = animation.drive(tween);
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
        ;
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
