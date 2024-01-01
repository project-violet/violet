// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';

class PlatformNavigator {
  static Future<T?> navigateFade<T>(BuildContext context, Widget page) async {
    if (!Platform.isIOS) {
      return await Navigator.of(context).push<T>(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget wi) {
            return FadeTransition(opacity: animation, child: wi);
          },
          pageBuilder: (_, __, ___) => page,
        ),
      );
    } else {
      return await Navigator.of(context).push<T>(CupertinoPageRoute(
        builder: (_) => page,
      ));
    }
  }

  static Future<T?> navigateSlide<T>(BuildContext context, Widget page,
      {bool opaque = true}) async {
    if (!Platform.isIOS) {
      return await Navigator.of(context).push<T>(PageRouteBuilder(
        opaque: opaque,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.ease;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        pageBuilder: (_, __, ___) => page,
      ));
    } else {
      return await Navigator.of(context)
          .push<T>(CupertinoPageRoute(builder: (_) => page));
    }
  }

  static Future<T?> navigateOption<T>(BuildContext context, Widget page) async {
    return await Navigator.of(context).push<T>(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation, Widget wi) {
          return FadeTransition(opacity: animation, child: wi);
        },
        pageBuilder: (_, __, ___) => page,
      ),
    );
  }
}
