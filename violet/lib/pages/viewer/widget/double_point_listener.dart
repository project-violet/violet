// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/pages/viewer/vertical_viewer_page.dart';

/// Raises an event when two or more fingers touch the screen.
class DoublePointListener extends StatefulWidget {
  final Widget child;
  final BoolCallback onStateChanged;

  const DoublePointListener({
    super.key,
    required this.child,
    required this.onStateChanged,
  });

  @override
  State<DoublePointListener> createState() => __DoublePointListener();
}

class __DoublePointListener extends State<DoublePointListener> {
  /// How many fingers are on the screen?
  int _mpPoints = 0;

  ///
  bool _onStateChanged = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _mpPoints++;
        if (_mpPoints >= 2) {
          if (_onStateChanged) {
            _onStateChanged = false;
            widget.onStateChanged(false);
          }
        }
      },
      onPointerUp: (event) {
        _mpPoints--;
        if (_mpPoints < 1) {
          _onStateChanged = true;
          widget.onStateChanged(true);
        }
      },
      onPointerCancel: (event) {
        _mpPoints = 0;
        _onStateChanged = true;
        widget.onStateChanged(true);
      },
      child: widget.child,
    );
  }
}
