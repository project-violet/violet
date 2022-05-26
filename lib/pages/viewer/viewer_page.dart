// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/viewer/others/lifecycle_event_handler.dart';
import 'package:violet/pages/viewer/others/photo_view_gallery.dart';
import 'package:violet/pages/viewer/others/preload_page_view.dart';
import 'package:violet/pages/viewer/tab_panel.dart';
import 'package:violet/pages/viewer/v_cached_network_image.dart';
import 'package:violet/pages/viewer/view_record_panel.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/pages/viewer/viewer_report.dart';
import 'package:violet/pages/viewer/viewer_setting_panel.dart';
import 'package:violet/pages/viewer/viewer_thumbnails.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';
import 'package:violet/variables.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/toast.dart';

const volumeKeyChannel = EventChannel('xyz.project.violet/volume');

typedef DoubleCallback = Future Function(double);
typedef BoolCallback = Function(bool);
typedef StringCallback = Future Function(String);

class ViewerPage extends StatefulWidget {
  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage>
    with SingleTickerProviderStateMixin {
  late ViewerPageProvider _pageInfo;
  bool isPageInfoInited = false;
  late final LifecycleEventHandler _lifecycleEventHandler;
  Timer? _nextPageTimer;
  final ValueNotifier<bool> _vIsBookmarked = ValueNotifier(false);
  bool _isSessionOutdated = false;
  bool _sliderOnChange = false;

  /// the index value of the page currently displayed on the screen
  int _currentPage = 0;

  /// user-identifiable page number
  /// the difference from _currentPage is that the page numbering shown
  /// to the actual user may not match the page in the current image list.
  /// for example, when a slide is manipulated in file system mode, the value
  /// displayed on the slider changes, but the page of the list does not change.
  int _prevPage = 1;
  final ValueNotifier<int> _vPrevPage = ValueNotifier(0);

  /// these are used for overlay
  double _opacity = 0.0;
  bool _disableBottom = true;
  bool _overlayOpend = false;

  /// these are used for page control
  PreloadPageController _pageController = PreloadPageController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  /// this is used for interactive viewer widget
  /// double-tap a specific location to zoom in on that location.
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  /// lock scroll after zoom gesture
  /// this prevents paging on zoom gesture are performed
  bool _scrollListEnable = true;

  /// these are used for VioletServer.viewReport
  late ViewerReport _report;
  int _inactivateSeconds = 0;
  late DateTime _startsTime;
  DateTime? _inactivateTime;
  late List<int> _decisecondPerPages;
  late List<bool> _isImageLoaded;

  /// check if the current user is using this app.
  bool _isStaring = true;

  /// these are used for thumbnail slider
  final ScrollController _thumbController = ScrollController();
  late List<double> _thumbImageWidth;
  late List<double> _thumbImageStartPos;

  /// It is height that a widget that has an image as a child.
  List<double>? _height;

  /// Image widget key
  /// This is used to get the height of a widget that has an image as a child.
  List<GlobalKey>? _keys;

  /// this is used on provider
  /// caching image header information
  List<Map<String, String>?>? _headerCache;

  /// this is used on provider
  /// caching image url
  List<String?>? _urlCache;

  /// this is used on provider
  /// caching estimated image height
  List<double>? _estimatedImageHeight;

  /// this is used on provider
  /// determine estimaed height is loaded
  List<bool>? _loadingEstimaed;

  /// these are used on [_patchHeightForDynamicLoadedImage]
  int _latestIndex = 0;
  double _latestAlign = 0;
  bool _onScroll = false;

  /// Is enabled thumbnail slider?
  bool _isThumbMode = false;

  /// Thumbnail slider height including image and page text
  double _thumbHeight = 140.0;

  late final FToast fToast;

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);

    if (!Settings.disableFullScreen)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    if (Settings.showRecordJumpMessage)
      Future.delayed(Duration(milliseconds: 100))
          .then((value) => _checkLatestRead());

