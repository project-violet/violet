// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class Variables {
  static late String applicationDocumentsDirectory;

  static Future<void> init() async {
    applicationDocumentsDirectory =
        (await getApplicationDocumentsDirectory()).path;
  }

  static double statusBarHeight = 0;
  static double bottomBarHeight = 0;
  static void updatePadding(double statusBar, double bottomBar) {
    if (Platform.isAndroid) {
      if (statusBarHeight == 0 && statusBar > 0.1) {
        statusBarHeight = max(statusBarHeight, statusBar);
      }
      if (bottomBarHeight == 0 && bottomBar > 0.1 && bottomBar < 80) {
        bottomBarHeight = max(bottomBarHeight, bottomBar);
      }
    }
  }

  static double articleInfoHeight = 0;
  static void setArticleInfoHeight(double pad) {
    if (articleInfoHeight == 0 && pad > 0.1) articleInfoHeight = pad;
  }
}
