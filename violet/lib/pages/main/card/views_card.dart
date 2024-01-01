// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

/*

import 'package:division/division.dart';
import 'package:flutter/material.dart';
import 'package:gradient_widgets/gradient_widgets.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/card/update_card.dart';
import 'package:violet/pages/main/views/views_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';

class ViewsCard extends StatefulWidget {
  const ViewsCard({Key? key}) : super(key: key);

  @override
  State<ViewsCard> createState() => _ViewsCardState();
}

class _ViewsCardState extends State<ViewsCard> with TickerProviderStateMixin {
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

                    if (!Settings.useVioletServer) {
                      await showOkDialog(context,
                          'To use this feature, turn on the Violet Server feature in Settings');
                      return;
                    }

                    PlatformNavigator.navigateSlide(context, const ViewsPage());
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
                      color:
                          Gradients.cosmicFusion.colors.first.withOpacity(.3),
                      spreadRadius: -9,
                    ),
                  ],
                ),
                child: GradientCard(
                  gradient: Gradients.cosmicFusion,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // SizedBox(
                        //   width: 50,
                        //   height: 50,
                        //   child: Transform.translate(
                        //     offset: Offset(-20, 0),
                        //     child: Transform.scale(
                        //       scale: 1.3,
                        //       child: Center(
                        //         child: Lottie.asset(
                        //           'assets/lottie/5040-shooting-star.json',
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
                          Translations.of(context).trans('realtimebest'),
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
