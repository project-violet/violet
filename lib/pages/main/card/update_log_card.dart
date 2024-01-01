// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

/*

import 'package:division/division.dart';
import 'package:flutter/material.dart';
import 'package:gradient_widgets/gradient_widgets.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/main/card/update_card.dart';
import 'package:violet/pages/main/patchnote/patchnote_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';

class UpdateLogCard extends StatefulWidget {
  const UpdateLogCard({Key? key}) : super(key: key);

  @override
  State<UpdateLogCard> createState() => _UpdateLogCardState();
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
                    controller!.forward(from: 0.0);

                    PlatformNavigator.navigateSlide(
                        context, const PatchNotePage());
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
                      color: Gradients.taitanum.colors.first.withOpacity(.3),
                      spreadRadius: -9,
                    ),
                  ],
                ),
                child: GradientCard(
                  gradient: Gradients.taitanum,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          Translations.of(context).trans('patchnote'),
                          style: const TextStyle(color: Colors.white),
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
