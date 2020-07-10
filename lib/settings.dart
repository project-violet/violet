// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/hitomi/shielder.dart';

class Settings {
  static Color themeColor; // default light
  static bool themeWhat; // default false == light
  static Color majorColor; // default purple
  static Color majorAccentColor;
  static int searchResultType; // 0: 3 Grid, 1: 2 Grid, 2: Big Line, 3: Detail
  static String includeTags;
  static List<String> excludeTags;
  static List<String> blurredTags;
  static String language; // System Language
  static List<String> routingRule;

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

    searchResultType =
        (await SharedPreferences.getInstance()).getInt('searchResultType');
    if (searchResultType == null) {
      (await SharedPreferences.getInstance())
          .setInt('searchResultType', searchResultType);
      searchResultType = 0;
    }

    language = (await SharedPreferences.getInstance()).getString('language');
    // majorColor = Color(0xFF5656E7);

    var includetags =
        (await SharedPreferences.getInstance()).getString('includetags');
    var excludetags =
        (await SharedPreferences.getInstance()).getString('excludetags');
    var blurredtags =
        (await SharedPreferences.getInstance()).getString('blurredtags');
    if (includetags == null) {
      var language = 'lang:english';
      var langcode = Platform.localeName.split('_')[0];
      if (langcode == 'ko')
        language = 'lang:korean';
      else if (langcode == 'ja')
        language = 'lang:japanese';
      else if (langcode == 'zh') language = 'lang:chinese';
      includetags = '($language or lang:n/a)';
      (await SharedPreferences.getInstance())
          .setString('includetags', includetags);
    }
    if (excludetags == null) {
      excludetags = MinorShielderFilter.tags.join('|');
      (await SharedPreferences.getInstance())
          .setString('excludetags', excludetags);
    }
    includeTags = includetags;
    excludeTags = excludetags.split('|').toList();
    blurredTags =
        blurredtags != null ? blurredtags.split(' ').toList() : List<String>();

    var routingrule =
        (await SharedPreferences.getInstance()).getString('routingrule');

    if (routingrule == null) {
      routingrule = 'Hitomi|ExHentai|EHentai|Hiyobi|NHentai';

      (await SharedPreferences.getInstance())
          .setString('routingrule', routingrule);
    }
    routingRule = routingrule.split('|');
  }

  static Future<void> setThemeWhat(bool wh) async {
    themeWhat = wh;
    if (!themeWhat)
      themeColor = Colors.white;
    else
      themeColor = Colors.black;
    (await SharedPreferences.getInstance()).setBool('themeColor', themeWhat);
  }

  static Future<void> setMajorColor(Color color) async {
    if (majorColor == color) return;

    (await SharedPreferences.getInstance()).setInt('majorColor', color.value);
    majorColor = color;

    Color accent;
    for (int i = 0; i < Colors.primaries.length - 2; i++)
      if (color.value == Colors.primaries[i].value) {
        accent = Colors.accents[i];
        break;
      }

    if (accent == null) {
      if (color == Colors.grey)
        accent = Colors.grey.shade700;
      else if (color == Colors.brown)
        accent = Colors.brown.shade700;
      else if (color == Colors.blueGrey)
        accent = Colors.blueGrey.shade700;
      else if (color == Colors.black) accent = Colors.black;
    }

    (await SharedPreferences.getInstance())
        .setInt('majorAccentColor', accent.value);
    majorAccentColor = accent;
  }

  static Future<void> setSearchResultType(int wh) async {
    searchResultType = wh;
    (await SharedPreferences.getInstance())
        .setInt('searchResultType', searchResultType);
  }

  static Future<void> setLanguage(String lang) async {
    language = lang;
    (await SharedPreferences.getInstance()).setString('language', lang);
  }

  static Future<void> setIncludeTags(String nn) async {
    includeTags = nn;
    (await SharedPreferences.getInstance())
        .setString('includetags', includeTags);
  }

  static Future<void> setExcludeTags(String nn) async {
    excludeTags = nn.split(' ').toList();
    (await SharedPreferences.getInstance())
        .setString('excludetags', excludeTags.join('|'));
  }

  static Future<void> setBlurredTags(String nn) async {
    blurredTags = nn.split(' ').toList();
    (await SharedPreferences.getInstance())
        .setString('blurredtags', blurredTags.join('|'));
  }
}
