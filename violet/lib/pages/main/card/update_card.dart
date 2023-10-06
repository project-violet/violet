// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

/*

import 'dart:math';

import 'package:division/division.dart';
import 'package:flutter/material.dart';
import 'package:gradient_widgets/gradient_widgets.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pimp_my_button/pimp_my_button.dart';

class UpdateCard extends StatefulWidget {
  final VoidCallback clickEvent;

  const UpdateCard({Key? key, required this.clickEvent}) : super(key: key);

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> with TickerProviderStateMixin {
  bool pressed = false;
  late AnimationController rotationController;

  @override
  void initState() {
    super.initState();
    rotationController = AnimationController(
      duration: const Duration(milliseconds: 270),
      vsync: this,
      // upperBound: pi * 2,
    );
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
                  if (isTapped) {
                    rotationController.forward(from: 0.0);
                  } else {
                    rotationController.reverse(from: 0.7);
                  }
                  setState(() => pressed = isTapped);
                  controller!.forward(from: 0.0);
                  Future.delayed(const Duration(milliseconds: 200),
                      () => controller.forward(from: 0.0));
                  // Future.delayed(Duration(milliseconds: 200),
                  //     () => controller.forward(from: 0.0));
                  // Future.delayed(Duration(milliseconds: 300),
                  //     () => controller.forward(from: 0.0));
                  widget.clickEvent();
                }),
              child: Container(
                decoration: BoxDecoration(
                  // color: Color(0xff00D99E),
                  borderRadius: BorderRadius.circular(8),
                  // gradient: LinearGradient(
                  //   begin: Alignment.bottomLeft,
                  //   end: Alignment(0.8, 0.0),
                  //   colors: [
                  //     Gradients.backToFuture.colors.first.withOpacity(.3),
                  //     Colors.indigo.withOpacity(.3),
                  //     Gradients.backToFuture.colors.last.withOpacity(.3)
                  //   ],
                  //   tileMode: TileMode.clamp,
                  // ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 15),
                      color:
                          Gradients.backToFuture.colors.first.withOpacity(.3),
                      spreadRadius: -9,
                    ),
                  ],
                ),
                child: GradientCard(
                  gradient: Gradients.aliHussien,
                  // shadowColor: Gradients.backToFuture.colors.last.withOpacity(0.2),
                  // elevation: 8,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: RotationTransition(
                            turns: Tween(begin: 0.0, end: 0.7)
                                .animate(rotationController),
                            child: const Icon(
                              MdiIcons.update,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '  Tap Me!',
                            style: TextStyle(
                                fontFamily: 'Calibre-Semibold',
                                fontSize: 18,
                                color: Colors.white),
                          ),
                        ),
                      ]
                      // child: Text(
                      //   // 'New Version',
                      //   '',
                      //   style: TextStyle(
                      //     fontSize: 30,
                      //     fontWeight: FontWeight.bold,
                      //     fontFamily: "Calibre-Semibold",
                      //     // letterSpacing: 1.0,
                      //   ),
                      // ),
                      ),
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

class MyRectangle2DemoParticle extends Particle {
  @override
  void paint(Canvas canvas, Size size, progress, seed) {
    Random random = Random(seed);
    int randomMirrorOffset = random.nextInt(10) + 1;
    CompositeParticle(children: [
      Firework(),
      RectangleMirror.builder(
          numberOfParticles: random.nextInt(6) + 4,
          particleBuilder: (int int) {
            return AnimatedPositionedParticle(
              begin: const Offset(0.0, -10.0),
              end: const Offset(0.0, -60.0),
              child:
                  FadingRect(width: 5.0, height: 15.0, color: intToColor(int)),
            );
          },
          initialDistance: -pi / randomMirrorOffset),
    ]).paint(canvas, size, progress, seed);
  }
}

 */
