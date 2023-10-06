// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

/*

import 'package:division/division.dart';
import 'package:flutter/material.dart';
import 'package:gradient_widgets/gradient_widgets.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/main/artist_collection/artist_collection_page.dart';
import 'package:violet/pages/main/card/update_card.dart';
import 'package:violet/pages/segment/platform_navigator.dart';

class ArtistCollectionCard extends StatefulWidget {
  const ArtistCollectionCard({Key? key}) : super(key: key);

  @override
  State<ArtistCollectionCard> createState() => _ArtistCollectionCarddState();
}

class _ArtistCollectionCarddState extends State<ArtistCollectionCard>
    with TickerProviderStateMixin {
  bool pressed = false;

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
                    controller!.forward(from: 0.0);

                    PlatformNavigator.navigateSlide(
                        context, const ArtistCollectionPage());
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
                      offset: const Offset(0, 8),
                      color: Gradients.coldLinear.colors.first.withOpacity(.3),
                      spreadRadius: -9,
                    ),
                  ],
                ),
                child: GradientCard(
                  gradient: Gradients.coldLinear,
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
                          style: const TextStyle(
                              // fontFamily: "Calibre-Semibold",
                              // fontSize: 18,
                              color: Colors.white),
                        ),
                      ]),
                ),
              ));
        },
      ),
    );
  }

  ParentStyle settingsItemStyle(bool pressed) => ParentStyle()
    ..elevation(pressed ? 0 : 10000, color: Colors.transparent)
    ..scale(pressed ? 0.95 : 1.0)
    ..alignmentContent.center()
    // ..height(70)
    // ..margin(vertical: 10)
    // ..borderRadius(all: 15)
    // ..background.hex('#ffffff')
    ..ripple(true)
    ..animate(150, Curves.easeOut);

  ParentStyle settingsItemIconStyle(Color color) => ParentStyle()
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

 */
