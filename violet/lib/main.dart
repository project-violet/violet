// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

// For the development of human civilization and science and technology

import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:violet/settings.dart';
import 'package:violet/user.dart';
import 'locale.dart';
import 'package:violet/pages/database_download_page.dart';
import 'package:violet/pages/splash_page.dart';
import 'package:violet/pages/afterloading_page.dart';

DateTime currentBackPressTime;
final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

const _filesToWarmup = [
  'assets/flare/Loading2.flr',
  'assets/flare/likeUtsua.flr'
];

Future<void> warmupFlare() async {
  for (final filename in _filesToWarmup) {
    await cachedActor(rootBundle, filename);
  }
}

Future<void> initDB() async {
  await Bookmark.getInstance();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlareCache.doesPrune = false;

  // final String UA = '';
  // Analytics ga = new AnalyticsIO(UA, 'ga_test', '3.0',
  //   documentDirectory: await getApplicationDocumentsDirectory());
  // ga.analyticsOpt = AnalyticsOpt.optIn;
  // ga.sendScreenView('home');

  FirebaseAnalytics analytics = FirebaseAnalytics();
  await analytics.setUserId('some-user');

  await Settings.init();
  await initDB();

  warmupFlare().then((_) {
    runApp(
      DynamicTheme(
        defaultBrightness: Brightness.light,
        data: (brightness) => new ThemeData(
          accentColor: Settings.majorColor,
          // primaryColor: Settings.majorColor,
          // primarySwatch: Settings.majorColor,
          brightness: brightness,
        ),
        themedWidgetBuilder: (context, theme) {
          return MaterialApp(
            navigatorObservers: [
              FirebaseAnalyticsObserver(analytics: analytics),
            ],
            theme: theme,
            home: SplashPage(),
            supportedLocales: [
              const Locale('ko', 'KR'),
              const Locale('en', 'US'),
              const Locale('ja', 'JP'),
            ],
            routes: <String, WidgetBuilder>{
              '/AfterLoading': (BuildContext context) => WillPopScope(
                    child: new AfterLoadingPage(),
                    onWillPop: () {
                      DateTime now = DateTime.now();
                      if (currentBackPressTime == null ||
                          now.difference(currentBackPressTime) >
                              Duration(seconds: 2)) {
                        currentBackPressTime = now;
                        scaffoldKey.currentState.showSnackBar(new SnackBar(
                          duration: Duration(seconds: 2),
                          content: new Text(
                            Translations.of(context).trans('closedoubletap'),
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.grey.shade800,
                        ));
                        return Future.value(false);
                      }
                      return Future.value(true);
                    },
                  ),
              '/DatabaseDownload': (BuildContext context) =>
                  new DataBaseDownloadPage(),
            },
            localizationsDelegates: [
              const TranslationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate
            ],
            localeResolutionCallback:
                (Locale locale, Iterable<Locale> supportedLocales) {
              if (locale == null) {
                debugPrint("*language locale is null!!!");
                return supportedLocales.first;
              }

              for (Locale supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode ||
                    supportedLocale.countryCode == locale.countryCode) {
                  debugPrint("*language ok $supportedLocale");
                  return supportedLocale;
                }
              }

              debugPrint("*language to fallback ${supportedLocales.first}");
              return supportedLocales.first;
            },
          );
        },
      ),
    );
  });
}
