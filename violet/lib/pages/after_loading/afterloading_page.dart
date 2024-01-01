// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uni_links/uni_links.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/act_log.dart';
import 'package:violet/other/named_color.dart';
import 'package:violet/pages/bookmark/bookmark_page.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/download/download_page.dart';
import 'package:violet/pages/hot/hot_page.dart';
import 'package:violet/pages/lock/lock_screen.dart';
import 'package:violet/pages/main/main_page.dart';
import 'package:violet/pages/search/search_page.dart';
import 'package:violet/pages/segment/double_tap_to_top.dart';
import 'package:violet/pages/settings/settings_page.dart';
import 'package:violet/platform/misc.dart';
import 'package:violet/script/script_webview.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/update/update_manager.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/update_sync.dart';
import 'package:violet/widgets/toast.dart';

class AfterLoadingPage extends StatefulWidget {
  const AfterLoadingPage({super.key});

  @override
  State<AfterLoadingPage> createState() => AfterLoadingPageState();
}

class AfterLoadingPageState extends State<AfterLoadingPage>
    with WidgetsBindingObserver {
  static int defaultInitialPage = 0;
  late FToast fToast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fToast = FToast();
    fToast.init(context);

    uriLinkStream.listen(handleDeeplink);

    Future.delayed(const Duration(milliseconds: 200))
        .then((value) => UpdateManager.updateCheck(context));
  }

  bool _alreadyLocked = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (Settings.useLockScreen &&
            Settings.useSecureMode &&
            !_alreadyLocked) {
          _alreadyLocked = true;
          Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (context) => const LockScreen(
                  isSecureMode: true,
                ),
              ))
              .then((value) => _alreadyLocked = false);
        }
        ActLogger.log(ActLogEvent(type: ActLogType.appResume));
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        ActLogger.log(ActLogEvent(type: ActLogType.appSuspense));
        break;
      case AppLifecycleState.detached:
        ActLogger.log(ActLogEvent(type: ActLogType.appStop));
        break;
      default:
        // TODO: Implement properly
        break;
    }
  }

  void handleDeeplink(Uri? uri) {
    if (uri == null) {
      return;
    }

    if (int.tryParse(uri.host) != null) {
      showArticleInfo(context, int.parse(uri.host));
    }
  }

  final PageController _pageController =
      PageController(initialPage: defaultInitialPage);

  int get _currentPage => _pageController.hasClients
      ? _pageController.page!.round()
      : defaultInitialPage;

  bool get _usesDrawer => Settings.useDrawer;

  bool get _usesBottomNavigationBar => !Settings.useDrawer;

  DateTime? _lastPopAt;

  bool _isDoubleTap = false;

  late final List<GlobalKey<State>> _widgetKeys =
      List.generate(7, (index) => GlobalKey());

  Widget _buildBottomNavigationBar(BuildContext context) {
    final translations = Translations.of(context);

    BottomNavigationBarItem buildItem(IconData iconData, String key) {
      return BottomNavigationBarItem(
        backgroundColor: Settings.themeWhat
            ? Settings.themeBlack
                ? const Color(0xFF060606)
                : Colors.grey.shade900.withOpacity(0.90)
            : Colors.grey.shade50,
        icon: Icon(iconData),
        label: translations.trans(key),
      );
    }

    Widget result = Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Settings.themeWhat && Settings.themeBlack
            ? const Color(0xFF060606)
            : null,
      ),
      child: BottomNavigationBar(
        showUnselectedLabels: false,
        type: BottomNavigationBarType.shifting,
        fixedColor: Settings.majorColor,
        unselectedItemColor: Settings.themeWhat ? Colors.white : Colors.black,
        backgroundColor: Settings.themeWhat && Settings.themeBlack
            ? const Color(0xFF060606)
            : null,
        currentIndex: _currentPage,
        onTap: (index) {
          if (_pageController.page != index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          } else {
            if (_isDoubleTap) {
              // something to do for double tap
              if (index >= 2 || Settings.liteMode) index += 1;
              (_widgetKeys[index].currentState as DoubleTapToTopMixin)
                  .animateToTop();

              _isDoubleTap = false;
              return;
            }

            _isDoubleTap = true;
            Timer(
                const Duration(milliseconds: 200), () => _isDoubleTap = false);
          }
        },
        items: <BottomNavigationBarItem>[
          if (!Settings.liteMode) buildItem(MdiIcons.home, 'main'),
          buildItem(Icons.search, 'search'),
          if (Settings.liteMode) buildItem(MdiIcons.fire, 'hot'),
          buildItem(Icons.bookmark, 'bookmark'),
          buildItem(Icons.file_download, 'download'),
          buildItem(Icons.settings, 'settings'),
        ],
      ),
    );

    if (Platform.isAndroid) {
      final mediaQuery = MediaQuery.of(context);
      result = MediaQuery(
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding +
              mediaQuery.viewInsets +
              const EdgeInsets.only(bottom: 6),
        ),
        child: result,
      );
    }

    return result;
  }

  Widget _buildDrawer(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final translations = Translations.of(context);

    Widget buildButton(IconData iconData, int page, String key) {
      final color = Settings.majorColor;

      return Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        height: 54,
        child: Container(
          decoration: BoxDecoration(
              color: page == _currentPage ? color.withOpacity(0.4) : null,
              borderRadius: const BorderRadius.all(Radius.circular(10))),
          child: InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            hoverColor: color,
            highlightColor: color.withOpacity(0.2),
            focusColor: color,
            splashColor: color.withOpacity(0.3),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(iconData),
                const SizedBox(width: 12),
                Text(
                  translations.trans(key),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _pageController.jumpToPage(page);
              });
              Navigator.pop(context);
            },
          ),
        ),
      );
    }

    return Container(
      width: 220,
      padding: mediaQuery.padding + mediaQuery.viewInsets,
      child: Drawer(
        child: Column(
          children: <Widget>[
            Container(
              margin: const EdgeInsets.all(40),
              child: Column(
                children: <Widget>[
                  InkWell(
                    child: Image.asset(
                      'assets/images/logo-${Settings.majorColor.name}.png',
                      width: 100,
                      height: 100,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Project Violet',
                    style: TextStyle(
                      color: Settings.themeWhat ? Colors.white : Colors.black87,
                      fontSize: 18.0,
                      fontFamily: 'Calibre-Semibold',
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    UpdateSyncManager.currentVersion,
                    style: const TextStyle(
                      fontFamily: 'Calibre-Semibold',
                      fontSize: 17.0,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            if (!Settings.liteMode) buildButton(MdiIcons.home, 0, 'main'),
            buildButton(Icons.search, !Settings.liteMode ? 1 : 0, 'search'),
            if (Settings.liteMode) buildButton(MdiIcons.fire, 1, 'hot'),
            buildButton(MdiIcons.bookmark, 2, 'bookmark'),
            buildButton(MdiIcons.download, 3, 'download'),
            buildButton(Icons.settings, 4, 'settings'),
            const Spacer(),
            Text(
              'Copyright (C) 2020-2024\nby project-violet',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 12.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    Variables.updatePadding((mediaQuery.padding + mediaQuery.viewInsets).top,
        (mediaQuery.padding + mediaQuery.viewInsets).bottom);

    return WillPopScope(
      onWillPop: () async {
        DateTime now = DateTime.now();

        if (_lastPopAt != null &&
            now.difference(_lastPopAt!) <= const Duration(seconds: 2)) {
          if (Platform.isAndroid) {
            await PlatformMiscMethods.instance.finishMainActivity();
          }

          return true;
        }

        _lastPopAt = now;

        fToast.showToast(
          child: ToastWrapper(
            isCheck: false,
            isWarning: true,
            icon: Icons.logout,
            msg: Translations.of(context).trans('closedoubletap'),
          ),
          ignorePointer: true,
          gravity: ToastGravity.BOTTOM,
          toastDuration: const Duration(seconds: 4),
        );

        return false;
      },
      child: Scaffold(
        bottomNavigationBar: _usesBottomNavigationBar
            ? _buildBottomNavigationBar(context)
            : null,
        drawer: _usesDrawer ? _buildDrawer(context) : null,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: !Settings.themeWhat
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          child: Stack(
            children: [
              if (kReleaseMode) const ScriptWebView(),
              PageView(
                controller: _pageController,
                physics:
                    _usesDrawer ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (newPage) {
                  setState(() {});
                },
                children: <Widget>[
                  if (!Settings.liteMode) MainPage(key: _widgetKeys[0]),
                  SearchPage(key: _widgetKeys[1]),
                  if (Settings.liteMode) HotPage(key: _widgetKeys[2]),
                  BookmarkPage(key: _widgetKeys[3]),
                  DownloadPage(key: _widgetKeys[4]),
                  SettingsPage(key: _widgetKeys[5]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
