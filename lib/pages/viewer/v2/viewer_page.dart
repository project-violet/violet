// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/viewer/others/lifecycle_event_handler.dart';
import 'package:violet/pages/viewer/v2/horizontal_viewer_page.dart';
import 'package:violet/pages/viewer/v2/vertical_viewer_page.dart';
import 'package:violet/pages/viewer/v2/viewer_controller.dart';
import 'package:violet/pages/viewer/v2/viewer_overlay.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/util/call_once.dart';

const volumeKeyChannel = EventChannel('xyz.project.violet/volume');

class ViewerPage extends StatefulWidget {
  const ViewerPage({Key? key}) : super(key: key);

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final CallOnce _initProvider;
  late ViewerPageProvider _pageInfo;
  late ViewerController c;
  late DateTime _startsTime, _inactivateTime;
  late final LifecycleEventHandler _lifecycleEventHandler;
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

    return WillPopScope(
      onWillPop: () async {
        c.onSession.value = false;
        await _savePageRead();
        return Future(() => true);
      },
      child: Stack(
        children: [
          Obx(() => c.viewType.value == ViewType.horizontal
              ? const HorizontalViewerPage()
              : const VerticalViewerPage()),
          const ViewerOverlay(),
        ],
      ),
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
    super.dispose();
  }

  _init() {
    _initProvider = CallOnce(_initAfterProvider);
    _startsTime = DateTime.now();

    if (Settings.showRecordJumpMessage) {
      Future.delayed(const Duration(milliseconds: 100))
          .then((value) => _checkLatestRead());
    }

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

    WidgetsBinding.instance.addObserver(_lifecycleEventHandler);
  }

  _dispose() {
    PaintingBinding.instance.imageCache.clear();
    if (_pageInfo.useWeb) {
      _pageInfo.uris.forEach((element) async {
        await CachedNetworkImageProvider(element).evict();
      });
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
  }

  _initAfterProvider() {
    _pageInfo = Provider.of<ViewerPageProvider>(context);
    c = Get.put(ViewerController(_pageInfo));
    _setupVolume();
  }

  _setupVolume() {
    volumeKeyChannel.receiveBroadcastStream().listen((event) {
      if (event is String) {
        if (event == 'down') {
          c.prev();
        } else if (event == 'up') {
          c.next();
        }
      }
    });
  }

  Future<void> _checkLatestRead([bool moveAnywhere = false]) async {
    final user = await User.getInstance();
    final log = await user.getUserLog();

    final x = log.where((e) => e.articleId() == _pageInfo.id.toString());
    if (x.length < 2) return;

    final e = x.elementAt(1);
    if (e.lastPage() == null) return;
    if (e.lastPage()! <= 1 ||
        DateTime.now().difference(DateTime.parse(e.datetimeStart())).inDays <=
            7) return;

    if (!moveAnywhere) {
      final isJump = await showYesNoDialog(
        context,
        locale.Translations.of(context)
            .trans('recordmessage')
            .replaceAll('%s', e.lastPage().toString()),
        locale.Translations.of(context).trans('record'),
      );
      if (!isJump) return;
    }

    c.jump(e.lastPage()! - 1);
  }

  Future<void> _savePageRead() async {
    await (await User.getInstance())
        .updateUserLog(_pageInfo.id, c.page.value + 1);
    if (!_pageInfo.useFileSystem && Settings.useVioletServer) {
      VioletServer.viewClose(
          _pageInfo.id,
          DateTime.now().difference(_startsTime).inSeconds -
              _inactivateSeconds);
    }
  }
}
