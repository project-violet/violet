// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/hitomi/shielder.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/log/log.dart';
import 'package:violet/settings/device_type.dart';

class Settings {
  // Color Settings
  static Color themeColor; // default light
  static bool themeWhat; // default false == light
  static Color majorColor; // default purple
  static Color majorAccentColor;
  static int searchResultType; // 0: 3 Grid, 1: 2 Grid, 2: Big Line, 3: Detail
  static int downloadResultType;
  static int downloadAlignType;
  static bool themeFlat;
  static bool themeBlack; // default false
  static bool useTabletMode;

  // Tag Settings
  static String includeTags;
  static List<String> excludeTags;
  static List<String> blurredTags;
  static String language; // System Language
  static bool translateTags;

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
  static bool enableTimer;
  static double timerTick;
  static bool moveToAppBarToBottom;
  static bool showSlider;
  static int imageQuality;
  static int thumbSize;
  static bool enableThumbSlider;
  static bool showPageNumberIndicator;
  static bool showRecordJumpMessage;

  // Download Options
  static bool useInnerStorage;
  static String downloadBasePath;
  static String downloadRule;

  static String searchMessageAPI;
  static bool useVioletServer;

  static bool useDrawer;

  static bool useOptimizeDatabase;

  static bool useLowPerf;

  // View Option
  static bool showArticleProgress;

  // Search Option
  static bool searchUseFuzzy;
  static bool searchTagTranslation;
  static bool searchUseTranslated;
  static bool searchShowCount;
  static bool searchPure;

  static String userAppId;

  static bool autobackupBookmark;

  // Lab
  static bool simpleItemWidgetLoadingIcon;
  static bool showNewViewerWhenArtistArticleListItemTap;
  static bool enableViewerFunctionBackdropFilter;
  static bool usingPushReplacementOnArticleRead;
  static bool downloadEhRawImage;

  static bool useLockScreen;
  static bool useSecureMode;

  static Future<void> initFirst() async {
    var mc = await _getInt('majorColor', Colors.purple.value);
    var mac = await _getInt('majorAccentColor', Colors.purpleAccent.value);

    majorColor = Color(mc);
    majorAccentColor = Color(mac);

    themeWhat = await _getBool('themeColor');
    themeColor = !themeWhat ? Colors.white : Colors.black;
    themeFlat = await _getBool('themeFlat');
    themeBlack = await _getBool('themeBlack');

    language = (await SharedPreferences.getInstance()).getString('language');

    useLockScreen = await _getBool('useLockScreen');
    useSecureMode = await _getBool('useSecureMode');
    await _setSecureMode();

    await _getInt('thread_count', 4);
  }

  static Future<void> _setSecureMode() async {
    if (Platform.isAndroid) {
      if (Settings.useSecureMode) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    }
  }

