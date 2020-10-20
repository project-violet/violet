// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:ext_storage/ext_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/hitomi/shielder.dart';
import 'package:violet/database/user/download.dart';

class Settings {
  // Color Settings
  static Color themeColor; // default light
  static bool themeWhat; // default false == light
  static Color majorColor; // default purple
  static Color majorAccentColor;
  static int searchResultType; // 0: 3 Grid, 1: 2 Grid, 2: Big Line, 3: Detail

  // Tag Settings
  static String includeTags;
  static List<String> excludeTags;
  static List<String> blurredTags;
  static String language; // System Language

  // Like this Hitomi.la => e-hentai => exhentai => nhentai
  static List<String> routingRule; // image routing rule
  static List<String> searchRule;
  static bool searchNetwork;

  // Global? English? Korean?
  static String databaseType;

  // Reader Option
  static bool rightToLeft;
  static bool isHorizontal;
  static bool scrollVertical;
  static bool animation;
  static bool padding;
  static bool disableOverlayButton;
  static bool disableFullScreen;

  // Download Options
  static String downloadBasePath;

  static bool useVioletServer;

  static bool useDrawer;

  static Future<void> initFirst() async {
    var mc = (await SharedPreferences.getInstance()).getInt('majorColor');
    var mac =
        (await SharedPreferences.getInstance()).getInt('majorAccentColor');
    if (mc == null) {
      await (await SharedPreferences.getInstance())
          .setInt('majorColor', Colors.purple.value);
      mc = Colors.purple.value;
    }
    if (mac == null) {
      await (await SharedPreferences.getInstance())
          .setInt('majorAccentColor', Colors.purpleAccent.value);
      mac = Colors.purpleAccent.value;
    }
    majorColor = Color(mc);
    majorAccentColor = Color(mac);

    themeWhat = (await SharedPreferences.getInstance()).getBool('themeColor');
    if (themeWhat == null) {
      await (await SharedPreferences.getInstance())
          .setBool('themeColor', false);
      themeWhat = false;
    }
    if (!themeWhat)
      themeColor = Colors.white;
    else
      themeColor = Colors.black;
  }

