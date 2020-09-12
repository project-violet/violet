// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/main.dart';
import 'package:violet/pages/bookmark/bookmark_page.dart';
import 'package:violet/pages/download/download_page.dart';
import 'package:violet/pages/main/main_page.dart';
import 'package:violet/pages/search/search_page.dart';
import 'package:violet/pages/settings/settings_page.dart';
import 'package:violet/settings/settings.dart';

class AfterLoadingPage extends StatefulWidget {
  @override
  _AfterLoadingPageState createState() => new _AfterLoadingPageState();
}

class _AfterLoadingPageState extends State<AfterLoadingPage>
    with WidgetsBindingObserver {
  int _page = 0;
  PageController _c;
  bool isBlurred = false;

  @override
  void initState() {
    _c = new PageController(
      initialPage: _page,
    );
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    setState(() {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive)
        isBlurred = true;
      else
        isBlurred = false;
    });
  }

  @override
  void disposed() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (Platform.isAndroid) {
      return new Scaffold(
        key: scaffoldKey,
        bottomNavigationBar: MediaQuery(
          data: mediaQuery.copyWith(
            padding: mediaQuery.padding +
                mediaQuery.viewInsets +
                EdgeInsets.only(bottom: 6),
          ),
          child: BottomNavigationBar(
            elevation: 9,
            showUnselectedLabels: false,
            type: BottomNavigationBarType.shifting,
            fixedColor: Settings.majorColor,
            unselectedItemColor: Settings.themeWhat
                ? Colors.white
                : Colors.black, //Colors.black,
            currentIndex: _page,
            onTap: (index) {
              this._c.animateToPage(index,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut);
            },
            items: <BottomNavigationBarItem>[
              new BottomNavigationBarItem(
                  backgroundColor: Settings.themeWhat
                      ? Colors.grey.shade900.withOpacity(0.90)
                      : Colors.grey.shade50,
                  icon: new Icon(MdiIcons.home),
                  title: new Text(Translations.of(context).trans('main'))),
              new BottomNavigationBarItem(
                  backgroundColor: Settings.themeWhat
                      ? Colors.grey.shade900.withOpacity(0.90)
                      : Colors.grey.shade50,
                  icon: new Icon(Icons.search),
                  title: new Text(Translations.of(context).trans('search'))),
              new BottomNavigationBarItem(
                  backgroundColor: Settings.themeWhat
                      ? Colors.grey.shade900.withOpacity(0.90)
                      : Colors.grey.shade50,
                  icon: new Icon(Icons.bookmark),
                  title: new Text(Translations.of(context).trans('bookmark'))),
              new BottomNavigationBarItem(
                  icon: new Icon(Icons.file_download),
                  title: new Text(Translations.of(context).trans('download'))),
              new BottomNavigationBarItem(
                  backgroundColor: Settings.themeWhat
                      ? Colors.grey.shade900.withOpacity(0.90)
                      : Colors.grey.shade50,
                  icon: new Icon(Icons.settings),
                  title: new Text(Translations.of(context).trans('settings'))),
            ],
          ),
        ),
        body: new PageView(
          controller: _c,
          onPageChanged: (newPage) {
            setState(() {
              this._page = newPage;
            });
          },
          children: <Widget>[
            MainPage(),
            SearchPage(),
            BookmarkPage(),
            DownloadPage(),
            SettingsPage(),
          ],
          // ),
        ),
      );
    } else if (Platform.isIOS) {
      return new Scaffold(
        key: scaffoldKey,
        bottomNavigationBar: BottomNavigationBar(
          elevation: 9,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.shifting,
          fixedColor: Settings.majorColor,
          unselectedItemColor:
              Settings.themeWhat ? Colors.white : Colors.black, //Colors.black,
          currentIndex: _page,
          onTap: (index) {
            this._c.animateToPage(index,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut);
          },
          items: <BottomNavigationBarItem>[
            new BottomNavigationBarItem(
                backgroundColor: Settings.themeWhat
                    ? Colors.grey.shade900.withOpacity(0.90)
                    : Colors.grey.shade50,
                icon: new Icon(MdiIcons.home),
                title: new Text(Translations.of(context).trans('main'))),
            new BottomNavigationBarItem(
                backgroundColor: Settings.themeWhat
                    ? Colors.grey.shade900.withOpacity(0.90)
                    : Colors.grey.shade50,
                icon: new Icon(Icons.search),
                title: new Text(Translations.of(context).trans('search'))),
            new BottomNavigationBarItem(
                backgroundColor: Settings.themeWhat
                    ? Colors.grey.shade900.withOpacity(0.90)
                    : Colors.grey.shade50,
                icon: new Icon(Icons.bookmark),
                title: new Text(Translations.of(context).trans('bookmark'))),
            new BottomNavigationBarItem(
                backgroundColor: Settings.themeWhat
                    ? Colors.grey.shade900.withOpacity(0.90)
                    : Colors.grey.shade50,
                icon: new Icon(Icons.settings),
                title: new Text(Translations.of(context).trans('settings'))),
          ],
        ),
        body: new PageView(
          controller: _c,
          onPageChanged: (newPage) {
            setState(() {
              this._page = newPage;
            });
          },
          children: <Widget>[
            MainPage(),
            SearchPage(),
            BookmarkPage(),
            SettingsPage(),
          ],
        ),
        // ),
      );
    }

    throw new Exception('not implemented');
  }
}
