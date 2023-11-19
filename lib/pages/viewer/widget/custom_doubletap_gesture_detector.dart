// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/material.dart';

/// GestureDetector uses a delay to distinguish between tap events
/// and double taps. By default, this delay cannot be modified, so
/// I created a separate class.
class CustomDoubleTapGestureDectector extends StatefulWidget {
  final GestureTapDownCallback onTap;
  final GestureTapDownCallback onDoubleTap;
  final Duration doubleTapMaxDelay;

  const CustomDoubleTapGestureDectector({
    super.key,
    required this.onTap,
    required this.onDoubleTap,
    // ignore: unused_element
    this.doubleTapMaxDelay = const Duration(milliseconds: 200),
  });

  @override
  State<CustomDoubleTapGestureDectector> createState() =>
      _CustomDoubleTapGestureDectectorState();
}

class _CustomDoubleTapGestureDectectorState
    extends State<CustomDoubleTapGestureDectector> {
  /// these are used for double tap check
  Timer? _doubleTapCheckTimer;
  bool _isPressed = false;
  bool _isDoubleTap = false;
  bool _isSingleTap = false;

  /// this is used for onTap, onDoubleTap event
  late TapDownDetails _onTapDetails;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      onTapDown: (TapDownDetails details) {
        _onTapDetails = details;

        _isPressed = true;
        if (_doubleTapCheckTimer != null && _doubleTapCheckTimer!.isActive) {
          _isDoubleTap = true;
          _doubleTapCheckTimer!.cancel();
        } else {
          _doubleTapCheckTimer =
              Timer(widget.doubleTapMaxDelay, _doubleTapTimerElapsed);
        }
      },
      onTapCancel: () {
        _isPressed = _isSingleTap = _isDoubleTap = false;
        if (_doubleTapCheckTimer != null && _doubleTapCheckTimer!.isActive) {
          _doubleTapCheckTimer!.cancel();
        }
      },
    );
  }

  void _doubleTapTimerElapsed() {
    if (_isPressed) {
      _isSingleTap = true;
    } else {
      widget.onTap(_onTapDetails);
    }
  }

  void _handleTap() {
    _isPressed = false;
    if (_isSingleTap) {
      _isSingleTap = false;
      widget.onTap(_onTapDetails);
    }
    if (_isDoubleTap) {
      _isDoubleTap = false;
      widget.onDoubleTap(_onTapDetails);
    }
  }
}
