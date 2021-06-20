// https://github.com/jhontona/animated-floatbuttons/
// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/settings/settings.dart';

class TransformFloatButton extends StatelessWidget {
  final Widget floatButton;
  final double translateValue;

  TransformFloatButton({this.floatButton, this.translateValue})
      : super(key: ObjectKey(floatButton));

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.translationValues(
        0.0,
        translateValue,
        0.0,
      ),
      child: Transform.scale(
        scale: 0.8,
        child: floatButton,
      ),
    );
  }
}

class AnimatedFloatingActionButton extends StatefulWidget {
  final List<Widget> fabButtons;
  final AnimatedIconData animatedIconData;
  final VoidCallback exitCallback;

  AnimatedFloatingActionButton({
    Key key,
    this.fabButtons,
    this.animatedIconData,
    this.exitCallback,
  }) : super(key: key);

  @override
  _AnimatedFloatingActionButtonState createState() =>
      _AnimatedFloatingActionButtonState();
}

class _AnimatedFloatingActionButtonState
    extends State<AnimatedFloatingActionButton>
    with SingleTickerProviderStateMixin {
  bool isOpened = true;
  AnimationController _animationController;
  Animation<double> _animateIcon;
  Animation<double> _translateButton;
  Curve _curve = Curves.easeOut;
  double _fabHeight = 56.0;

  @override
  initState() {
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300))
          ..addListener(() {
            setState(() {});
          });
    _animateIcon =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _translateButton = Tween<double>(
      begin: _fabHeight,
      end: -14.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        0.0,
        0.75,
        curve: _curve,
      ),
    ));
    super.initState();
    _animationController.forward();
  }

  @override
  dispose() {
    _animationController.dispose();
    super.dispose();
  }

  animate() {
    if (!isOpened) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    isOpened = !isOpened;
    widget.exitCallback();
  }

  Widget toggle() {
    return Container(
      child: FloatingActionButton(
        backgroundColor:
            Settings.themeWhat ? Colors.grey.shade800 : Colors.grey.shade100,
        onPressed: animate,
        elevation: 2,
        foregroundColor: Settings.majorColor,
        child: AnimatedIcon(
          icon: widget.animatedIconData,
          progress: _animateIcon,
        ),
      ),
    );
  }

  List<Widget> _setFabButtons() {
    final processButtons = <Widget>[];
    for (int i = 0; i < widget.fabButtons.length; i++) {
      processButtons.add(TransformFloatButton(
        floatButton: widget.fabButtons[i],
        translateValue: _translateButton.value * (widget.fabButtons.length - i),
      ));
    }
    processButtons.add(toggle());
    return processButtons;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: _setFabButtons(),
    );
  }
}
