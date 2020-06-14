// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static Color themeColor; // default light
  static bool themeWhat; // default false == light
  static Color majorColor; // default purple
  static Color majorAccentColor;
  static int searchResultType; // 0: BigImage, 1: Grid, 2: Detail

  static Future<void> init() async {
    var mc = (await SharedPreferences.getInstance()).getInt('majorColor');
    var mac =
        (await SharedPreferences.getInstance()).getInt('majorAccentColor');
    if (mc == null) {
      (await SharedPreferences.getInstance())
          .setInt('majorColor', Colors.purple.value);
      mc = Colors.purple.value;
    }
    if (mac == null) {
      (await SharedPreferences.getInstance())
          .setInt('majorAccentColor', Colors.purpleAccent.value);
      mac = Colors.purpleAccent.value;
    }
    majorColor = Color(mc);
    majorAccentColor = Color(mac);

    themeWhat = (await SharedPreferences.getInstance()).getBool('themeColor');
    if (themeWhat == null) {
      (await SharedPreferences.getInstance()).setBool('themeColor', false);
      themeWhat = false;
    }
    if (!themeWhat)
      themeColor = Colors.white;
    else
      themeColor = Colors.black;

    searchResultType = (await SharedPreferences.getInstance()).getInt('searchResultType');
    if (searchResultType == null) {
      (await SharedPreferences.getInstance())
          .setInt('searchResultType', searchResultType);
      searchResultType = 1; 
    }
  }

  static Future<void> setThemeWhat(bool wh) async {
    themeWhat = wh;
    if (!themeWhat)
      themeColor = Colors.white;
    else
      themeColor = Colors.black;
    (await SharedPreferences.getInstance()).setBool('themeColor', themeWhat);
  }
}
