// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/hitomi/shielder.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/settings.dart';
import 'package:violet/log/log.dart';
import 'package:violet/platform/android_external_storage_directory.dart';
import 'package:violet/settings/device_type.dart';

class MultiPreferences {
  static late SharedPreferences shared_prefs;
  static late SettingsManager db_prefs;
  
  static MultiPreferences? _instance;

  static MultiPreferences create() {
    return MultiPreferences();
  }

  @protected
  @mustCallSuper
  void dispose() async {
    if(Platform.isLinux){
      db_prefs.dispose();
    }
  }

  static Future<MultiPreferences> getInstance() async {
    // switch(true){
    //   case Platform.isAndroid:
    //   case Platform.isIOS: 
    //     shared_prefs = await SharedPreferences.getInstance();
    //     break;
    //   case Platform.isLinux:
    //   case Platform.isMacOS: 
    //     db_prefs = await SettingsManager.getInstance();
    //     break;
    // }
    if(Platform.isAndroid || Platform.isIOS){
      shared_prefs = await SharedPreferences.getInstance();
    } else if(Platform.isLinux){
      db_prefs = await SettingsManager.getInstance();
    }
    if (_instance == null) {
      _instance = create();
    }
    return _instance!;
  }
  Future<void> init() async {
    if(Platform.isLinux){
      await db_prefs.execute('CREATE TABLE IF NOT EXISTS SharedPreferences (key STRING, value STRING,type STRING );');
    }
  }

  Future<Set<String>> getKeys() async {
    if(Platform.isAndroid || Platform.isIOS){
      return Future.value(shared_prefs.getKeys());
    } else if(Platform.isLinux){
      try {
        var res = await db_prefs.query('SELECT key FROM SharedPreferences;');
        if(res.isEmpty) return Future.value(null);
        return res.first.values.first;
      } catch(e){
        return Future.value(null);
      }
    } else {
      throw Error();
    }
  }

  Future<Object> get(String key) async {
    if(Platform.isAndroid || Platform.isIOS){
      return Future.value(shared_prefs.get(key));
    } else if(Platform.isLinux){
      try {
        var res = await db_prefs.query('SELECT value FROM SharedPreferences WHERE key="${key}";');
        if(res.isEmpty) return Future.value(null);
        return res.first.values.first;
      } catch(e){
        return Future.value(null);
      }
    } else {
      throw Error();
    }
  }

  Future<String?> getString(String key) async {
    if(Platform.isAndroid || Platform.isIOS){
      return Future.value(shared_prefs.getString(key));
    } else if(Platform.isLinux){
      try {
        var res = await db_prefs.query('SELECT value FROM SharedPreferences WHERE key="${key}" AND type="STRING";');
        if(res.isEmpty) return Future.value(null);
        return res.first.values.first;
      } catch(e){
        return Future.value(null);
      }
    } else {
      throw Error();
    }
  }
  
  Future<void> setString(String key,String value) async {
    if(Platform.isAndroid || Platform.isIOS){
      shared_prefs.setString(key, value);
    } else if(Platform.isLinux){
      String? result = null;
      try {
        result = await getString(key);
      } catch(e){
        result = null;
      }
      if(result != null){
        await db_prefs.execute('UPDATE SharedPreferences SET value="${value}" WHERE key="${key}" AND type="STRING";');
      } else {
        await db_prefs.execute('INSERT INTO SharedPreferences (key,value,type) VALUES ("${key}","${value}","STRING");');
      }
    }
  }

  Future<bool?> getBool(String key) async {
    if(Platform.isAndroid || Platform.isIOS){
      return Future.value(shared_prefs.getBool(key));
    } else if(Platform.isLinux){
      try {
        var res = await db_prefs.query('SELECT value FROM SharedPreferences WHERE key="${key}" AND type="BOOL";');
        if(res.isEmpty) return Future.value(null);
        return res.first.values.first;
        // return Future.value(null);
      } catch(e){
        return Future.value(null);
      }
    } else {
      throw Error();
    }
  }
  Future<void> setBool(String key,bool value) async {
    if(Platform.isAndroid || Platform.isIOS){
      await shared_prefs.setBool(key, value);
    } else if(Platform.isLinux){
      bool? result = null;
      try {
        result = await getBool(key);
      } catch(e){
        result = null;
      }
      if(result != null){
        await db_prefs.execute('UPDATE SharedPreferences SET value="${value}" WHERE key="${key}" AND type="BOOL";');
      } else {
        await db_prefs.execute('INSERT INTO SharedPreferences(key,value,type) VALUES("${key}","${value}","BOOL");');
      }
    }
  }

