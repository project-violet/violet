// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:path_provider/path_provider.dart';

class Variables {
  static String applicationDocumentsDirectory;

  static Future<void> init() async {
    applicationDocumentsDirectory =
        (await getApplicationDocumentsDirectory()).path;
  }

  static double statusBarHeight = 0;
  static double bottomBarHeight = 0;
  static void updatePadding(double statusBar, double bottomBar) {
    statusBarHeight = max(statusBarHeight, statusBar);
    bottomBarHeight = max(bottomBarHeight, bottomBar);
  }
}