  static Future<void> init() async {
    searchResultType =
        (await SharedPreferences.getInstance()).getInt('searchResultType');
    if (searchResultType == null) {
      await (await SharedPreferences.getInstance())
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
      await (await SharedPreferences.getInstance())
          .setString('includetags', includetags);
    }
    if (excludetags == null ||
        excludetags == MinorShielderFilter.tags.join('|')) {
      excludetags = '';
      await (await SharedPreferences.getInstance())
          .setString('excludetags', excludetags);
    }
    includeTags = includetags;
    excludeTags = excludetags.split('|').toList();
    blurredTags =
        blurredtags != null ? blurredtags.split(' ').toList() : List<String>();

    var routingrule =
        (await SharedPreferences.getInstance()).getString('routingrule');
    var searchrule =
        (await SharedPreferences.getInstance()).getString('searchrule');
    var searchnetwork =
        (await SharedPreferences.getInstance()).getBool('searchnetwork');

    if (routingrule == null) {
      routingrule = 'Hitomi|EHentai|ExHentai|Hiyobi|NHentai';

      await (await SharedPreferences.getInstance())
          .setString('routingrule', routingrule);
    }
    routingRule = routingrule.split('|');
    if (searchrule == null) {
      searchrule = 'Hitomi|EHentai|ExHentai|Hiyobi|NHentai';

      await (await SharedPreferences.getInstance())
          .setString('searchrule', searchrule);
    }
    searchRule = searchrule.split('|');
    if (searchnetwork == null) {
      searchnetwork = false;

      await (await SharedPreferences.getInstance())
          .setBool('searchnetwork', searchnetwork);
    }
    searchNetwork = searchnetwork;

    var databasetype =
        (await SharedPreferences.getInstance()).getString('databasetype');
    if (databasetype == null) {
      var langcode = Platform.localeName.split('_')[0];
      var acclc = ['ko', 'ja', 'en', 'ru', 'zh'];

      if (!acclc.contains(langcode)) langcode = 'global';

      databasetype = langcode;

      await (await SharedPreferences.getInstance())
          .setString('databasetype', langcode);
    }
    databaseType = databasetype;

    var right2left =
        (await SharedPreferences.getInstance()).getBool('right2left');
    if (right2left == null) {
      right2left = true;
      await (await SharedPreferences.getInstance())
          .setBool('right2left', right2left);
    }
    rightToLeft = right2left;

    isHorizontal =
        (await SharedPreferences.getInstance()).getBool('ishorizontal');
    if (isHorizontal == null) {
      isHorizontal = false;
      await (await SharedPreferences.getInstance())
          .setBool('ishorizontal', isHorizontal);
    }

    scrollVertical =
        (await SharedPreferences.getInstance()).getBool('scrollvertical');
    if (scrollVertical == null) {
      scrollVertical = false;
      await (await SharedPreferences.getInstance())
          .setBool('scrollvertical', scrollVertical);
    }

    animation = (await SharedPreferences.getInstance()).getBool('animation');
    if (animation == null) {
      animation = false;
      await (await SharedPreferences.getInstance())
          .setBool('animation', animation);
    }

    padding = (await SharedPreferences.getInstance()).getBool('padding');
    if (padding == null) {
      padding = false;
      await (await SharedPreferences.getInstance()).setBool('padding', padding);
    }

    disableOverlayButton =
        (await SharedPreferences.getInstance()).getBool('disableoverlaybutton');
    if (disableOverlayButton == null) {
      disableOverlayButton = false;
      await (await SharedPreferences.getInstance())
          .setBool('disableoverlaybutton', disableOverlayButton);
    }

    disableFullScreen =
        (await SharedPreferences.getInstance()).getBool('disablefullscreen');
    if (disableFullScreen == null) {
      disableFullScreen = false;
      await (await SharedPreferences.getInstance())
          .setBool('disablefullscreen', disableFullScreen);
    }

    if (Platform.isAndroid) {
      downloadBasePath =
          (await SharedPreferences.getInstance()).getString('downloadbasepath');
      final String path = await ExtStorage.getExternalStorageDirectory();
      if (downloadBasePath == null) {
        downloadBasePath = join(path, '.violet');
        await (await SharedPreferences.getInstance())
            .setString('downloadbasepath', downloadBasePath);
      }

      if (downloadBasePath == join(path, 'Violet') &&
          (await SharedPreferences.getInstance())
                  .getBool('downloadbasepathcc1') ==
              null) {
        downloadBasePath = join(path, '.violet');
        await (await SharedPreferences.getInstance())
            .setString('downloadbasepath', downloadBasePath);
        await (await SharedPreferences.getInstance())
            .setBool('downloadbasepathcc1', true);

        try {
          if (await Permission.storage.isGranted) {
            var prevDir = Directory(join(path, 'Violet'));
            if (await prevDir.exists()) {
              await prevDir.rename(join(path, '.violet'));
            }

            var downloaded =
                await (await Download.getInstance()).getDownloadItems();
            for (var download in downloaded) {
              Map<String, dynamic> result =
                  Map<String, dynamic>.from(download.result);
              if (download.files() != null)
                result['Files'] =
                    download.files().replaceAll('/Violet/', '/.violet/');
              if (download.path() != null)
                result['Path'] =
                    download.path().replaceAll('/Violet/', '/.violet/');
              download.result = result;
              await download.update();
            }
          }
        } catch (e, st) {
          Crashlytics.instance.recordError(e, st);
        }
      }
    }

    useVioletServer =
        (await SharedPreferences.getInstance()).getBool('usevioletserver');
    if (useVioletServer == null) {
      useVioletServer = false;
      await (await SharedPreferences.getInstance())
          .setBool('usevioletserver', useVioletServer);
    }

    useDrawer = (await SharedPreferences.getInstance()).getBool('usedrawer');
    if (useDrawer == null) {
      useDrawer = false;
      await (await SharedPreferences.getInstance())
          .setBool('usedrawer', useDrawer);
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

  static Future<void> setMajorColor(Color color) async {
    if (majorColor == color) return;

    await (await SharedPreferences.getInstance())
        .setInt('majorColor', color.value);
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

    await (await SharedPreferences.getInstance())
        .setInt('majorAccentColor', accent.value);
    majorAccentColor = accent;
  }

  static Future<void> setSearchResultType(int wh) async {
    searchResultType = wh;
    await (await SharedPreferences.getInstance())
        .setInt('searchResultType', searchResultType);
  }

  static Future<void> setLanguage(String lang) async {
    language = lang;
    await (await SharedPreferences.getInstance()).setString('language', lang);
  }

  static Future<void> setIncludeTags(String nn) async {
    includeTags = nn;
    await (await SharedPreferences.getInstance())
        .setString('includetags', includeTags);
  }

  static Future<void> setExcludeTags(String nn) async {
    excludeTags = nn.split(' ').toList();
    await (await SharedPreferences.getInstance())
        .setString('excludetags', excludeTags.join('|'));
  }

  static Future<void> setBlurredTags(String nn) async {
    blurredTags = nn.split(' ').toList();
    await (await SharedPreferences.getInstance())
        .setString('blurredtags', blurredTags.join('|'));
  }

  static Future<void> setRightToLeft(bool nn) async {
    rightToLeft = nn;
    await (await SharedPreferences.getInstance())
        .setBool('right2left', rightToLeft);
  }

  static Future<void> setIsHorizontal(bool nn) async {
    isHorizontal = nn;
    await (await SharedPreferences.getInstance())
        .setBool('ishorizontal', isHorizontal);
  }

  static Future<void> setScrollVertical(bool nn) async {
    scrollVertical = nn;
    await (await SharedPreferences.getInstance())
        .setBool('scrollvertical', scrollVertical);
  }

  static Future<void> setAnimation(bool nn) async {
    animation = nn;
    await (await SharedPreferences.getInstance())
        .setBool('animation', animation);
  }

  static Future<void> setPadding(bool nn) async {
    padding = nn;
    await (await SharedPreferences.getInstance()).setBool('padding', padding);
  }

  static Future<void> setDisableOverlayButton(bool nn) async {
    disableOverlayButton = nn;
    await (await SharedPreferences.getInstance())
        .setBool('disableoverlaybutton', disableOverlayButton);
  }

  static Future<void> setDisableFullScreen(bool nn) async {
    disableFullScreen = nn;
    await (await SharedPreferences.getInstance())
        .setBool('disablefullscreen', disableFullScreen);
  }

  static Future<void> setSearchOnWeb(bool nn) async {
    searchNetwork = nn;
    await (await SharedPreferences.getInstance()).setBool('searchnetwork', nn);
  }

  static Future<void> setUseVioletServer(bool nn) async {
    useVioletServer = nn;
    await (await SharedPreferences.getInstance())
        .setBool('usevioletserver', nn);
  }

  static Future<void> setUseDrawer(bool nn) async {
    useDrawer = nn;
    await (await SharedPreferences.getInstance()).setBool('usedrawer', nn);
  }
}
