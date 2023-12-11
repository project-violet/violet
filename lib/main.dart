// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flare_flutter/provider/asset_flare.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart'; // @dependent: android
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/firebase_options.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/lock/lock_screen.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    // https://stackoverflow.com/questions/66971604/sqlite-with-flutter-desktop-windows
    if (Platform.isWindows || Platform.isLinux) {
        // Initialize FFI
        sqfliteFfiInit();
        // Change the default factory
        databaseFactory = databaseFactoryFfi;
    }

    WidgetsFlutterBinding.ensureInitialized();

    if(Platform.isAndroid || Platform.isIOS) await FlutterDownloader.initialize(); // @dependent: android
    FlareCache.doesPrune = false;
    FlutterError.onError = recordFlutterError;

    if(Platform.isAndroid || Platform.isIOS) await initFirebase();
    await Settings.initFirst();
    await warmupFlare();

    runApp(const MyApp());
  }, (exception, stack) async {
    Logger.error('[async-error] E: $exception\n$stack');

    if(Platform.isAndroid || Platform.isIOS) await FirebaseCrashlytics.instance.recordError(exception, stack);
  });
}

const _filesToWarmup = [
  'assets/flare/Loading2.flr',
  'assets/flare/likeUtsua.flr'
];

Future<void> warmupFlare() async {
  for (final filename in _filesToWarmup) {
    await cachedActor(
      AssetFlare(bundle: rootBundle, name: filename),
    );
  }
}

Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails) async {
  Logger.error(
      '[unhandled-error] E: ${flutterErrorDetails.exceptionAsString()}\n'
      '${flutterErrorDetails.stack}');

  if(Platform.isAndroid || Platform.isIOS) FirebaseCrashlytics.instance.recordFlutterError(flutterErrorDetails);
}

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // check user-id is set
  final prefs = await MultiPreferences.getInstance();
  var id = await prefs.getString('fa_userid');
  if (id == null) {
    id = sha1.convert(utf8.encode(DateTime.now().toString())).toString();
    prefs.setString('fa_userid', id);
  }

  var analytics = FirebaseAnalytics.instance;
  await analytics.setUserId(id: id);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicTheme(
      defaultBrightness: Brightness.light,
      data: (brightness) => ThemeData(
        useMaterial3: false,
        brightness: brightness,
        bottomSheetTheme:
            BottomSheetThemeData(backgroundColor: Colors.black.withOpacity(0)),
        scaffoldBackgroundColor:
            Settings.themeBlack && Settings.themeWhat ? Colors.black : null,
        dialogBackgroundColor: Settings.themeBlack && Settings.themeWhat
            ? Palette.blackThemeBackground
            : null,
        cardColor: Settings.themeBlack && Settings.themeWhat
            ? Palette.blackThemeBackground
            : null,
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: Settings.majorColor, brightness: brightness),
        cupertinoOverrideTheme: CupertinoThemeData(
          brightness: brightness,
          primaryColor: Settings.majorColor,
          textTheme: const CupertinoTextThemeData(),
          barBackgroundColor: Settings.themeWhat
              ? Settings.themeBlack
                  ? const Color(0xFF181818)
                  : Colors.grey.shade800
              : null,
        ),
      ),
      themedWidgetBuilder: (context, theme) {
        return myApp(theme);
      },
    );
  }

  Widget myApp(ThemeData theme) {
    const supportedLocales = <Locale>[
      Locale('en', 'US'),
      Locale('ko', 'KR'),
      Locale('ja', 'JP'),
      Locale('zh', 'CH'),
      Locale('it', 'IT'),
      Locale('eo', 'ES'),
      Locale('pt', 'BR'),
    ];

    const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
      TranslationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ];

    final routes = <String, WidgetBuilder>{
      '/AfterLoading': (context) =>
          const CupertinoScaffold(body: AfterLoadingPage()),
      '/DatabaseDownload': (context) => const DataBaseDownloadPage(),
      '/SplashPage': (context) => const SplashPage(),
    };

    final home =
        Settings.useLockScreen ? const LockScreen() : const SplashPage();

    final navigatorObservers = [
      if(Platform.isAndroid || Platform.isIOS) FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ];

    return GetMaterialApp(
      navigatorObservers: navigatorObservers,
      theme: theme,
      home: home,
      supportedLocales: supportedLocales,
      routes: routes,
      localizationsDelegates: localizationsDelegates,
      localeResolutionCallback: localeResolution,
    );
  }

  Locale localeResolution(Locale? locale, Iterable<Locale> supportedLocales) {
    if (Settings.language != null) {
      if (Settings.language!.contains('_')) {
        final ss = Settings.language!.split('_');
        if (ss.length == 2) {
          return Locale.fromSubtags(languageCode: ss[0], scriptCode: ss[1]);
        } else {
          return Locale.fromSubtags(
              languageCode: ss[0], scriptCode: ss[1], countryCode: ss[2]);
        }
      } else {
        return Locale(Settings.language!);
      }
    }

    if (locale == null) {
      if (Settings.language == null) {
        Settings.setLanguage(supportedLocales.first.languageCode);
      }
      return supportedLocales.first;
    }

    for (Locale supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode ||
          supportedLocale.countryCode == locale.countryCode) {
        if (Settings.language == null) {
          Settings.setLanguage(supportedLocale.languageCode);
        }
        return supportedLocale;
      }
    }

    if (Settings.language == null) {
      Settings.setLanguage(supportedLocales.first.languageCode);
    }

    return supportedLocales.first;
  }
}