    Future.delayed(Duration(milliseconds: 100)).then((value) async =>
        _vIsBookmarked.value =
            await (await Bookmark.getInstance()).isBookmark(_pageInfo.id));

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    )..addListener(() {
        if (_animation != null)
          _transformationController.value = _animation!.value;
      });

    _itemPositionsListener.itemPositions.addListener(() {
      if (_isSessionOutdated) return;
      if (_sliderOnChange) return;

      var v = _itemPositionsListener.itemPositions.value.toList();
      int? selected;

      v.sort((x, y) => x.itemLeadingEdge.compareTo(y.itemLeadingEdge));

      for (var e in v) {
        if (e.itemLeadingEdge <= 0.125) {
          selected = e.index;
        } else {
          break;
        }
      }

      _getLatestHeight();

      if (selected != null && _prevPage != selected + 1) {
        if (_isThumbMode && !_sliderOnChange) {
          _thumbAnimateTo(selected);
        }

        _prevPage = selected + 1;
        _vPrevPage.value = _prevPage;
        _currentPage = _prevPage;
      }
    });

    _lifecycleEventHandler = LifecycleEventHandler(
      inactiveCallBack: () async {
        _inactivateTime = DateTime.now();
        _isStaring = false;
        await (await User.getInstance())
            .updateUserLog(_pageInfo.id, _currentPage);
      },
      resumeCallBack: () async {
        _inactivateSeconds +=
            DateTime.now().difference(_inactivateTime!).inSeconds;
        _isStaring = true;
        await ScriptManager.refresh();
      },
    );

    WidgetsBinding.instance.addObserver(_lifecycleEventHandler);

    _startsTime = DateTime.now();

    startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isPageInfoInited) {
      isPageInfoInited = true;
      _pageInfo = Provider.of<ViewerPageProvider>(context);
      _report = ViewerReport(
        id: _pageInfo.id,
        pages: _pageInfo.uris.length,
        startsTime: DateTime.now(),
      );
      _decisecondPerPages = List.filled(_pageInfo.uris.length, 0);

      _isImageLoaded =
          List.filled(_pageInfo.uris.length, _pageInfo.useFileSystem);

      if (_pageInfo.useFileSystem) _preprocessImageInfoForFileImage();

      Timer.periodic(
        Duration(milliseconds: 100),
        pageReadTimerCallback,
      );
    }
    volumeKeyChannel.receiveBroadcastStream().listen((event) {
      if (event is String) {
        if (event == 'down') {
          _rightButtonEvent();
        } else if (event == 'up') {
          _leftButtonEvent();
        }
      }
    });
  }

  _preprocessImageInfoForFileImage() {
    _thumbHeight = [140.0, 120.0, 96.0][Settings.thumbSize];
    _isThumbMode = Settings.enableThumbSlider;

    var imageSizes = _pageInfo.uris.map((e) {
      final image = File(e);
      if (!image.existsSync()) return null;
      return ImageSizeGetter.getSize(FileInput(image));
    }).toList();

    _thumbImageStartPos = List.filled(imageSizes.length + 1, 0);
    _thumbImageWidth = List.filled(imageSizes.length, 0);

    for (var i = 0; i < imageSizes.length; i++) {
      final sz = imageSizes[i];

      if (sz != null)
        _thumbImageStartPos[i + 1] =
            (_thumbHeight - 14.0) * sz.width / sz.height;
      else
        _thumbImageStartPos[i + 1] = (_thumbHeight - 14.0) / 36 * 25;

      _thumbImageWidth[i] = _thumbImageStartPos[i + 1];
      _thumbImageStartPos[i + 1] += _thumbImageStartPos[i];
    }
  }

  @override
  void dispose() {
    if (_nextPageTimer != null) _nextPageTimer!.cancel();
    PaintingBinding.instance.imageCache.clear();
    if (_pageInfo.useWeb)
      _pageInfo.uris.forEach((element) async {
        await CachedNetworkImageProvider(element).evict();
      });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    imageCache.clear();
    imageCache.clearLiveImages();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleEventHandler);
    super.dispose();
  }

  Future<void> _savePageRead(bool useFileSystem) async {
    await (await User.getInstance()).updateUserLog(_pageInfo.id, _currentPage);
    if (!useFileSystem && Settings.useVioletServer) {
      _report.endsTime = DateTime.now();
      _report.validSeconds =
          DateTime.now().difference(_startsTime).inSeconds - _inactivateSeconds;
      _report.lastPage = _currentPage;
      _report.msPerPages = _decisecondPerPages;

      VioletServer.viewClose(
              _pageInfo.id,
              DateTime.now().difference(_startsTime).inSeconds -
                  _inactivateSeconds)
          .then((value) {
        VioletServer.viewReport(_report);
      });
    }
  }

  Future<void> pageReadTimerCallback(timer) async {
    if (_isStaring) {
      var page = _prevPage - 1 < 0
          ? 0
          : _prevPage - 1 >= _pageInfo.uris.length
              ? _pageInfo.uris.length - 1
              : _prevPage - 1;

      if (_isImageLoaded[page]) _decisecondPerPages[page] += 1;
    }
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
    var next = _prevPage + 1;
    if (next < 1 || next > _pageInfo.uris.length) return;
    if (!Settings.isHorizontal) {
      if (!Settings.animation) {
        await _itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(microseconds: 1),
          alignment: 0.12,
        );
      } else {
        _sliderOnChange = true;
        await _itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
        Future.delayed(Duration(milliseconds: 300)).then((value) {
          _sliderOnChange = false;
        });
      }
    } else {
      if (!Settings.animation) {
        _pageController.jumpToPage(next - 1);
      } else {
        _pageController.animateToPage(
          next - 1,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
    _thumbAnimateTo(next - 1);
    _currentPage = next;
    _prevPage = next;
    _vPrevPage.value = next;
  }

  void _checkLatestRead([bool moveAnywhere = false]) {
    User.getInstance().then((value) => value.getUserLog().then((value) async {
          var x = value.where((e) => e.articleId() == _pageInfo.id.toString());
          if (x.length < 2) return;
          var e = x.elementAt(1);
          if (e.lastPage() == null) return;
          print(DateTime.parse(e.datetimeStart())
              .difference(DateTime.now())
              .inDays);
          if (e.lastPage()! > 1 &&
              DateTime.now()
                      .difference(DateTime.parse(e.datetimeStart()))
                      .inDays <
                  7) {
            if (moveAnywhere ||
                await showYesNoDialog(
                    context,
                    Translations.of(context)
                        .trans('recordmessage')
                        .replaceAll('%s', e.lastPage().toString()),
                    Translations.of(context).trans('record'))) {
              if (!Settings.isHorizontal) {
                _latestIndex = e.lastPage()! - 1;
                _itemScrollController.scrollTo(
                  index: e.lastPage()! - 1,
                  duration: Duration(microseconds: 1),
                  alignment: 0.12,
                );
              } else {
                _pageController.jumpToPage(e.lastPage()! - 1);
              }
            }
          }
        }));
  }

  @override
  Widget build(BuildContext context) {
    ImageCache imageCache = PaintingBinding.instance.imageCache;
    final mediaQuery = MediaQuery.of(context);
    if (imageCache.currentSizeBytes >= (1024 + 256) << 20) {
      imageCache.clear();
      imageCache.clearLiveImages();
    }

    return WillPopScope(
      onWillPop: () async {
        _isSessionOutdated = true;
        await _savePageRead(_pageInfo.useFileSystem);
        return Future(() => true);
      },
      child: () {
        if (Settings.disableFullScreen) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: Padding(
              padding: mediaQuery.padding + mediaQuery.viewInsets,
              child:
                  Settings.isHorizontal ? _bodyHorizontal() : _bodyVertical(),
            ),
          );
        } else {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
            sized: false,
            child: Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              body: Settings.isHorizontal ? _bodyHorizontal() : _bodyVertical(),
            ),
          );
        }
      }(),
    );
  }

  _exitButton() {
    final statusBarHeight =
        Settings.disableFullScreen ? MediaQuery.of(context).padding.top : 0;
    final height = MediaQuery.of(context).size.height;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Duration(milliseconds: 300),
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        child: AnimatedPadding(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            top: height -
                Variables.bottomBarHeight -
                (48 + 48 + 48 + 32 - 24) -
                (_isThumbMode ? _thumbHeight.toInt() : 0) -
                (Settings.showSlider ? 48.0 : 0) -
                statusBarHeight,
            bottom: (48 + 48.0 + 32 - 24) +
                (_isThumbMode ? _thumbHeight.toInt() : 0) +
                (Settings.showSlider ? 48.0 : 0),
            left: 48.0,
            right: 48.0,
          ),
          child: CupertinoButton(
            minSize: 48.0,
            color: Colors.black.withOpacity(0.8),
            pressedOpacity: 0.4,
            disabledColor: CupertinoColors.quaternarySystemFill,
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            onPressed: () async {
              _isSessionOutdated = true;
              await _savePageRead(_pageInfo.useFileSystem);
              Navigator.pop(context, _currentPage);
              return Future(() => false);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back, size: 20.0),
                Container(width: 10),
                Text('Exit'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _appBar() {
    final statusBarHeight =
        Settings.disableFullScreen ? MediaQuery.of(context).padding.top : 0;
    final height = MediaQuery.of(context).size.height;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Duration(milliseconds: 300),
      child: Stack(
        children: [
          !Settings.disableFullScreen
              ? Padding(
                  padding: EdgeInsets.only(top: statusBarHeight.toDouble()),
                  child: Container(
                    height: Variables.statusBarHeight,
                    color: Colors.black,
                  ),
                )
              : Container(),
          Container(
            padding: !Settings.moveToAppBarToBottom
                ? EdgeInsets.only(
                    top: !Settings.disableFullScreen
                        ? Variables.statusBarHeight
                        : 0.0)
                : EdgeInsets.only(
                    top: height -
                        Variables.bottomBarHeight -
                        (48) -
                        (Platform.isIOS ? 48 - 24 : 0) -
                        statusBarHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: Settings.moveToAppBarToBottom
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Material(
                  color: Colors.black.withOpacity(0.8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _appBarBack(),
                      Expanded(
                        child: Row(
                          children: [
                            _appBarBookmark(),
                            _appBarInfo(),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _appBarTab(),
                          _appBarHistory(),
                          _appBarTimer(),
                          _appBarGallery(),
                          _appBarSettings(),
                        ],
                      ),
                    ],
                  ),
                ),
                !Settings.disableFullScreen && Settings.moveToAppBarToBottom
                    ? Container(
                        height: Variables.bottomBarHeight +
                            (Platform.isIOS ? 48 - 24 : 0),
                        color: Platform.isIOS
                            ? Colors.black.withOpacity(0.8)
                            : Colors.black,
                      )
                    : Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _appBarBack() {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      color: Colors.white,
      onPressed: () async {
        _isSessionOutdated = true;
        await _savePageRead(_pageInfo.useFileSystem);
        Navigator.pop(context, _currentPage);
        return Future(() => false);
      },
    );
  }

  _appBarBookmark() {
    return ValueListenableBuilder(
      valueListenable: _vIsBookmarked,
      builder: (BuildContext context, bool value, Widget? child) {
        return IconButton(
          icon: Icon(value ? MdiIcons.heart : MdiIcons.heartOutline),
          color: Colors.white,
          onPressed: () async {
            _vIsBookmarked.value =
                await (await Bookmark.getInstance()).isBookmark(_pageInfo.id);

            if (_vIsBookmarked.value) {
              if (!await showYesNoDialog(context, '북마크를 삭제할까요?', '북마크')) return;
            }

            fToast.showToast(
              child: ToastWrapper(
                icon: _vIsBookmarked.value ? Icons.delete_forever : Icons.check,
                color: _vIsBookmarked.value
                    ? Colors.redAccent.withOpacity(0.8)
                    : Colors.greenAccent.withOpacity(0.8),
                ignoreDrawer: true,
                reverse: true,
                msg:
                    '${_pageInfo.id}${Translations.of(context).trans(!_vIsBookmarked.value ? 'addtobookmark' : 'removetobookmark')}',
              ),
              gravity: ToastGravity.TOP,
              toastDuration: Duration(seconds: 4),
            );

            _vIsBookmarked.value = !_vIsBookmarked.value;
            if (_vIsBookmarked.value)
              await (await Bookmark.getInstance()).bookmark(_pageInfo.id);
            else
              await (await Bookmark.getInstance()).unbookmark(_pageInfo.id);
          },
        );
      },
    );
  }

  _appBarInfo() {
    return IconButton(
      icon: Icon(MdiIcons.information),
      color: Colors.white,
      onPressed: () async {
        final height = MediaQuery.of(context).size.height;

        final search = await HentaiManager.idSearch(_pageInfo.id.toString());
        if (search.item1.length != 1) return;

        final qr = search.item1[0];

        if (!ProviderManager.isExists(qr.id()))
          await HentaiManager.getImageProvider(qr).then((value) async {
            ProviderManager.insert(qr.id(), value);
          });

        var prov = await ProviderManager.get(_pageInfo.id);
        var thumbnail = await prov.getThumbnailUrl();
        var headers = await prov.getHeader(0);
        ProviderManager.insert(qr.id(), prov);

        var isBookmarked =
            await (await Bookmark.getInstance()).isBookmark(qr.id());

        _isStaring = false;
        stopTimer();

        Provider<ArticleInfo>? cache;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) {
            return DraggableScrollableSheet(
              initialChildSize: 400 / height,
              minChildSize: 400 / height,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                if (cache == null) {
                  cache = Provider<ArticleInfo>.value(
                    child: ArticleInfoPage(
                      key: ObjectKey('asdfasdf'),
                    ),
                    value: ArticleInfo.fromArticleInfo(
                      queryResult: qr,
                      thumbnail: thumbnail,
                      headers: headers,
                      heroKey: 'zxcvzxcvzxcv',
                      isBookmarked: isBookmarked,
                      controller: controller,
                      lockRead: true,
                    ),
                  );
                }
                return cache!;
              },
            );
          },
        ).then((value) {
          _isStaring = true;
          startTimer();
        });
      },
    );
  }

  _appBarTab() {
    final height = MediaQuery.of(context).size.height;
    return IconButton(
      icon: Icon(MdiIcons.tab),
      color: Colors.white,
      onPressed: () async {
        stopTimer();
        _isStaring = false;
        TabPanel? cache;
        await showModalBottomSheet(
            context: context,
            isScrollControlled: false,
            builder: (context) {
              if (cache == null)
                cache = TabPanel(
                  articleId: _pageInfo.id,
                  usableTabList: _pageInfo.usableTabList,
                  height: height,
                );
              return cache!;
            }).then((value) async {
          if (value == null) return;

          await _savePageRead(_pageInfo.useFileSystem);

          await (await User.getInstance()).insertUserLog(value.id(), 0);

          _inactivateSeconds = 0;
          _startsTime = DateTime.now();

          if (!Settings.isHorizontal) {
            _itemScrollController.scrollTo(
              index: 0,
              duration: Duration(microseconds: 1),
              alignment: 0.12,
            );
          } else {
            _pageController.jumpToPage(0);
          }
          _currentPage = 0;
          _prevPage = 0;
          _vPrevPage.value = 0;

          var prov = await ProviderManager.get(value.id());
          var headers = await prov.getHeader(0);

          _pageInfo = ViewerPageProvider(
            uris: List<String>.filled(prov.length(), ''),
            useProvider: true,
            provider: prov,
            headers: headers,
            id: value.id(),
            title: value.title(),
            usableTabList: _pageInfo.usableTabList,
          );

          _report = ViewerReport(
            id: _pageInfo.id,
            pages: _pageInfo.uris.length,
            startsTime: DateTime.now(),
          );
          _decisecondPerPages = List.filled(_pageInfo.uris.length, 0);
          _isImageLoaded = List.filled(_pageInfo.uris.length, false);

          _headerCache =
              List<Map<String, String>?>.filled(_pageInfo.uris.length, null);
          _urlCache = List<String?>.filled(_pageInfo.uris.length, null);
          _height = List<double>.filled(_pageInfo.uris.length, 0);
          _keys = List<GlobalKey>.generate(
              _pageInfo.uris.length, (index) => GlobalKey());
          _estimatedImageHeight = List<double>.filled(_pageInfo.uris.length, 0);
          _loadingEstimaed = List<bool>.filled(_pageInfo.uris.length, false);
          _latestIndex = 0;
          _latestAlign = 0;
          _onScroll = false;

          setState(() {});

          Future.delayed(Duration(milliseconds: 300))
              .then((value) => _checkLatestRead(true));
        });
        startTimer();
        _isStaring = true;
      },
    );
  }

  _appBarHistory() {
    return IconButton(
      icon: Icon(MdiIcons.history),
      color: Colors.white,
      onPressed: () async {
        stopTimer();
        _isStaring = false;
        ViewRecordPanel? cache;
        await showModalBottomSheet(
            context: context,
            isScrollControlled: false,
            builder: (context) {
              if (cache == null)
                cache = ViewRecordPanel(
                  articleId: _pageInfo.id,
                );
              return cache!;
            }).then((value) {
          if (value != null) {
            if (!Settings.isHorizontal) {
              _itemScrollController.scrollTo(
                index: value,
                duration: Duration(microseconds: 1),
                alignment: 0.12,
              );
            } else {
              _pageController.jumpToPage(value - 1);
            }
            _currentPage = value;
            _prevPage = value;
            _vPrevPage.value = value;
          }
        });
        startTimer();
        _isStaring = true;
      },
    );
  }

  _appBarTimer() {
    return IconButton(
      icon: Icon(Settings.enableTimer ? MdiIcons.timer : MdiIcons.timerOff),
      color: Colors.white,
      onPressed: () async {
        setState(() {
          Settings.setEnableTimer(!Settings.enableTimer);
        });
        startTimer();
      },
    );
  }

  _appBarGallery() {
    return IconButton(
      icon: Icon(MdiIcons.folderImage),
      color: Colors.white,
      onPressed: () async {
        stopTimer();
        _isStaring = false;
        FractionallySizedBox? cache;
        await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              if (cache == null)
                cache = FractionallySizedBox(
                  heightFactor: 0.8,
                  child: Provider<ViewerPageProvider>.value(
                    value: _pageInfo,
                    child: ViewerThumbnail(
                      viewedPage: _currentPage - 1,
                    ),
                  ),
                );
              return cache!;
            }).then((value) async {
          if (value != null) {
            if (value != null) {
              if (!Settings.isHorizontal) {
                _itemScrollController.scrollTo(
                  index: value,
                  duration: Duration(microseconds: 1),
                  alignment: 0.12,
                );
              } else {
                _pageController.jumpToPage(value - 1);
              }
              _currentPage = value;
              _prevPage = value;
              _vPrevPage.value = value;
            }
          }
          startTimer();
          _isStaring = true;
        });
      },
    );
  }

  _appBarSettings() {
    return IconButton(
      icon: Icon(Icons.settings),
      color: Colors.white,
      onPressed: () async {
        stopTimer();
        _isStaring = false;
        ViewerSettingPanel? cache;
        await showModalBottomSheet(
            context: context,
            isScrollControlled: false,
            builder: (context) {
              if (cache == null)
                cache = ViewerSettingPanel(
                  viewerStyleChangeEvent: () {
                    if (Settings.isHorizontal) {
                      _pageController =
                          PreloadPageController(initialPage: _prevPage - 1);
                    } else {
                      var npage = _prevPage;
                      _sliderOnChange = true;
                      Future.delayed(Duration(milliseconds: 180)).then((value) {
                        _itemScrollController.scrollTo(
                          index: npage - 1,
                          duration: Duration(microseconds: 1),
                          alignment: 0.12,
                        );
                        _sliderOnChange = false;
                      });
                    }
                    setState(() {});
                  },
                  thumbSizeChangeEvent: () {
                    _preprocessImageInfoForFileImage();
                  },
                  setStateCallback: () {
                    setState(() {});
                  },
                );
              return cache!;
            });
        startTimer();
        _isStaring = true;
        return;
      },
    );
  }

  // _appBarPageInfo() {
  //   return Expanded(
  //     child: Text(
  //       _pageInfo.id.toString(),
  //       maxLines: 1,
  //       overflow: TextOverflow.ellipsis,
  //       style: TextStyle(
  //         color: Colors.white,
  //         fontSize: 19,
  //       ),
  //       onTap: () async {
  //         stopTimer();
  //         await showModalBottomSheet(
  //           context: context,
  //           isScrollControlled: false,
  //           builder: (context) => ViewRecordPanel(
  //             articleId: _pageInfo.id,
  //           ),
  //         ).then((value) {
  //           if (value != null) {
  //             if (!Settings.isHorizontal) {
  //               _itemScrollController.jumpTo(index: value, alignment: 0.12);
  //             } else {
  //               _pageController.jumpToPage(value - 1);
  //             }
  //             _currentPage = value;
  //             setState(() {
  //               _prevPage = value;
  //             });
  //           }
  //         });
  //         startTimer();
  //       },
  //     ),
  //   );
  // }

  _bodyVertical() {
    final height = MediaQuery.of(context).size.height;

    return Stack(
      children: <Widget>[
        // PhotoView.customChild(
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          child: Container(
            color: Settings.themeWhat && Settings.themeBlack
                ? Colors.black
                : const Color(0xff444444),
            child: NotificationListener(
              child: ScrollablePositionedList.builder(
                physics: _scrollListEnable
                    ? AlwaysScrollableScrollPhysics()
                    : NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _pageInfo.uris.length,
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                minCacheExtent:
                    _pageInfo.useFileSystem ? height * 3.0 : height * 3.0,
                itemBuilder: (context, index) {
                  Widget? image;
                  if (!Settings.padding) {
                    if (_pageInfo.useWeb)
                      image = _networkImageItem(index);
                    else if (_pageInfo.useFileSystem)
                      image = _storageImageItem(index);
                    else if (_pageInfo.useProvider)
                      image = _providerImageItem(index);
                  } else {
                    if (_pageInfo.useWeb)
                      image = Padding(
                        child: _networkImageItem(index),
                        padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                      );
                    else if (_pageInfo.useFileSystem)
                      image = Padding(
                        child: _storageImageItem(index),
                        padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                      );
                    else if (_pageInfo.useProvider)
                      image = Padding(
                        child: _providerImageItem(index),
                        padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                      );
                  }

                  if (image == null) throw Exception('Dead Reaching');

                  return _DoublePointListener(
                    child: image,
                    onStateChanged: (value) {
                      setState(() {
                        _scrollListEnable = value;
                      });
                    },
                  );
                },
              ),
              onNotification: (t) {
                if (t is ScrollStartNotification) {
                  _onScroll = true;
                } else if (t is ScrollEndNotification) {
                  _onScroll = false;
                }
                return false;
              },
            ),
          ),
        ),
        if (Settings.showPageNumberIndicator) _verticalPageLabel(),
        _touchArea(),
        if (!_disableBottom &&
            (!Settings.moveToAppBarToBottom || Settings.showSlider))
          _bottomAppBar(),
        if (!_disableBottom) _appBar(),
        if (Platform.isIOS && !_disableBottom) _exitButton(),
      ],
    );
  }

  _bodyHorizontal() {
    return Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          constraints: BoxConstraints.expand(
            height: MediaQuery.of(context).size.height,
          ),
          child: VPhotoViewGallery.builder(
            scrollPhysics: const AlwaysScrollableScrollPhysics(),
            builder: _buildItem,
            itemCount: _pageInfo.uris.length,
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
            pageController: _pageController,
            onPageChanged: (page) async {
              _thumbAnimateTo(page.toInt());

              _currentPage = page.toInt() + 1;
              _prevPage = page.toInt() + 1;
              _vPrevPage.value = page.toInt() + 1;
              await _precache(page.toInt() - 1);
              await _precache(page.toInt() + 1);
            },
            scrollDirection:
                Settings.scrollVertical ? Axis.vertical : Axis.horizontal,
            reverse: Settings.rightToLeft,
            loadingBuilder: (context, imageChunkEvent) {
              return Center(
                child: SizedBox(
                  child: CircularProgressIndicator(
                      value: imageChunkEvent == null
                          ? 0
                          : imageChunkEvent.cumulativeBytesLoaded /
                              imageChunkEvent.expectedTotalBytes!.toDouble()),
                  width: 30,
                  height: 30,
                ),
              );
            },
          ),
        ),
        if (Settings.showPageNumberIndicator) _verticalPageLabel(),
        _touchAreaMiddle(),
        if (!Settings.disableOverlayButton) _touchAreaLeft(),
        if (!Settings.disableOverlayButton) _touchAreaRight(),
        if (!_disableBottom &&
            (!Settings.moveToAppBarToBottom || Settings.showSlider))
          _bottomAppBar(),
        if (!_disableBottom) _appBar(),
        if (Platform.isIOS && !_disableBottom) _exitButton(),
      ],
    );
  }

  _precache(int index) async {
    if (_pageInfo.useWeb) {
      if (index < 0 || _pageInfo.uris.length <= index) return;
      await precacheImage(
        CachedNetworkImageProvider(
          _pageInfo.uris[index],
          headers: _pageInfo.headers,
        ),
        context,
      );
    } else if (_pageInfo.useProvider) {
      if (index < 0 || _pageInfo.provider!.length() <= index) return;
      if (_headerCache == null) {
        _headerCache =
            List<Map<String, String>?>.filled(_pageInfo.uris.length, null);
        _urlCache = List<String?>.filled(_pageInfo.uris.length, null);
      }
      if (_height == null) {
        _height = List<double>.filled(_pageInfo.uris.length, 0);
        _keys = List<GlobalKey>.generate(
            _pageInfo.uris.length, (index) => GlobalKey());
      }

      if (_headerCache![index] == null) {
        var header = await _pageInfo.provider!.getHeader(index);
        _headerCache![index] = header;
      }

      if (_urlCache![index] == null) {
        var url = await _pageInfo.provider!.getImageUrl(index);
        _urlCache![index] = url;
      }

      await precacheImage(
        CachedNetworkImageProvider(
          _urlCache![index]!,
          headers: _headerCache![index],
        ),
        context,
      );
    }
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    if (_pageInfo.useWeb)
      return PhotoViewGalleryPageOptions(
        imageProvider: CachedNetworkImageProvider(
          _pageInfo.uris[index],
          headers: _pageInfo.headers,
        ),
        filterQuality: SettingsWrapper.imageQuality,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    else if (_pageInfo.useFileSystem) {
      return PhotoViewGalleryPageOptions(
        imageProvider: FileImage(File(_pageInfo.uris[index])),
        filterQuality: SettingsWrapper.imageQuality,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    } else if (_pageInfo.useProvider) {
      return PhotoViewGalleryPageOptions.customChild(
        child: FutureBuilder(
          future: Future.sync(() async {
            if (_headerCache == null) {
              _headerCache = List<Map<String, String>?>.filled(
                  _pageInfo.uris.length, null);
              _urlCache = List<String?>.filled(_pageInfo.uris.length, null);
            }
            if (_height == null) {
              _height = List<double>.filled(_pageInfo.uris.length, 0);
              _keys = List<GlobalKey>.generate(
                  _pageInfo.uris.length, (index) => GlobalKey());
            }

            if (_headerCache![index] == null) {
              var header = await _pageInfo.provider!.getHeader(index);
              _headerCache![index] = header;
            }

            if (_urlCache![index] == null) {
              var url = await _pageInfo.provider!.getImageUrl(index);
              _urlCache![index] = url;
            }

            return Tuple2<Map<String, String>, String>(
                _headerCache![index]!, _urlCache![index]!);
          }),
          builder: (context, snapshot) {
            if (_urlCache![index] != null && _headerCache![index] != null) {
              return PhotoView(
                imageProvider: CachedNetworkImageProvider(
                  _urlCache![index]!,
                  headers: _headerCache![index],
                ),
                filterQuality: SettingsWrapper.imageQuality,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 1.0,
                maxScale: PhotoViewComputedScale.contained * 5.0,
                gestureDetectorBehavior: HitTestBehavior.opaque,
              );
            }

            return SizedBox(
              height: 300,
              child: Center(
                child: SizedBox(
                  child: CircularProgressIndicator(),
                  width: 30,
                  height: 30,
                ),
              ),
            );
          },
        ),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    }
    throw Exception('Dead Reaching');
  }

  _touchArea() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Container(
      color: null,
      width: width,
      height: height,
      child: _CustomDoubleTapGestureDectector(
        onTap: _touchEvent,
        onDoubleTap: _doubleTapEvent,
      ),
    );
  }

  void _touchEvent(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    if (details.localPosition.dx < width / 3) {
      if (!Settings.disableOverlayButton) _leftButtonEvent();
    } else if (width / 3 * 2 < details.localPosition.dx) {
      if (!Settings.disableOverlayButton) _rightButtonEvent();
    } else {
      _middleButtonEvent();
    }
  }

  void _doubleTapEvent(TapDownDetails details) {
    Matrix4 endMatrix;
    Offset position = details.localPosition;

    if (_transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
    } else {
      endMatrix = Matrix4.identity()
        ..translate(-position.dx * 1, -position.dy * 1)
        ..scale(2.0);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );
    _animationController.forward(from: 0);
  }

  _touchAreaMiddle() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.center,
      child: Container(
        color: null,
        width: width / 3,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _middleButtonEvent,
        ),
      ),
    );
  }

  _middleButtonEvent() async {
    if (!_overlayOpend) {
      if (!Settings.isHorizontal) _prevPage = _currentPage;
      // setState(() {});
      setState(() {
        _opacity = 1.0;
        _disableBottom = false;
      });
      if (!Settings.disableFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
          SystemUiOverlay.top,
          SystemUiOverlay.bottom,
        ]);
      }
      _thumbJumpTo(_prevPage >= 1 ? _prevPage - 1 : 0);
    } else {
      setState(() {
        _opacity = 0.0;
      });
      if (!Settings.disableFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      }
      Future.delayed(Duration(milliseconds: 300)).then((value) {
        setState(() {
          _disableBottom = true;
        });
      });
    }
    _overlayOpend = !_overlayOpend;
  }

  _thumbJumpTo(page) {
    if (!_disableBottom && _isThumbMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final width = MediaQuery.of(context).size.width;
        final jumpOffset =
            _thumbImageStartPos[page] - width / 2 + _thumbImageWidth[page] / 2;
        _thumbController.jumpTo(jumpOffset > 0 ? jumpOffset : 0);
      });
    }
  }

  _thumbAnimateTo(page) {
    if (!_disableBottom && _isThumbMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final width = MediaQuery.of(context).size.width;
        final jumpOffset =
            _thumbImageStartPos[page] - width / 2 + _thumbImageWidth[page] / 2;
        _thumbController.animateTo(
          jumpOffset > 0 ? jumpOffset : 0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  _touchAreaLeft() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        color: null,
        width: width / 3,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _leftButtonEvent,
        ),
      ),
    );
  }

  _leftButtonEvent() async {
    var next = Settings.rightToLeft ^ Settings.isHorizontal
        ? _prevPage - 1
        : _prevPage + 1;
    if (next < 1 || next > _pageInfo.uris.length) return;
    if (!Settings.isHorizontal) {
      if (!Settings.animation) {
        _itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(microseconds: 1),
          alignment: 0.12,
        );
      } else {
        _sliderOnChange = true;
        await _itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
        Future.delayed(Duration(milliseconds: 300)).then((value) {
          _sliderOnChange = false;
        });
      }
    } else {
      if (!Settings.animation) {
        _pageController.jumpToPage(next - 1);
      } else {
        _pageController.animateToPage(
          next - 1,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
    _currentPage = next;
    _prevPage = next;
    _vPrevPage.value = next;
  }

  _touchAreaRight() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        color: null,
        width: width / 3,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _rightButtonEvent,
        ),
      ),
    );
  }

  _rightButtonEvent() async {
    var next = Settings.rightToLeft ^ Settings.isHorizontal
        ? _prevPage + 1
        : _prevPage - 1;
    if (next < 1 || next > _pageInfo.uris.length) return;
    if (!Settings.isHorizontal) {
      if (!Settings.animation) {
        _itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(microseconds: 1),
          alignment: 0.12,
        );
      } else {
        _sliderOnChange = true;
        await _itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
        Future.delayed(Duration(milliseconds: 300)).then((value) {
          _sliderOnChange = false;
        });
      }
    } else {
      if (!Settings.animation) {
        _pageController.jumpToPage(next - 1);
      } else {
        _pageController.animateToPage(
          next - 1,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
    _currentPage = next;
    _prevPage = next;
    _vPrevPage.value = next;
  }

  _networkImageItem(index) {
    final width =
        MediaQuery.of(context).size.width - (Settings.padding ? 8 : 0);
    if (_height == null) {
      _height = List<double>.filled(_pageInfo.uris.length, 0);
      _keys = List<GlobalKey>.generate(
          _pageInfo.uris.length, (index) => GlobalKey());
    }
    return FutureBuilder(
      // to avoid loading all images when fast scrolling
      future: Future.delayed(Duration(milliseconds: 300)).then((value) => 1),
      builder: (context, snapshot) {
        // To prevent the scroll from being chewed,
        // it is necessary to put an empty box for the invisible part.
        if (!snapshot.hasData && _height![index] == 0) {
          return SizedBox(
            height: 300,
            child: Center(
              child: SizedBox(
                child: CircularProgressIndicator(),
                width: 30,
                height: 30,
              ),
            ),
          );
        }

        return Container(
          constraints: BoxConstraints(
              minHeight: _height![index] != 0 ? _height![index] : 300),
          child: VCachedNetworkImage(
            key: _keys![index],
            imageUrl: _pageInfo.uris[index],
            httpHeaders: _pageInfo.headers,
            fit: BoxFit.cover,
            fadeInDuration: Duration(microseconds: 500),
            fadeInCurve: Curves.easeIn,
            imageBuilder: (context, imageProvider, child) {
              if (_height![index] == 0 || _height![index] == 300) {
                try {
                  final RenderBox renderBoxRed = _keys![index]
                      .currentContext!
                      .findRenderObject()! as RenderBox;
                  final sizeRender = renderBoxRed.size;
                  if (sizeRender.height != 300)
                    _height![index] = width / sizeRender.aspectRatio;
                  _isImageLoaded[index] = true;
                } catch (_) {}
              }
              return child;
            },
            progressIndicatorBuilder: (context, string, progress) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: SizedBox(
                    child: CircularProgressIndicator(value: progress.progress),
                    width: 30,
                    height: 30,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  _storageImageItem(index) {
    if (_height == null) {
      _height = List<double>.filled(_pageInfo.uris.length, 0);
    }

    Future<dynamic> future;

    if (_height![index] == 0)
      future = Future.delayed(Duration(milliseconds: 300));
    else
      future = Future.value(0);

    return FutureBuilder(
      // to avoid loading all images when fast scrolling
      future: future.then((value) async {
        return 0;
      }),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _FileImage(
            path: _pageInfo.uris[index],
            cachedHeight: _height![index] != 0 ? _height![index] : null,
            heightCallback: _height![index] != 0
                ? null
                : (height) async {
                    _height![index] = height;
                  },
          );
        }

        return SizedBox(
          height: _height![index] != 0 ? _height![index] : 300,
          child: Center(
            child: SizedBox(
              child: CircularProgressIndicator(),
              width: 30,
              height: 30,
            ),
          ),
        );
      },
    );
  }

  // Future<Size> _calculateImageDimension(String uri) async {
  //   Completer<Size> completer = Completer();
  //   Image image = Image.file(File(uri));
  //   image.image.resolve(ImageConfiguration()).addListener(
  //     ImageStreamListener(
  //       (ImageInfo image, bool synchronousCall) {
  //         var myImage = image.image;
  //         Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
  //         if (!completer.isCompleted) completer.complete(size);
  //       },
  //     ),
  //   );
  //   return completer.future;
  // }

  /*
  Future<Size> _calculateNetworkImageDimension(String uri) async {
    Completer<Size> completer = Completer();
    Image image = Image(
        image: OptimizedCacheImageProvider(uri, headers: _pageInfo.headers));
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }
   */

  _providerImageItem(index) {
    if (_headerCache == null) {
      _headerCache =
          List<Map<String, String>?>.filled(_pageInfo.uris.length, null);
      _urlCache = List<String?>.filled(_pageInfo.uris.length, null);
    }

    final width = MediaQuery.of(context).size.width;
    if (_height == null) {
      _height = List<double>.filled(_pageInfo.uris.length, 0);
      _keys = List<GlobalKey>.generate(
          _pageInfo.uris.length, (index) => GlobalKey());
    }

    if (_estimatedImageHeight == null) {
      _estimatedImageHeight = List<double>.filled(_pageInfo.uris.length, 0);
      _loadingEstimaed = List<bool>.filled(_pageInfo.uris.length, false);
    }

    if (_loadingEstimaed![index] == false) {
      _loadingEstimaed![index] = true;
      Future.delayed(Duration(milliseconds: 1)).then((value) async {
        if (_isSessionOutdated) return;
        final h =
            await _pageInfo.provider!.getEstimatedImageHeight(index, width);
        if (h > 0) {
          setState(() {
            _estimatedImageHeight![index] = h;
          });
        }
      });
    }

    Future<dynamic> future;

    if (_height![index] == 0)
      future = Future.delayed(Duration(milliseconds: 300));
    else
      future = Future.value(0);

    return FutureBuilder(
      // to avoid loading all images when fast scrolling
      future: future.then((value) => 1),
      builder: (context, snapshot) {
        // To prevent the scroll from being chewed,
        // it is necessary to put an empty box for the invisible part.
        if (!snapshot.hasData && _height![index] == 0) {
          return SizedBox(
            height: _estimatedImageHeight![index] != 0
                ? _estimatedImageHeight![index]
                : 300,
            child: Center(
              child: SizedBox(
                child: CircularProgressIndicator(),
                width: 30,
                height: 30,
              ),
            ),
          );
        }

        return FutureBuilder(
          future: Future.value(1).then((value) async {
            if (_headerCache![index] == null) {
              var header = await _pageInfo.provider!.getHeader(index);
              _headerCache![index] = header;
            }

            if (_urlCache![index] == null) {
              var url = await _pageInfo.provider!.getImageUrl(index);
              _urlCache![index] = url;
            }

            return 1;
          }),
          builder: (context, snapshot) {
            if (_urlCache![index] == null || _headerCache![index] == null) {
              return SizedBox(
                height: _estimatedImageHeight![index] != 0
                    ? _estimatedImageHeight![index]
                    : 300,
                child: Center(
                  child: SizedBox(
                    child: CircularProgressIndicator(),
                    width: 30,
                    height: 30,
                  ),
                ),
              );
            }
            return Container(
              // height: _height[index] != 0 ? _height[index] : null,
              constraints: _height![index] != 0
                  ? BoxConstraints(minHeight: _height![index])
                  : _estimatedImageHeight![index] != 0
                      ? BoxConstraints(minHeight: _estimatedImageHeight![index])
                      : null,
              child: VCachedNetworkImage(
                key: _keys![index],
                imageUrl: _urlCache![index]!,
                httpHeaders: _headerCache![index],
                fit: BoxFit.cover,
                fadeInDuration: Duration(microseconds: 500),
                fadeInCurve: Curves.easeIn,
                filterQuality: SettingsWrapper.imageQuality,
                imageBuilder: (context, imageProvider, child) {
                  if (_height![index] == 0 || _height![index] == 300) {
                    Future.delayed(Duration(milliseconds: 50)).then((value) {
                      try {
                        final RenderBox renderBoxRed = _keys![index]
                            .currentContext!
                            .findRenderObject() as RenderBox;
                        final sizeRender = renderBoxRed.size;
                        if (sizeRender.height != 300) {
                          _height![index] =
                              (width / sizeRender.aspectRatio - 1.5)
                                  .floor()
                                  .toDouble();
                        }

                        _isImageLoaded[index] = true;

                        if (_latestIndex >= index && !_onScroll)
                          _patchHeightForDynamicLoadedImage();
                      } catch (_) {}
                    });
                  }
                  return child;
                },
                progressIndicatorBuilder: (context, string, progress) {
                  return SizedBox(
                    height: _estimatedImageHeight![index] != 0
                        ? _estimatedImageHeight![index]
                        : 300,
                    child: Center(
                      child: SizedBox(
                        child:
                            CircularProgressIndicator(value: progress.progress),
                        width: 30,
                        height: 30,
                      ),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  Logger.error(
                      '[Viewer] E: image load failed\n' + error.toString());
                  Future.delayed(Duration(milliseconds: 500))
                      .then((value) => setState(() {
                            _keys![index] = GlobalKey();
                          }));
                  return SizedBox(
                    height: _estimatedImageHeight![index] != 0
                        ? _estimatedImageHeight![index]
                        : 300,
                    child: Center(
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: Settings.majorColor,
                          ),
                          onPressed: () => setState(() {
                            _keys![index] = GlobalKey();
                          }),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// This function is used for [_patchHeightForDynamicLoadedImage].
  /// The height of the widget with the initial image is set to 300,
  /// and when the image is loaded, the height is reset based on the
  /// aspect ratio of the image, which automatically adjusts the page
  /// currently being viewed by the user. This is a problem caused
  /// by the minCacheExtent of the listview, and we could not reduce
  /// the minCacheExtent to solve this problem.
  _getLatestHeight() {
    var v = _itemPositionsListener.itemPositions.value.toList();
    int? selected;
    ItemPosition? selectede;

    v.sort((x, y) => y.itemLeadingEdge.compareTo(x.itemLeadingEdge));

    for (var e in v) {
      if (e.itemLeadingEdge >= 0.0) {
        selected = e.index;
        selectede = e;
      } else {
        break;
      }
    }

    _latestIndex = selected ?? 0;
    _latestAlign = selectede?.itemLeadingEdge ?? 0;
  }

  _patchHeightForDynamicLoadedImage() {
    if (_sliderOnChange) return;
    _itemScrollController.scrollTo(
      index: _latestIndex,
      duration: Duration(microseconds: 1),
      alignment: _latestAlign,
    );
  }

  _bottomAppBar() {
    final width = MediaQuery.of(context).size.width;
    final statusBarHeight =
        Settings.disableFullScreen ? MediaQuery.of(context).padding.top : 0;
    final height = MediaQuery.of(context).size.height;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Duration(milliseconds: 300),
      child: Stack(
        children: [
          !Settings.disableFullScreen && !Settings.moveToAppBarToBottom
              ? Padding(
                  padding: EdgeInsets.only(top: statusBarHeight.toDouble()),
                  child: Container(
                    height: Variables.statusBarHeight,
                    color: Colors.black,
                  ),
                )
              : Container(),
          AnimatedPadding(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.only(
                top: height -
                    Variables.bottomBarHeight -
                    (48) -
                    (Platform.isIOS ? 48 - 24 : 0) -
                    (_isThumbMode ? _thumbHeight : 0) -
                    statusBarHeight -
                    (Settings.moveToAppBarToBottom ? 48 : 0)),
            curve: Curves.easeInOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              alignment: Alignment.bottomCenter,
              height: Variables.bottomBarHeight +
                  (Platform.isIOS ? 48 : 0) +
                  (_isThumbMode ? _thumbHeight : 0) +
                  (!Settings.moveToAppBarToBottom ? 48 : 0),
              curve: Curves.easeInOut,
              child: Material(
                color: Colors.black.withOpacity(0.8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_pageInfo.useFileSystem)
                      AnimatedOpacity(
                        opacity: _isThumbMode ? 1.0 : 0,
                        duration: Duration(milliseconds: 300),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: _isThumbMode ? _thumbHeight : 0,
                          child: _thumbArea(),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_pageInfo.useFileSystem)
                          IconButton(
                            color: Colors.white,
                            icon: Icon(Icons.keyboard_arrow_up),
                            onPressed: () async {
                              _isThumbMode = !_isThumbMode;
                              if (_isThumbMode)
                                Future.delayed(Duration(milliseconds: 10)).then(
                                    (value) => _thumbAnimateTo(_prevPage - 1));
                              await Settings.setEnableThumbSlider(_isThumbMode);
                              setState(() {});
                            },
                          ),
                        SizedBox(
                          width: 30.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ValueListenableBuilder(
                                  valueListenable: _vPrevPage,
                                  builder: (BuildContext context, int value,
                                      Widget? child) {
                                    return Text('$value',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16.0));
                                  }),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            // width: 200,
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: Colors.blue,
                                inactiveTrackColor: Color(0xffd0d2d3),
                                trackHeight: 3,
                                thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: 6.0),
                                // thumbShape: SliderThumbShape(),
                              ),
                              child: ValueListenableBuilder(
                                valueListenable: _vPrevPage,
                                builder: (BuildContext context, int value,
                                    Widget? child) {
                                  return Slider(
                                    value: value.toDouble() > 0
                                        ? value <= _pageInfo.uris.length
                                            ? value.toDouble()
                                            : _pageInfo.uris.length.toDouble()
                                        : 1,
                                    max: _pageInfo.uris.length.toDouble(),
                                    min: 1,
                                    label: value.toString(),
                                    divisions: _pageInfo.uris.length,
                                    inactiveColor:
                                        Settings.majorColor.withOpacity(0.7),
                                    activeColor: Settings.majorColor,
                                    onChangeStart: (value) {
                                      _sliderOnChange = true;
                                    },
                                    onChangeEnd: (value) {
                                      Future.delayed(
                                              Duration(milliseconds: 300))
                                          .then((value) {
                                        _sliderOnChange = false;
                                      });
                                      if (!Settings.isHorizontal &&
                                          _pageInfo.useFileSystem)
                                        _itemScrollController.scrollTo(
                                          index: value.toInt() - 1,
                                          duration: Duration(microseconds: 1),
                                          alignment: 0.12,
                                        );
                                    },
                                    onChanged: (value) {
                                      if (!Settings.isHorizontal) {
                                        if (!_pageInfo.useFileSystem)
                                          _itemScrollController.jumpTo(
                                            index: value.toInt() - 1,
                                            alignment: 0.12,
                                          );
                                      } else {
                                        _pageController
                                            .jumpToPage(value.toInt() - 1);
                                      }

                                      _thumbJumpTo(value.toInt() - 1);

                                      _currentPage = value.toInt();
                                      _prevPage = value.toInt();
                                      _vPrevPage.value = value.toInt();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Text('${_pageInfo.uris.length}',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 15.0)),
                        Container(
                          width: 16.0,
                        )
                      ],
                    ),
                    if (!Platform.isIOS &&
                        !Settings.disableFullScreen &&
                        !Settings.moveToAppBarToBottom)
                      Container(
                        height: Variables.bottomBarHeight,
                        color: Colors.black,
                      )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _thumbArea() {
    final width = MediaQuery.of(context).size.width;
    return ListView.builder(
      controller: _thumbController,
      scrollDirection: Axis.horizontal,
      itemCount: _pageInfo.uris.length,
      physics: BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.only(top: 4.0, left: 2.0, right: 2.0),
          width: _thumbImageWidth[index],
          child: GestureDetector(
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: Image.file(
                      File(_pageInfo.uris[index]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      isAntiAlias: true,
                      // cacheWidth: ((_thumbHeight - 14.0) / 4 * 3 * 2).toInt(),
                      cacheHeight: (_thumbHeight * 2.0).toInt(),
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Container(height: 2.0),
                Text((index + 1).toString(),
                    style: TextStyle(color: Colors.white, fontSize: 12.0)),
              ],
            ),
            onTap: () {
              if (!Settings.isHorizontal) {
                _itemScrollController.scrollTo(
                  index: index,
                  duration: Duration(microseconds: 1),
                  alignment: 0.12,
                );
              } else {
                _pageController.jumpToPage(index);
              }

              final jumpOffset = _thumbImageStartPos[index] -
                  width / 2 +
                  _thumbImageWidth[index] / 2;
              _thumbController.animateTo(
                jumpOffset > 0 ? jumpOffset : 0,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );

              _currentPage = index;
              _prevPage = index;
              _vPrevPage.value = index;
            },
          ),
        );
      },
    );
  }

  _verticalPageLabel() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.all(8),
      child: ValueListenableBuilder(
        valueListenable: _vPrevPage,
        builder: (BuildContext context, int value, Widget? child) {
          return Stack(
            children: [
              Text(
                '$value/${_pageInfo.uris.length}',
                style: TextStyle(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = Colors.black,
                ),
              ),
              Text(
                '$value/${_pageInfo.uris.length}',
                style: TextStyle(
                  color: Colors.grey.shade300,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Raises an event when two or more fingers touch the screen.
class _DoublePointListener extends StatefulWidget {
  final Widget child;
  final BoolCallback onStateChanged;

  _DoublePointListener({
    required this.child,
    required this.onStateChanged,
  });

  @override
  State<_DoublePointListener> createState() => __DoublePointListener();
}

class __DoublePointListener extends State<_DoublePointListener> {
  /// How many fingers are on the screen?
  int _mpPoints = 0;

  ///
  bool _onStateChanged = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _mpPoints++;
        if (_mpPoints >= 2) {
          if (_onStateChanged) {
            _onStateChanged = false;
            widget.onStateChanged(false);
          }
        }
      },
      onPointerUp: (event) {
        _mpPoints--;
        if (_mpPoints < 1) {
          _onStateChanged = true;
          widget.onStateChanged(true);
        }
      },
      child: widget.child,
    );
  }
}

/// GestureDetector uses a delay to distinguish between tap events
/// and double taps. By default, this delay cannot be modified, so
/// I created a separate class.
class _CustomDoubleTapGestureDectector extends StatefulWidget {
  final GestureTapDownCallback onTap;
  final GestureTapDownCallback onDoubleTap;
  final Duration doubleTapMaxDelay;

  _CustomDoubleTapGestureDectector({
    required this.onTap,
    required this.onDoubleTap,
    this.doubleTapMaxDelay = const Duration(milliseconds: 200),
  });

  @override
  State<_CustomDoubleTapGestureDectector> createState() =>
      __CustomDoubleTapGestureDectectorState();
}

class __CustomDoubleTapGestureDectectorState
    extends State<_CustomDoubleTapGestureDectector> {
  /// these are used for double tap check
  Timer? _doubleTapCheckTimer;
  bool _isPressed = false;
  bool _isDoubleTap = false;
  bool _isSingleTap = false;

  /// this is used for onTap, onDoubleTap event
  late TapDownDetails _onTapDetails;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      onTapDown: (TapDownDetails details) {
        _onTapDetails = details;

        _isPressed = true;
        if (_doubleTapCheckTimer != null && _doubleTapCheckTimer!.isActive) {
          _isDoubleTap = true;
          _doubleTapCheckTimer!.cancel();
        } else {
          _doubleTapCheckTimer =
              Timer(widget.doubleTapMaxDelay, _doubleTapTimerElapsed);
        }
      },
      onTapCancel: () {
        _isPressed = _isSingleTap = _isDoubleTap = false;
        if (_doubleTapCheckTimer != null && _doubleTapCheckTimer!.isActive) {
          _doubleTapCheckTimer!.cancel();
        }
      },
    );
  }

  void _doubleTapTimerElapsed() {
    if (_isPressed) {
      _isSingleTap = true;
    } else {
      widget.onTap(_onTapDetails);
    }
  }

  void _handleTap() {
    _isPressed = false;
    if (_isSingleTap) {
      _isSingleTap = false;
      widget.onTap(_onTapDetails);
    }
    if (_isDoubleTap) {
      _isDoubleTap = false;
      widget.onDoubleTap(_onTapDetails);
    }
  }
}

class _FileImage extends StatefulWidget {
  final String path;
  final double? cachedHeight;
  final DoubleCallback? heightCallback;

  const _FileImage(
      {required this.path, this.heightCallback, this.cachedHeight});

  @override
  __FileImageState createState() => __FileImageState();
}

class __FileImageState extends State<_FileImage> {
  late double _height;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    if (widget.cachedHeight != null && widget.cachedHeight! > 0)
      _height = widget.cachedHeight!;
    else
      _height = 300;
  }

  @override
  void dispose() {
    clearMemoryImageCache(widget.path);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final image = ExtendedImage.file(
      File(widget.path),
      fit: BoxFit.contain,
      imageCacheName: widget.path,
      filterQuality: SettingsWrapper.imageQuality,
      loadStateChanged: (ExtendedImageState state) {
        if (widget.cachedHeight != null && widget.cachedHeight! > 0)
          return state.completedWidget;

        final ImageInfo? imageInfo = state.extendedImageInfo;
        if ((state.extendedImageLoadState == LoadState.completed ||
                imageInfo != null) &&
            !_loaded) {
          _loaded = true;
          Future.delayed(Duration(milliseconds: 100)).then((value) {
            final aspectRatio = imageInfo!.image.width / imageInfo.image.height;
            if (widget.heightCallback != null)
              widget.heightCallback!(width / aspectRatio);
            setState(() {
              _height = width / aspectRatio;
            });
          });
        } else if (state.extendedImageLoadState == LoadState.loading) {
          return SizedBox(
            height: _height,
            child: Center(
              child: SizedBox(
                child: CircularProgressIndicator(),
                width: 30,
                height: 30,
              ),
            ),
          );
        }

        return state.completedWidget;
      },
    );

    return AnimatedContainer(
      alignment: Alignment.center,
      height: _height,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: image,
    );
  }
}
