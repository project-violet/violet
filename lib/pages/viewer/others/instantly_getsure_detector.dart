// https://github.com/ManuelRohrauer/inkwell_splash/blob/master/lib/inkwell_splash.dart

import 'package:flutter/material.dart';
import 'dart:async';

class InstantlyGestureDetector extends StatelessWidget {
  InstantlyGestureDetector({
    Key key,
    this.child,
    this.onTap,
    this.onDoubleTap,
    this.doubleTapTime = const Duration(milliseconds: 300),
    this.onLongPress,
    this.onTapDown,
    this.onTapCancel,
    this.behavior,
    this.excludeFromSemantics = false,
  })  : assert(excludeFromSemantics != null),
        super(key: key);

  final Widget child;
  final GestureTapCallback onTap;
  final GestureTapCallback onDoubleTap;
  final Duration doubleTapTime;
  final GestureLongPressCallback onLongPress;
  final GestureTapDownCallback onTapDown;
  final GestureTapCancelCallback onTapCancel;
  final bool excludeFromSemantics;
  final HitTestBehavior behavior;

  Timer doubleTapTimer;
  bool isPressed = false;
  bool isSingleTap = false;
  bool isDoubleTap = false;

  void _doubleTapTimerElapsed() {
    if (isPressed) {
      isSingleTap = true;
    } else {
      if (this.onTap != null) this.onTap();
    }
  }

  void _onTap() {
    isPressed = false;
    if (isSingleTap) {
      isSingleTap = false;
      if (this.onTap != null) this.onTap(); // call user onTap function
    }
    if (isDoubleTap) {
      isDoubleTap = false;
      if (this.onDoubleTap != null) this.onDoubleTap();
    }
  }

  void _onTapDown(TapDownDetails details) {
    isPressed = true;
    if (doubleTapTimer != null && doubleTapTimer.isActive) {
      isDoubleTap = true;
      doubleTapTimer.cancel();
    } else {
      doubleTapTimer = Timer(doubleTapTime, _doubleTapTimerElapsed);
    }
    if (this.onTapDown != null) this.onTapDown(details);
  }

  void _onTapCancel() {
    isPressed = isSingleTap = isDoubleTap = false;
    if (doubleTapTimer != null && doubleTapTimer.isActive) {
      doubleTapTimer.cancel();
    }
    if (this.onTapCancel != null) this.onTapCancel();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: key,
      child: child,
      behavior: behavior,
      onTap: (onDoubleTap != null)
          ? _onTap
          : onTap, // if onDoubleTap is not used from user, then route further to onTap
      onLongPress: onLongPress,
      onTapDown: (onDoubleTap != null) ? _onTapDown : onTapDown,
      onTapCancel: (onDoubleTap != null) ? _onTapCancel : onTapCancel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }
}