  static Future<void> init() async {
    searchResultType = await _getInt('searchResultType');
    downloadResultType = await _getInt('downloadResultType', 3);
    downloadAlignType = await _getInt('downloadAlignType', 0);

    var includetags =
        (await SharedPreferences.getInstance()).getString('includetags');
    var excludetags =
        (await SharedPreferences.getInstance()).getString('excludetags');
    var blurredtags =
        (await SharedPreferences.getInstance()).getString('blurredtags');
    if (includetags == null) {
      var language = 'lang:english';
      var langcode = Platform.localeName.split('_')[0];
      if (langcode == 'ko') {
        language = 'lang:korean';
      } else if (langcode == 'ja') {
        language = 'lang:japanese';
      } else if (langcode == 'zh') {
        language = 'lang:chinese';
      }
      includetags = '($language)';
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
    blurredTags = blurredtags != null ? blurredtags.split(' ').toList() : [];
    translateTags = await _getBool('translatetags');

    routingRule = (await _getString(
            'routingrule', 'Hitomi|EHentai|ExHentai|Hiyobi|NHentai'))
        .split('|');
    searchRule =
        (await _getString('searchrule', 'Hitomi|EHentai|ExHentai|NHentai'))
            .split('|');
    searchNetwork = await _getBool('searchnetwork');

    if (!routingRule.contains('Hiyobi')) {
      routingRule.add('Hiyobi');
      await (await SharedPreferences.getInstance())
          .setString('routingrule', routingRule.join('|'));
    }

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

    rightToLeft = await _getBool('right2left', true);
    isHorizontal = await _getBool('ishorizontal');
    scrollVertical = await _getBool('scrollvertical');
    animation = await _getBool('animation');
    padding = await _getBool('padding');
    disableOverlayButton = await _getBool('disableoverlaybutton');
    disableFullScreen = await _getBool('disablefullscreen');
    enableTimer = await _getBool('enabletimer');
    timerTick = await _getDouble('timertick', 1.0);
    moveToAppBarToBottom =
        await _getBool('movetoappbartobottom', Platform.isIOS);
    showSlider = await _getBool('showslider');
    imageQuality = await _getInt('imagequality', 3);
    thumbSize = await _getInt('imageQuality', 0);
    enableThumbSlider = await _getBool('enableThumbSlider');
    showPageNumberIndicator = await _getBool('showPageNumberIndicator', true);
    showRecordJumpMessage = await _getBool('showRecordJumpMessage', true);

    useInnerStorage =
        (await SharedPreferences.getInstance()).getBool('useinnerstorage');
    if (useInnerStorage == null) {
      useInnerStorage = Platform.isIOS;
      if (Platform.isAndroid) {
        var deviceInfoPlugin = DeviceInfoPlugin();
        final androidInfo = await deviceInfoPlugin.androidInfo;
        if (androidInfo.version.sdkInt >= 30) useInnerStorage = true;
      }

      await (await SharedPreferences.getInstance())
          .setBool('userinnerstorage', useInnerStorage);
    }

    if (Platform.isAndroid) {
      downloadBasePath =
          (await SharedPreferences.getInstance()).getString('downloadbasepath');
      final String path = await ExtStorage.getExternalStorageDirectory();

      var androidInfo = await DeviceInfoPlugin().androidInfo;
      var sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30 &&
          (await SharedPreferences.getInstance())
                  .getBool('android30downpath') ==
              null) {
        await (await SharedPreferences.getInstance())
            .setBool('android30downpath', true);
        var ext = await getExternalStorageDirectory();
        downloadBasePath = ext.path;
        await (await SharedPreferences.getInstance())
            .setString('downloadbasepath', downloadBasePath);
      }

      if (downloadBasePath == null) {
        downloadBasePath = join(path, '.violet');
        await (await SharedPreferences.getInstance())
            .setString('downloadbasepath', downloadBasePath);
      }

      if (sdkInt < 30 &&
          downloadBasePath == join(path, 'Violet') &&
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
              if (download.files() != null) {
                result['Files'] =
                    download.files().replaceAll('/Violet/', '/.violet/');
              }
              if (download.path() != null) {
                result['Path'] =
                    download.path().replaceAll('/Violet/', '/.violet/');
              }
              download.result = result;
              await download.update();
            }
          }
        } catch (e, st) {
          Logger.error('[Settings] E: $e\n'
              '$st');
          FirebaseCrashlytics.instance.recordError(e, st);
        }
      }
    } else if (Platform.isIOS) {
      downloadBasePath = await _getString('downloadbasepath', 'not supported');
    }

    downloadRule = await _getString(
        'downloadrule', '%(extractor)s/%(id)s/%(file)s.%(ext)s');
    searchMessageAPI = await _getString(
        'searchmessageapi', 'https://koromo.xyz/api/search/msg');

    useVioletServer = await _getBool('usevioletserver');
    useDrawer = await _getBool('usedrawer');
    showArticleProgress = await _getBool('showarticleprogress');
    useOptimizeDatabase = await _getBool('useoptimizedatabase', true);

    useLowPerf = await _getBool('uselowperf', true);

    searchUseFuzzy = await _getBool('searchusefuzzy');
    searchTagTranslation = await _getBool('searchtagtranslation');
    searchUseTranslated = await _getBool('searchusetranslated');
    searchShowCount = await _getBool('searchshowcount', true);
    searchPure = await _getBool('searchPure');

    userAppId = (await SharedPreferences.getInstance()).getString('fa_userid');

    autobackupBookmark = await _getBool('autobackupbookmark', false);

    useTabletMode = await _getBool('usetabletmode', Device.get().isTablet);

    simpleItemWidgetLoadingIcon =
        await _getBool('simpleItemWidgetLoadingIcon', true);
    showNewViewerWhenArtistArticleListItemTap =
        await _getBool('showNewViewerWhenArtistArticleListItemTap', true);
    enableViewerFunctionBackdropFilter =
        await _getBool('enableViewerFunctionBackdropFilter');
    usingPushReplacementOnArticleRead =
        await _getBool('usingPushReplacementOnArticleRead', true);
    downloadEhRawImage = await _getBool('downloadEhRawImage');

    await regacy1_20_2();
  }

  static Future regacy1_20_2() async {
    if (await _checkLegacyExists('regacy1_20_2')) return;

    if (!simpleItemWidgetLoadingIcon) {
      await setSimpleItemWidgetLoadingIcon(true);
    }
    if (!showNewViewerWhenArtistArticleListItemTap) {
      await setShowNewViewerWhenArtistArticleListItemTap(true);
    }
  }

  static Future<bool> _checkLegacyExists(String name) async {
    var nn = (await SharedPreferences.getInstance()).getBool(name);
    if (nn == null) {
      await (await SharedPreferences.getInstance()).setBool(name, true);
      return false;
    }
    return true;
  }

  static Future<bool> _getBool(String key, [bool defaultValue = false]) async {
    var nn = (await SharedPreferences.getInstance()).getBool(key);
    if (nn == null) {
      nn = defaultValue;
      await (await SharedPreferences.getInstance()).setBool(key, nn);
    }
    return nn;
  }

  static Future<int> _getInt(String key, [int defaultValue = 0]) async {
    var nn = (await SharedPreferences.getInstance()).getInt(key);
    if (nn == null) {
      nn = defaultValue;
      await (await SharedPreferences.getInstance()).setInt(key, nn);
    }
    return nn;
  }

  static Future<String> _getString(String key,
      [String defaultValue = '']) async {
    var nn = (await SharedPreferences.getInstance()).getString(key);
    if (nn == null) {
      nn = defaultValue;
      await (await SharedPreferences.getInstance()).setString(key, nn);
    }
    return nn;
  }

  static Future<double> _getDouble(String key,
      [double defaultValue = 0.0]) async {
    var nn = (await SharedPreferences.getInstance()).getDouble(key);
    if (nn == null) {
      nn = defaultValue;
      await (await SharedPreferences.getInstance()).setDouble(key, nn);
    }
    return nn;
  }

  static Future<String> getDefaultDownloadPath() async {
    final String path = await ExtStorage.getExternalStorageDirectory();

    var androidInfo = await DeviceInfoPlugin().androidInfo;
    var sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      var ext = await getExternalStorageDirectory();
      downloadBasePath = ext.path;
    }

    downloadBasePath ??= join(path, '.violet');

    return downloadBasePath;
  }

  static Future<void> setThemeWhat(bool wh) async {
    themeWhat = wh;
    if (!themeWhat) {
      themeColor = Colors.white;
    } else {
      themeColor = Colors.black;
    }
    await (await SharedPreferences.getInstance())
        .setBool('themeColor', themeWhat);
  }

  static Future<void> setThemeBlack(bool wh) async {
    themeBlack = wh;
    await (await SharedPreferences.getInstance())
        .setBool('themeBlack', themeBlack);
  }

  static Future<void> setThemeFlat(bool nn) async {
    themeFlat = nn;
    await (await SharedPreferences.getInstance()).setBool('themeFlat', nn);
  }

  static Future<void> setMajorColor(Color color) async {
    if (majorColor == color) return;

    await (await SharedPreferences.getInstance())
        .setInt('majorColor', color.value);
    majorColor = color;

    Color accent;
    for (int i = 0; i < Colors.primaries.length - 2; i++) {
      if (color.value == Colors.primaries[i].value) {
        accent = Colors.accents[i];
        break;
      }
    }

    if (accent == null) {
      if (color == Colors.grey) {
        accent = Colors.grey.shade700;
      } else if (color == Colors.brown) {
        accent = Colors.brown.shade700;
      } else if (color == Colors.blueGrey) {
        accent = Colors.blueGrey.shade700;
      } else if (color == Colors.black) {
        accent = Colors.black;
      }
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

  static Future<void> setDownloadResultType(int wh) async {
    downloadResultType = wh;
    await (await SharedPreferences.getInstance())
        .setInt('downloadResultType', downloadResultType);
  }

  static Future<void> setDownloadAlignType(int wh) async {
    downloadAlignType = wh;
    await (await SharedPreferences.getInstance())
        .setInt('downloadAlignType', downloadAlignType);
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

  static Future<void> setTranslateTags(bool nn) async {
    translateTags = nn;
    await (await SharedPreferences.getInstance())
        .setBool('translatetags', translateTags);
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

  static Future<void> setEnableTimer(bool nn) async {
    enableTimer = nn;
    await (await SharedPreferences.getInstance())
        .setBool('enabletimer', enableTimer);
  }

  static Future<void> setTimerTick(double nn) async {
    timerTick = nn;
    await (await SharedPreferences.getInstance())
        .setDouble('timertick', timerTick);
  }

  static Future<void> setMoveToAppBarToBottom(bool nn) async {
    moveToAppBarToBottom = nn;
    await (await SharedPreferences.getInstance())
        .setBool('movetoappbartobottom', nn);
  }

  static Future<void> setImageQuality(int nn) async {
    imageQuality = nn;
    await (await SharedPreferences.getInstance())
        .setInt('imagequality', imageQuality);
  }

  static Future<void> setThumbSize(int nn) async {
    thumbSize = nn;
    await (await SharedPreferences.getInstance())
        .setInt('thumbSize', thumbSize);
  }

  static Future<void> setEnableThumbSlider(bool nn) async {
    enableThumbSlider = nn;
    await (await SharedPreferences.getInstance())
        .setBool('enableThumbSlider', enableThumbSlider);
  }

  static Future<void> setShowPageNumberIndicator(bool nn) async {
    showPageNumberIndicator = nn;
    await (await SharedPreferences.getInstance())
        .setBool('showPageNumberIndicator', showPageNumberIndicator);
  }

  static Future<void> setShowRecordJumpMessage(bool nn) async {
    showRecordJumpMessage = nn;
    await (await SharedPreferences.getInstance())
        .setBool('showRecordJumpMessage', showRecordJumpMessage);
  }

  static Future<void> setShowSlider(bool nn) async {
    showSlider = nn;
    await (await SharedPreferences.getInstance()).setBool('showslider', nn);
  }

  static Future<void> setSearchOnWeb(bool nn) async {
    searchNetwork = nn;
    await (await SharedPreferences.getInstance()).setBool('searchnetwork', nn);
  }

  static Future<void> setSearchPure(bool nn) async {
    searchPure = nn;
    await (await SharedPreferences.getInstance()).setBool('searchPure', nn);
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

  static Future<void> setBaseDownloadPath(String nn) async {
    downloadBasePath = nn;
    await (await SharedPreferences.getInstance())
        .setString('downloadbasepath', nn);
  }

  static Future<void> setDownloadRule(String nn) async {
    downloadRule = nn;
    await (await SharedPreferences.getInstance()).setString('downloadrule', nn);
  }

  static Future<void> setSearchMessageAPI(String nn) async {
    searchMessageAPI = nn;
    await (await SharedPreferences.getInstance())
        .setString('searchmessageapi', nn);
  }

  static Future<void> setUserInnerStorage(bool nn) async {
    useInnerStorage = nn;
    await (await SharedPreferences.getInstance())
        .setBool('useinnerstorage', nn);
  }

  static Future<void> setShowArticleProgress(bool nn) async {
    showArticleProgress = nn;
    await (await SharedPreferences.getInstance())
        .setBool('showarticleprogress', nn);
  }

  static Future<void> setUseOptimizeDatabase(bool nn) async {
    useOptimizeDatabase = nn;
    await (await SharedPreferences.getInstance())
        .setBool('useoptimizedatabase', nn);
  }

  static Future<void> setUseLowPerf(bool nn) async {
    useLowPerf = nn;
    await (await SharedPreferences.getInstance()).setBool('uselowperf', nn);
  }

  static Future<void> setSearchUseFuzzy(bool nn) async {
    searchUseFuzzy = nn;
    await (await SharedPreferences.getInstance()).setBool('searchusefuzzy', nn);
  }

  static Future<void> setSearchTagTranslation(bool nn) async {
    searchTagTranslation = nn;
    await (await SharedPreferences.getInstance())
        .setBool('searchtagtranslation', nn);
  }

  static Future<void> setSearchUseTranslated(bool nn) async {
    searchUseTranslated = nn;
    await (await SharedPreferences.getInstance())
        .setBool('searchusetranslated', nn);
  }

  static Future<void> setSearchShowCount(bool nn) async {
    searchShowCount = nn;
    await (await SharedPreferences.getInstance())
        .setBool('searchshowcount', nn);
  }

  static Future<void> setAutoBackupBookmark(bool nn) async {
    autobackupBookmark = nn;
    await (await SharedPreferences.getInstance())
        .setBool('autobackupbookmark', nn);
  }

  static Future<void> setUseTabletMode(bool nn) async {
    useTabletMode = nn;
    await (await SharedPreferences.getInstance()).setBool('usetabletmode', nn);
  }

  static Future<void> setSimpleItemWidgetLoadingIcon(bool nn) async {
    simpleItemWidgetLoadingIcon = nn;
    await (await SharedPreferences.getInstance())
        .setBool('simpleItemWidgetLoadingIcon', nn);
  }

  static Future<void> setShowNewViewerWhenArtistArticleListItemTap(
      bool nn) async {
    showNewViewerWhenArtistArticleListItemTap = nn;
    await (await SharedPreferences.getInstance())
        .setBool('showNewViewerWhenArtistArticleListItemTap', nn);
  }

  static Future<void> setEnableViewerFunctionBackdropFilter(bool nn) async {
    enableViewerFunctionBackdropFilter = nn;
    await (await SharedPreferences.getInstance())
        .setBool('enableViewerFunctionBackdropFilter', nn);
  }

  static Future<void> setUsingPushReplacementOnArticleRead(bool nn) async {
    usingPushReplacementOnArticleRead = nn;
    await (await SharedPreferences.getInstance())
        .setBool('usingPushReplacementOnArticleRead', nn);
  }

  static Future<void> setDownloadEhRawImage(bool nn) async {
    downloadEhRawImage = nn;
    await (await SharedPreferences.getInstance())
        .setBool('downloadEhRawImage', nn);
  }

  static Future<void> setUseLockScreen(bool nn) async {
    useLockScreen = nn;
    await (await SharedPreferences.getInstance()).setBool('useLockScreen', nn);
  }

  static Future<void> setUseSecureMode(bool nn) async {
    useSecureMode = nn;
    await (await SharedPreferences.getInstance()).setBool('useSecureMode', nn);
  }
}
