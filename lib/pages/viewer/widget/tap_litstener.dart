// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CustomDelayTapListener extends StatelessWidget {
  final VoidCallback onTap;
  final Duration delay;

  const CustomDelayTapListener({
    super.key,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _FastTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_FastTapGestureRecognizer>(
          () => _FastTapGestureRecognizer(delay),
          (_FastTapGestureRecognizer instance) {
            instance.onTap = onTap;
          },
        ),
      },
    );
  }
}

// https://github.com/flutter/flutter/issues/106170#issuecomment-1551417220

class _FastTapGestureRecognizer extends TapGestureRecognizer {
  final Duration delay;
  _FastTapGestureRecognizer(this.delay);

  /// Timer to keep track of the last tap up event
  Timer? _lastTapUpEvent;

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      _lastTapUpEvent?.cancel();
      _lastTapUpEvent = null;
    }
    if (event is PointerUpEvent) {
      _lastTapUpEvent = Timer(
        delay,
        () {
          resolve(GestureDisposition.accepted);
          // acceptGesture(event.pointer);
        },
      );
    }
    super.handleEvent(event);
  }
}