  Future<double?> getDouble(String key) async {
    if(Platform.isAndroid || Platform.isIOS){
      return Future.value(shared_prefs.getDouble(key));
    } else if(Platform.isLinux){
      try {
        var res = await db_prefs.query('SELECT value FROM SharedPreferences WHERE key="${key}" AND type="DOUBLE";');
        if(res.isEmpty) return Future.value(null);
        return res.first.values.first;
        // return Future.value(null);
      } catch(e){
        return Future.value(null);
      }
    } else {
      throw Error();
    }
  }
  Future<void> setDouble(String key,double value) async {
    if(Platform.isAndroid || Platform.isIOS){
      await shared_prefs.setDouble(key, value);
    } else if(Platform.isLinux){
      double? result = null;
      try {
        result = await getDouble(key);
      } catch(e){
        result = null;
      }
      if(result != null){
        await db_prefs.execute('UPDATE SharedPreferences SET value="${value}" WHERE key="${key}" AND type="DOUBLE";');
      } else {
        await db_prefs.execute('INSERT INTO SharedPreferences(key,value,type) VALUES("${key}","${value}","DOUBLE");');
      }
    }
  }

  Future<int?> getInt(String key) async {
    if(Platform.isAndroid || Platform.isIOS){
      return Future.value(shared_prefs.getInt(key));
    } else if(Platform.isLinux){
      try{
        var res = await db_prefs.query('SELECT value FROM SharedPreferences WHERE key="${key}" AND TYPE="INT";');
        if(res.isEmpty) return Future.value(null);
        return res.first.values.first;
      } catch(e){
        return Future.value(null);
      }
    } else {
      throw Error();
    }
  }
  Future<void> setInt(String key,int value) async {
    if(Platform.isAndroid || Platform.isIOS){
      await shared_prefs.setInt(key, value);
    } else if(Platform.isLinux){
      int? result = null;
      try {
        result = await getInt(key);
      } catch(e){
        result = null;
      }
      if(result != null){
        await db_prefs.execute('UPDATE SharedPreferences SET value="${value}" WHERE key="${key}" AND type="INT";');
      } else {
        await db_prefs.execute('INSERT INTO SharedPreferences(key,value,type) VALUES("${key}","${value}","INT");');
      }
    }
  }
}

class Settings {
  static late final SharedPreferences prefs;

  // Color Settings
  static late Color themeColor; // default light
  static late bool themeWhat; // default false == light
  static late Color majorColor; // default purple
  static late Color majorAccentColor;
  static late int
      searchResultType; // 0: 3 Grid, 1: 2 Grid, 2: Big Line, 3: Detail, 4: Ultra
  static late int downloadResultType;
  static late int downloadAlignType;
  static late bool themeFlat;
  static late bool themeBlack; // default false
  static late bool useTabletMode;
  static late bool liteMode;

  // Tag Settings
  static late String includeTags;
  static late List<String> excludeTags;
  static late List<String> blurredTags;
  static late String? language; // System Language
  static late bool translateTags;

  // Like this Hitomi.la => e-hentai => exhentai => nhentai
  static late List<String> routingRule; // image routing rule
  static late List<String> searchRule;
  static late bool searchNetwork;

  // Global? English? Korean?
  static late String databaseType;

  // Reader Option
  static late bool rightToLeft;
  static late bool isHorizontal;
  static late bool scrollVertical;
  static late bool animation;
  static late bool padding;
  static late bool disableOverlayButton;
  static late bool disableFullScreen;
  static late bool enableTimer;
  static late double timerTick;
  static late bool moveToAppBarToBottom;
  static late bool showSlider;
  static late int imageQuality;
  static late int thumbSize;
  static late bool enableThumbSlider;
  static late bool showPageNumberIndicator;
  static late bool showRecordJumpMessage;

