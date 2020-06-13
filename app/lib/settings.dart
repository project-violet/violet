// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static Color themeColor; // default light
  static Color majorColor; // default purple
  static Color majorAccentColor;

  static Future<void> init() async {
    var mc = (await SharedPreferences.getInstance()).getInt('majorColor');
    var mac = (await SharedPreferences.getInstance()).getInt('majorAccentColor');
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

    var tc = (await SharedPreferences.getInstance()).getBool('themeColor');
    if (tc == null) {
      (await SharedPreferences.getInstance())
          .setBool('themeColor', false);
      tc = false;
    }
    if (!tc)
      themeColor = Colors.white;
    else
      themeColor = Colors.black;
  }
}
