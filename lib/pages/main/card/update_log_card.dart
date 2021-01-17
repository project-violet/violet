// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:ui';

import 'package:division/division.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gradient_widgets/gradient_widgets.dart';
import 'package:lottie/lottie.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/artist_collection/artist_collection_page.dart';
import 'package:violet/pages/main/card/update_card.dart';
import 'package:violet/pages/main/patchnote/patchnote_page.dart';
import 'package:violet/pages/main/views/views_page.dart';
import 'package:violet/settings/settings.dart';

class UpdateLogCard extends StatefulWidget {
  @override
  _UpdateLogCardState createState() => _UpdateLogCardState();
}

class _UpdateLogCardState extends State<UpdateLogCard>
    with TickerProviderStateMixin {
  bool pressed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width - 16,
      height: 75,
      child: PimpedButton(
        particle: MyRectangle2DemoParticle(),
        pimpedWidgetBuilder: (context, controller) {
          return Parent(
              style: settingsItemStyle(pressed),
              gesture: Gestures()
                ..isTap((isTapped) async {
                  setState(() => pressed = isTapped);
                  if (!isTapped) {
                    controller.forward(from: 0.0);

                    if (!Platform.isIOS) {
                      Navigator.of(context).push(PageRouteBuilder(
                        transitionDuration: Duration(milliseconds: 500),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          var begin = Offset(0.0, 1.0);
                          var end = Offset.zero;
                          var curve = Curves.ease;

                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));

                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                        pageBuilder: (_, __, ___) => PatchNotePage(),
                      ));
                    } else {
                      Navigator.of(context).push(
                          CupertinoPageRoute(builder: (_) => PatchNotePage()));
                    }
                  }
                }),
              child: Container(
                height: 75,
                decoration: BoxDecoration(
                  // color: Color(0xff00D99E),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: Offset(0, 8),
                      color: Gradients.taitanum.colors.first.withOpacity(.3),
                      spreadRadius: -9,
                    ),
                  ],
                ),
                child: GradientCard(
                  gradient: Gradients.taitanum,
                  child: Container(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            Translations.of(context).trans('patchnote'),
                            style: TextStyle(color: Colors.white),
                          ),
                        ]),
                  ),
                ),
              ));
        },
      ),
    );
  }

  final settingsItemStyle = (pressed) => ParentStyle()
    ..elevation(pressed ? 0 : 10000, color: Colors.transparent)
    ..scale(pressed ? 0.95 : 1.0)
    ..alignmentContent.center()
    // ..height(70)
    // ..margin(vertical: 10)
    // ..borderRadius(all: 15)
    // ..background.hex('#ffffff')
    ..ripple(true)
    ..animate(150, Curves.easeOut);

  final settingsItemIconStyle = (Color color) => ParentStyle()
    ..background.color(color)
    ..margin(left: 15)
    ..padding(all: 12)
    ..borderRadius(all: 30);

  final TxtStyle itemTitleTextStyle = TxtStyle()
    ..bold()
    ..fontSize(16);

  final TxtStyle itemDescriptionTextStyle = TxtStyle()
    ..textColor(Colors.black26)
    ..bold()
    ..fontSize(12);
}