  // Download Options
  static late bool useInnerStorage;
  static late String downloadBasePath;
  static late String downloadRule;

  static late String searchMessageAPI;
  static late bool useVioletServer;

  static late bool useDrawer;

  static late bool useOptimizeDatabase;

  static late bool useLowPerf;

  // View Option
  static late bool showArticleProgress;

  // Search Option
  static late bool searchUseFuzzy;
  static late bool searchTagTranslation;
  static late bool searchUseTranslated;
  static late bool searchShowCount;
  static late bool searchPure;

  static late String userAppId;

  static late bool autobackupBookmark;

  // Lab
  static late bool simpleItemWidgetLoadingIcon;
  static late bool showNewViewerWhenArtistArticleListItemTap;
  static late bool enableViewerFunctionBackdropFilter;
  static late bool usingPushReplacementOnArticleRead;
  static late bool downloadEhRawImage;
  static late bool bookmarkScrollbarPositionToLeft;
  static late bool useVerticalWebviewViewer;
  static late bool inViewerMessageSearch;

  static late bool useLockScreen;
  static late bool useSecureMode;

  static Future<void> initFirst() async {
    prefs = await SharedPreferences.getInstance();

    final mc = await _getInt('majorColor', Colors.purple.value);
    final mac = await _getInt('majorAccentColor', Colors.purpleAccent.value);

    majorColor = Color(mc);
    majorAccentColor = Color(mac);

    themeWhat = await _getBool('themeColor');
    themeColor = !themeWhat ? Colors.white : Colors.black;
    themeFlat = await _getBool('themeFlat');
    themeBlack = await _getBool('themeBlack');

    liteMode = await _getBool('liteMode', true);

    language = prefs.getString('language');

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
    searchResultType = await _getInt('searchResultType', 4);
    downloadResultType = await _getInt('downloadResultType', 3);
    downloadAlignType = await _getInt('downloadAlignType', 0);

    var includetags = prefs.getString('includetags');
    var excludetags = prefs.getString('excludetags');
    var blurredtags = prefs.getString('blurredtags');

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
      await prefs.setString('includetags', includetags);
    }
    if (excludetags == null ||
        excludetags == MinorShielderFilter.tags.join('|')) {
      excludetags = '';
      await prefs.setString('excludetags', excludetags);
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
      await prefs.setString('routingrule', routingRule.join('|'));
    }

