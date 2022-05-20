// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart'; // @dependent: android
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/firebase_options.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/lock/lock_screen.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:wakelock/wakelock.dart';

import 'locale/locale.dart';

const _filesToWarmup = [
  'assets/flare/Loading2.flr',
  'assets/flare/likeUtsua.flr'
];

Future<void> warmupFlare() async {
  for (final filename in _filesToWarmup) {
    await cachedActor(rootBundle, filename);
  }
}

/*
Future<void> _sqlIntegrityTest() async {
  var sql1 =
      HitomiManager.translate2query('(lang:english) -group:zenmai_kourogi');
  var query1 = await (await DataBaseManager.getInstance()).query(sql1);
  print(sql1);
  print(query1.length);
  var sql2 = HitomiManager.translate2query('(lang:english)');
  var query2 = await (await DataBaseManager.getInstance()).query(sql2);
  print(sql2);
  print(query2.length);
  var sql3 =
      HitomiManager.translate2query('group:zenmai_kourogi (lang:english)');
  var query3 = await (await DataBaseManager.getInstance()).query(sql3);
  print(sql3);
  print(query3.length);
}
 */

Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails) async {
  Logger.error(
      '[unhandled-error] E: ${flutterErrorDetails.exceptionAsString()}\n'
      '${flutterErrorDetails.stack}');

  await FirebaseCrashlytics.instance.recordFlutterError(flutterErrorDetails);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(); // @dependent: android
  FlareCache.doesPrune = false;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = recordFlutterError;

  var analytics = FirebaseAnalytics.instance;
  var id = (await SharedPreferences.getInstance()).getString('fa_userid');
  if (id == null) {
    var ii = sha1.convert(utf8.encode(DateTime.now().toString()));
    id = ii.toString();
    (await SharedPreferences.getInstance()).setString('fa_userid', id);
  }
  await analytics.setUserId(id: id);

  await Settings.initFirst();
  await warmupFlare();
  Wakelock.enable();

  runApp(
    DynamicTheme(
      defaultBrightness: Brightness.light,
      data: (brightness) => ThemeData(
        brightness: brightness,
        bottomSheetTheme:
            BottomSheetThemeData(backgroundColor: Colors.black.withOpacity(0)),
        scaffoldBackgroundColor:
            Settings.themeBlack && Settings.themeWhat ? Colors.black : null,
        dialogBackgroundColor: Settings.themeBlack && Settings.themeWhat
            ? const Color(0xFF141414)
            : null,
        cardColor: Settings.themeBlack && Settings.themeWhat
            ? const Color(0xFF141414)
            : null,
        colorScheme:
            ColorScheme.fromSwatch().copyWith(secondary: Settings.majorColor),
      ),
      themedWidgetBuilder: (context, theme) {
        return MaterialApp(
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: analytics),
          ],
          theme: theme,
          home:
              Settings.useLockScreen ? const LockScreen() : const SplashPage(),
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('ko', 'KR'),
            Locale('ja', 'JP'),
            Locale('zh', 'CH'),
            Locale('it', 'IT'),
            Locale('eo', 'ES'),
          ],
          routes: <String, WidgetBuilder>{
            '/AfterLoading': (context) => const AfterLoadingPage(),
            '/DatabaseDownload': (context) => const DataBaseDownloadPage(),
            '/SplashPage': (context) => const SplashPage(),
          },
          localizationsDelegates: const [
            TranslationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          localeResolutionCallback:
              (Locale locale, Iterable<Locale> supportedLocales) {
            print(Settings.language);
            if (Settings.language != null) {
              if (Settings.language.contains('_')) {
                var ss = Settings.language.split('_');
                if (ss.length == 2) {
                  return Locale.fromSubtags(
                      languageCode: ss[0], scriptCode: ss[1]);
                } else {
                  return Locale.fromSubtags(
                      languageCode: ss[0],
                      scriptCode: ss[1],
                      countryCode: ss[2]);
                }
              } else {
                return Locale(Settings.language);
              }
            }

            if (locale == null) {
              debugPrint('*language locale is null!!!');
              if (Settings.language == null) {
                Settings.setLanguage(supportedLocales.first.languageCode);
              }
              return supportedLocales.first;
            }

            for (Locale supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode ||
                  supportedLocale.countryCode == locale.countryCode) {
                debugPrint('*language ok $supportedLocale');
                if (Settings.language == null) {
                  Settings.setLanguage(supportedLocale.languageCode);
                }
                return supportedLocale;
              }
            }

            debugPrint('*language to fallback ${supportedLocales.first}');
            if (Settings.language == null) {
              Settings.setLanguage(supportedLocales.first.languageCode);
            }
            return supportedLocales.first;
          },
        );
      },
    ),
  );
}
