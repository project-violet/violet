// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/settings/settings.dart';

class Palette {
  static const blackThemeBackground = Color(0xFF141414);
  static const darkThemeBackground = Color(0xFF353535);
  static final lightThemeBackground = Colors.grey.shade100;

  static Color get themeColor => Settings.themeWhat
      ? Settings.themeBlack
          ? Palette.blackThemeBackground
          : Palette.darkThemeBackground
      : Palette.lightThemeBackground;

  static Color get themeColorLightShallow => Settings.themeWhat
      ? Settings.themeBlack
          ? Palette.blackThemeBackground
          : Palette.darkThemeBackground
      : Colors.grey.shade200;
}
