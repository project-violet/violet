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
import 'package:violet/component/hitomi/artists.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/main/artist_collection/artist_collection_page.dart';
import 'package:violet/pages/main/card/update_card.dart';

class ArtistCollectionCard extends StatefulWidget {
  @override
  _ArtistCollectionCarddState createState() => _ArtistCollectionCarddState();
}

class _ArtistCollectionCarddState extends State<ArtistCollectionCard>
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
                ..isTap((isTapped) {
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
                        pageBuilder: (_, __, ___) => ArtistCollectionPage(),
                      ));
                    } else {
                      Navigator.of(context).push(CupertinoPageRoute(
                          builder: (_) => ArtistCollectionPage()));
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
                      color: Gradients.coldLinear.colors.first.withOpacity(.3),
                      spreadRadius: -9,
                    ),
                  ],
                ),
                child: GradientCard(
                  gradient: Gradients.coldLinear,
                  child: Container(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // SizedBox(
                          //   width: 50,
                          //   height: 50,
                          //   child: Transform.translate(
                          //     offset: Offset(-10, -20),
                          //     child: Transform.scale(
                          //       scale: 3.8,
                          //       child: Center(
                          //         child: Lottie.asset(
                          //           'assets/lottie/28446-floward-gift-box.json',
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          //   // Icon(
                          //   //   MdiIcons.group,
                          //   //   color: Colors.white,
                          //   //   size: 30,
                          //   // ),
                          // ),
                          Text(
                            Translations.of(context).trans('artistcollection'),
                            style: TextStyle(
                                // fontFamily: "Calibre-Semibold",
                                // fontSize: 18,
                                color: Colors.white),
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
