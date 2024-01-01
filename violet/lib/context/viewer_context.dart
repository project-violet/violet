// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/pages/viewer/viewer_controller.dart';

typedef ViewerContextCallback = Future Function(ViewerController);

class ViewerContext {
  static final List<ViewerController> _c = <ViewerController>[];

  static void push(ViewerController c) {
    _c.add(c);
  }

  static void pop() {
    if (_c.isNotEmpty) {
      _c.removeLast();
    }
  }

  static void signal(ViewerContextCallback callback) {
    if (_c.isNotEmpty) {
      callback(_c.last);
    }
  }
}