    var databasetype = prefs.getString('databasetype');
    if (databasetype == null) {
      var langcode = Platform.localeName.split('_')[0];
      var acclc = ['ko', 'ja', 'en', 'ru', 'zh'];

      if (!acclc.contains(langcode)) langcode = 'global';

      databasetype = langcode;

      await prefs.setString('databasetype', langcode);
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

    var tUseInnerStorage = prefs.getBool('useinnerstorage');
    if (tUseInnerStorage == null) {
      tUseInnerStorage = Platform.isIOS;
      if (Platform.isAndroid) {
        var deviceInfoPlugin = DeviceInfoPlugin();
        final androidInfo = await deviceInfoPlugin.androidInfo;
        if (androidInfo.version.sdkInt >= 30) tUseInnerStorage = true;
      }

      await prefs.setBool('userinnerstorage', tUseInnerStorage);
    }
    useInnerStorage = tUseInnerStorage;

    String? tDownloadBasePath;
    if (Platform.isAndroid) {
      tDownloadBasePath = prefs.getString('downloadbasepath');
      final String path = await AndroidExternalStorageDirectory.instance
          .getExternalStorageDirectory();

      var androidInfo = await DeviceInfoPlugin().androidInfo;
      var sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30 && prefs.getBool('android30downpath') == null) {
        await prefs.setBool('android30downpath', true);
        var ext = await getExternalStorageDirectory();
        tDownloadBasePath = ext!.path;
        await prefs.setString('downloadbasepath', tDownloadBasePath);
      }

      if (tDownloadBasePath == null) {
        tDownloadBasePath = join(path, '.violet');
        await prefs.setString('downloadbasepath', tDownloadBasePath);
      }

      if (sdkInt < 30 &&
          tDownloadBasePath == join(path, 'Violet') &&
          prefs.getBool('downloadbasepathcc1') == null) {
        tDownloadBasePath = join(path, '.violet');
        await prefs.setString('downloadbasepath', tDownloadBasePath);
        await prefs.setBool('downloadbasepathcc1', true);

        try {
          if (await Permission.manageExternalStorage.isGranted) {
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
                    download.files()!.replaceAll('/Violet/', '/.violet/');
              }
              if (download.path() != null) {
                result['Path'] =
                    download.path()!.replaceAll('/Violet/', '/.violet/');
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
      tDownloadBasePath = await _getString('downloadbasepath', 'not supported');
    }
    downloadBasePath = tDownloadBasePath!;

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

    // main에서 셋팅됨
    userAppId = prefs.getString('fa_userid')!;

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
    bookmarkScrollbarPositionToLeft =
        await _getBool('bookmarkScrollbarPositionToLeft');
    useVerticalWebviewViewer = await _getBool('useVerticalWebviewViewer');
    inViewerMessageSearch = await _getBool('inViewerMessageSearch');

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
    var nn = prefs.getBool(name);
    if (nn == null) {
      await prefs.setBool(name, true);
      return false;
    }
    return true;
  }

  static Future<bool> _getBool(String key, [bool defaultValue = false]) async {
    var nn = prefs.getBool(key);
    if (nn == null) {
      nn = defaultValue;
      await prefs.setBool(key, nn);
    }
    return nn;
  }

  static Future<int> _getInt(String key, [int defaultValue = 0]) async {
    var nn = prefs.getInt(key);
    if (nn == null) {
      nn = defaultValue;
      await prefs.setInt(key, nn);
    }
    return nn;
  }

  static Future<String> _getString(String key,
      [String defaultValue = '']) async {
    var nn = prefs.getString(key);
    if (nn == null) {
      nn = defaultValue;
      await prefs.setString(key, nn);
    }
    return nn;
  }

  static Future<double> _getDouble(String key,
      [double defaultValue = 0.0]) async {
    var nn = prefs.getDouble(key);
    if (nn == null) {
      nn = defaultValue;
      await prefs.setDouble(key, nn);
    }
    return nn;
  }

  static Future<String> getDefaultDownloadPath() async {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    var sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      var ext = await getExternalStorageDirectory();
      downloadBasePath = ext!.path;
    }

    /*
    if (downloadBasePath == null) {
      final String path = await ExtStorage.getExternalStorageDirectory();
      downloadBasePath = join(path, '.violet');
    }
     */

    return downloadBasePath;
  }

  static Future<void> setThemeWhat(bool wh) async {
    themeWhat = wh;
    if (!themeWhat) {
      themeColor = Colors.white;
    } else {
      themeColor = Colors.black;
    }

    await prefs.setBool('themeColor', themeWhat);
  }

  static Future<void> setThemeBlack(bool wh) async {
    themeBlack = wh;

    await prefs.setBool('themeBlack', themeBlack);
  }

  static Future<void> setThemeFlat(bool nn) async {
    themeFlat = nn;

    await prefs.setBool('themeFlat', nn);
  }

  static Future<void> setMajorColor(Color color) async {
    if (majorColor == color) return;

    await prefs.setInt('majorColor', color.value);
    majorColor = color;

    Color? accent;
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

    await prefs.setInt('majorAccentColor', accent!.value);
    majorAccentColor = accent;
  }

  static Future<void> setSearchResultType(int wh) async {
    searchResultType = wh;

    await prefs.setInt('searchResultType', searchResultType);
  }

  static Future<void> setDownloadResultType(int wh) async {
    downloadResultType = wh;

    await prefs.setInt('downloadResultType', downloadResultType);
  }

  static Future<void> setDownloadAlignType(int wh) async {
    downloadAlignType = wh;

    await prefs.setInt('downloadAlignType', downloadAlignType);
  }

  static Future<void> setLanguage(String lang) async {
    language = lang;

    await prefs.setString('language', lang);
  }

  static Future<void> setIncludeTags(String nn) async {
    includeTags = nn;

    await prefs.setString('includetags', includeTags);
  }

  static Future<void> setExcludeTags(String nn) async {
    excludeTags = nn.split(' ').toList();

    await prefs.setString('excludetags', excludeTags.join('|'));
  }

  static Future<void> setBlurredTags(String nn) async {
    blurredTags = nn.split(' ').toList();

    await prefs.setString('blurredtags', blurredTags.join('|'));
  }

  static Future<void> setTranslateTags(bool nn) async {
    translateTags = nn;

    await prefs.setBool('translatetags', translateTags);
  }

  static Future<void> setRightToLeft(bool nn) async {
    rightToLeft = nn;

    await prefs.setBool('right2left', rightToLeft);
  }

  static Future<void> setIsHorizontal(bool nn) async {
    isHorizontal = nn;

    await prefs.setBool('ishorizontal', isHorizontal);
  }

  static Future<void> setScrollVertical(bool nn) async {
    scrollVertical = nn;

    await prefs.setBool('scrollvertical', scrollVertical);
  }

  static Future<void> setAnimation(bool nn) async {
    animation = nn;

    await prefs.setBool('animation', animation);
  }

  static Future<void> setPadding(bool nn) async {
    padding = nn;

    await prefs.setBool('padding', padding);
  }

  static Future<void> setDisableOverlayButton(bool nn) async {
    disableOverlayButton = nn;

    await prefs.setBool('disableoverlaybutton', disableOverlayButton);
  }

  static Future<void> setDisableFullScreen(bool nn) async {
    disableFullScreen = nn;

    await prefs.setBool('disablefullscreen', disableFullScreen);
  }

  static Future<void> setEnableTimer(bool nn) async {
    enableTimer = nn;

    await prefs.setBool('enabletimer', enableTimer);
  }

  static Future<void> setTimerTick(double nn) async {
    timerTick = nn;

    await prefs.setDouble('timertick', timerTick);
  }

  static Future<void> setMoveToAppBarToBottom(bool nn) async {
    moveToAppBarToBottom = nn;

    await prefs.setBool('movetoappbartobottom', nn);
  }

  static Future<void> setImageQuality(int nn) async {
    imageQuality = nn;

    await prefs.setInt('imagequality', imageQuality);
  }

  static Future<void> setThumbSize(int nn) async {
    thumbSize = nn;

    await prefs.setInt('thumbSize', thumbSize);
  }

  static Future<void> setEnableThumbSlider(bool nn) async {
    enableThumbSlider = nn;

    await prefs.setBool('enableThumbSlider', enableThumbSlider);
  }

  static Future<void> setShowPageNumberIndicator(bool nn) async {
    showPageNumberIndicator = nn;

    await prefs.setBool('showPageNumberIndicator', showPageNumberIndicator);
  }

  static Future<void> setShowRecordJumpMessage(bool nn) async {
    showRecordJumpMessage = nn;

    await prefs.setBool('showRecordJumpMessage', showRecordJumpMessage);
  }

  static Future<void> setShowSlider(bool nn) async {
    showSlider = nn;

    await prefs.setBool('showslider', nn);
  }

  static Future<void> setSearchOnWeb(bool nn) async {
    searchNetwork = nn;

    await prefs.setBool('searchnetwork', nn);
  }

  static Future<void> setSearchPure(bool nn) async {
    searchPure = nn;

    await prefs.setBool('searchPure', nn);
  }

  static Future<void> setUseVioletServer(bool nn) async {
    useVioletServer = nn;

    await prefs.setBool('usevioletserver', nn);
  }

  static Future<void> setUseDrawer(bool nn) async {
    useDrawer = nn;

    await prefs.setBool('usedrawer', nn);
  }

  static Future<void> setBaseDownloadPath(String nn) async {
    downloadBasePath = nn;

    await prefs.setString('downloadbasepath', nn);
  }

  static Future<void> setDownloadRule(String nn) async {
    downloadRule = nn;

    await prefs.setString('downloadrule', nn);
  }

  static Future<void> setSearchMessageAPI(String nn) async {
    searchMessageAPI = nn;

    await prefs.setString('searchmessageapi', nn);
  }

  static Future<void> setUserInnerStorage(bool nn) async {
    useInnerStorage = nn;

    await prefs.setBool('useinnerstorage', nn);
  }

  static Future<void> setShowArticleProgress(bool nn) async {
    showArticleProgress = nn;

    await prefs.setBool('showarticleprogress', nn);
  }

  static Future<void> setUseOptimizeDatabase(bool nn) async {
    useOptimizeDatabase = nn;

    await prefs.setBool('useoptimizedatabase', nn);
  }

  static Future<void> setUseLowPerf(bool nn) async {
    useLowPerf = nn;

    await prefs.setBool('uselowperf', nn);
  }

  static Future<void> setSearchUseFuzzy(bool nn) async {
    searchUseFuzzy = nn;

    await prefs.setBool('searchusefuzzy', nn);
  }

  static Future<void> setSearchTagTranslation(bool nn) async {
    searchTagTranslation = nn;

    await prefs.setBool('searchtagtranslation', nn);
  }

  static Future<void> setSearchUseTranslated(bool nn) async {
    searchUseTranslated = nn;

    await prefs.setBool('searchusetranslated', nn);
  }

  static Future<void> setSearchShowCount(bool nn) async {
    searchShowCount = nn;

    await prefs.setBool('searchshowcount', nn);
  }

  static Future<void> setAutoBackupBookmark(bool nn) async {
    autobackupBookmark = nn;

    await prefs.setBool('autobackupbookmark', nn);
  }

  static Future<void> setUseTabletMode(bool nn) async {
    useTabletMode = nn;

    await prefs.setBool('usetabletmode', nn);
  }

  static Future<void> setSimpleItemWidgetLoadingIcon(bool nn) async {
    simpleItemWidgetLoadingIcon = nn;

    await prefs.setBool('simpleItemWidgetLoadingIcon', nn);
  }

  static Future<void> setShowNewViewerWhenArtistArticleListItemTap(
      bool nn) async {
    showNewViewerWhenArtistArticleListItemTap = nn;

    await prefs.setBool('showNewViewerWhenArtistArticleListItemTap', nn);
  }

  static Future<void> setEnableViewerFunctionBackdropFilter(bool nn) async {
    enableViewerFunctionBackdropFilter = nn;

    await prefs.setBool('enableViewerFunctionBackdropFilter', nn);
  }

  static Future<void> setUsingPushReplacementOnArticleRead(bool nn) async {
    usingPushReplacementOnArticleRead = nn;

    await prefs.setBool('usingPushReplacementOnArticleRead', nn);
  }

  static Future<void> setDownloadEhRawImage(bool nn) async {
    downloadEhRawImage = nn;

    await prefs.setBool('downloadEhRawImage', nn);
  }

  static Future<void> setBookmarkScrollbarPositionToLeft(bool nn) async {
    bookmarkScrollbarPositionToLeft = nn;

    await prefs.setBool('bookmarkScrollbarPositionToLeft', nn);
  }

  static Future<void> setUseVerticalWebviewViewer(bool nn) async {
    useVerticalWebviewViewer = nn;

    await prefs.setBool('useVerticalWebviewViewer', nn);
  }

  static Future<void> setInViewerMessageSearch(bool nn) async {
    inViewerMessageSearch = nn;

    await prefs.setBool('inViewerMessageSearch', nn);
  }

  static Future<void> setUseLockScreen(bool nn) async {
    useLockScreen = nn;

    await prefs.setBool('useLockScreen', nn);
  }

  static Future<void> setUseSecureMode(bool nn) async {
    useSecureMode = nn;

    await prefs.setBool('useSecureMode', nn);
  }

  static Future<void> setLightMode(bool nn) async {
    liteMode = nn;

    await prefs.setBool('liteMode', nn);
  }
}
