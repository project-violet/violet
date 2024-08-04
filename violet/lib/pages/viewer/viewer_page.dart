// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:apple_pencil_double_tap/apple_pencil_double_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/context/viewer_context.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/viewer/horizontal_viewer_page.dart';
import 'package:violet/pages/viewer/others/lifecycle_event_handler.dart';
import 'package:violet/pages/viewer/overlay/viewer_overlay.dart';
import 'package:violet/pages/viewer/vertical_viewer_page.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/util/call_once.dart';
import 'package:violet/util/evict_image_urls.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late CallOnce _initProvider;
  late ViewerPageProvider _pageInfo;
  late ViewerController c;
  late String getxId;
  late DateTime _startsTime, _inactivateTime;
  late LifecycleEventHandler _lifecycleEventHandler;
  Timer? _nextPageTimer;
  int _inactivateSeconds = 0;

  _tidyImageCache() {
    ImageCache imageCache = PaintingBinding.instance.imageCache;
    if (imageCache.currentSizeBytes >= (1024 + 256) << 20) {
      imageCache.clear();
      imageCache.clearLiveImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    _tidyImageCache();

    final mediaQuery = MediaQuery.of(context);

    final view = Obx(
      () => Stack(
        children: [
          if (c.viewType.value == ViewType.horizontal)
            HorizontalViewerPage(getxId: getxId)
          else
            VerticalViewerPage(getxId: getxId),
          ViewerOverlay(getxId: getxId),
        ],
      ),
    );

    late Widget body;

    if (c.fullscreen.value) {
      body = AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        sized: false,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: view,
        ),
      );
    } else {
      body = Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Padding(
          padding: mediaQuery.padding + mediaQuery.viewInsets,
          child: view,
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvoked: _handlePopInvoked,
      child: body,
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initProvider.call();
  }

  @override
  void dispose() {
    _dispose();
    if (_nextPageTimer != null) _nextPageTimer!.cancel();
    super.dispose();
  }

  _init() {
    _initProvider = CallOnce(_initAfterProvider);
    _startsTime = DateTime.now();

    if (!Settings.disableFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    }

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      if (_pageInfo.jumpPage != null) {
        c.jump(_pageInfo.jumpPage!);
      } else {
        c.bookmark.value =
            await (await Bookmark.getInstance()).isBookmark(_pageInfo.id);

        if (Settings.showRecordJumpMessage) {
          await Future.delayed(const Duration(milliseconds: 100))
              .then((value) => _checkLatestRead());
        }
      }

      c.startTimer();
    });

    _lifecycleEventHandler = LifecycleEventHandler(
      inactiveCallBack: () async {
        _inactivateTime = DateTime.now();
        await (await User.getInstance())
            .updateUserLog(_pageInfo.id, c.page.value);
      },
      resumeCallBack: () async {
        _inactivateSeconds +=
            DateTime.now().difference(_inactivateTime).inSeconds;
        await ScriptManager.refresh();
      },
    );

    ApplePencilDoubleTap().listen((PreferredDoubleTapAction preferedAction) {
      if (ModalRoute.of(context)!.isCurrent) {
        c.next();
      }
    });

    WidgetsBinding.instance.addObserver(_lifecycleEventHandler);
  }

  _dispose() {
    PaintingBinding.instance.imageCache.clear();
    if (_pageInfo.useWeb) {
      evictImageUrls(_pageInfo.uris);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    imageCache.clear();
    imageCache.clearLiveImages();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    WidgetsBinding.instance.removeObserver(_lifecycleEventHandler);
    ViewerContext.pop();
    Get.delete<ViewerController>(tag: getxId);
  }

  void startTimer() {
    if (_nextPageTimer != null) {
      _nextPageTimer!.cancel();
      _nextPageTimer = null;
    }
    if (Settings.enableTimer) {
      _nextPageTimer = Timer.periodic(
        Duration(milliseconds: (Settings.timerTick * 1000).toInt()),
        nextPageTimerCallback,
      );
    }
  }

  void stopTimer() {
    if (_nextPageTimer != null) {
      _nextPageTimer!.cancel();
      _nextPageTimer = null;
    }
  }

  Future<void> nextPageTimerCallback(timer) async {
    c.next();
  }

  _initAfterProvider() {
    _pageInfo = Provider.of<ViewerPageProvider>(context);
    getxId = const Uuid().v4();
    c = Get.put(
      ViewerController(
        context,
        _pageInfo,
        close: _close,
        replace: _replace,
        startTimer: startTimer,
        stopTimer: stopTimer,
      ),
      tag: getxId,
    );
    ViewerContext.push(c);

    if (Platform.isAndroid) _setupVolume();
  }

  Future<void> _close() async {
    c.onSession.value = false;
    await _savePageRead();
  }

  Future<void> _handlePopInvoked(bool didPop) async {
    await _close();
  }

  _setupVolume() {
    const EventChannel('xyz.project.violet/volume')
        .receiveBroadcastStream()
        .listen((event) {
      if (event is String) {
        if (event == 'up') {
          c.prev();
        } else if (event == 'down') {
          c.next();
        }
      }
    });
  }

  _checkLatestRead([bool moveAnywhere = false]) async {
    final user = await User.getInstance();
    final log = await user.getUserLog();

    final x = log.where((e) => e.articleId() == _pageInfo.id.toString());
    if (x.length < 2) return;

    final e = x.elementAt(1);
    if (e.lastPage() == null) return;
    if (e.lastPage()! <= 1 ||
        DateTime.now().difference(DateTime.parse(e.datetimeStart())).inDays >
            7) {
      return;
    }

    if (!moveAnywhere) {
      final isJump = await showYesNoDialog(
        context,
        locale.Translations.of(context)
            .trans('recordmessage')
            .replaceAll('%s', e.lastPage().toString()),
        locale.Translations.of(context).trans('record'),
      );
      if (!isJump) return;

      c.jump(e.lastPage()! - 1);
    }
  }

  _savePageRead() async {
    await (await User.getInstance())
        .updateUserLog(_pageInfo.id, c.page.value + 1);
    if (!_pageInfo.useFileSystem && Settings.useVioletServer) {
      VioletServer.viewClose(
          _pageInfo.id,
          DateTime.now().difference(_startsTime).inSeconds -
              _inactivateSeconds);
    }
  }

  _replace(QueryResult article) async {
    await _savePageRead();

    await (await User.getInstance()).insertUserLog(article.id(), 0);

    var prov = await ProviderManager.get(article.id());
    var headers = await prov.getHeader(0);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation1, animation2) =>
            Provider<ViewerPageProvider>.value(
          value: ViewerPageProvider(
            uris: List<String>.filled(prov.length(), ''),
            useProvider: true,
            provider: prov,
            headers: headers,
            id: article.id(),
            title: article.title(),
            usableTabList: _pageInfo.usableTabList,
          ),
          child: const ViewerPage(),
        ),
      ),
    );
  }
}
