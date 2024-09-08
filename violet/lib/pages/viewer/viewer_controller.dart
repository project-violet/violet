// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/pages/viewer/others/preload_page_view.dart';
import 'package:violet/pages/viewer/others/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

enum ViewType {
  vertical,
  horizontal,
}

class ViewerController extends GetxController {
  /// viewer target options
  final ViewerPageProvider provider;
  late final int articleId;
  late final int maxPage;
  var onTwoPage = false.obs;
  var secondPageToSecondPage = Settings.secondPageToSecondPage.obs;

  /// this variable used in [_appBarTwoPage] and [_HorizontalViewerPageState]
  /// if true, then lock the [_onPageChanged] method on [_HorizontalViewerPageState]
  var onTwoPageJump = false;

  /// viewer callbacks
  late AsyncCallback close;
  late Function replace;
  late Function stopTimer;
  late Function startTimer;

  /// common viewer options
  var page = 0.obs;
  var viewType =
      Settings.isHorizontal ? ViewType.horizontal.obs : ViewType.vertical.obs;
  var animation = Settings.animation.obs;
  var rightToLeft = Settings.rightToLeft.obs;
  var imgQuality = Settings.imageQuality.obs;
  var fullscreen = (!Settings.disableFullScreen).obs;

  /// horizontal viewer option
  var viewScrollType =
      Settings.scrollVertical ? ViewType.vertical.obs : ViewType.horizontal.obs;

  /// vertical viewer options
  var padding = Settings.padding.obs;

  /// overlay options
  var leftRightButton = (!Settings.disableOverlayButton).obs;
  var appBarToBottom = Settings.moveToAppBarToBottom.obs;
  var showSlider = Settings.showSlider.obs;
  var indicator = Settings.showPageNumberIndicator.obs;
  late RxBool thumb;
  var thumbSize = Settings.thumbSize.obs;
  var search = false.obs;
  var bookmark = false.obs;

  /// timer options
  var timer = false.obs;
  var timerTick = Settings.timerTick.obs;

  /// internal options
  var onSession = true.obs;
  var isStaring = true;
  var sliderOnChange = false;

  /// these are used on overlay
  var overlay = false.obs;
  var overlayButton = (!Settings.disableOverlayButton).obs;
  var opacity = 0.0.obs;

  /// scroll controllers
  /// instances declared with var can be replaced by the
  /// corresponding library implementation restrictions.
  final verticalItemScrollController = ItemScrollController();
  var horizontalPageController = PreloadPageController();
  var thumbController = ScrollController();
  final searchText = TextEditingController(text: '');
  SuggestionsBoxController? suggestionsBoxController;

  /// Is enabled search?
  var messages = <Tuple5<double, int, int, double, List<double>>>[];
  String latestSearch = '';
  var messageIndex = 0.obs;

  /// image infos
  late RxList<bool> isImageLoaded;
  late List<RxString?> urlCache;
  late List<Map<String, String>?> headerCache;
  late List<double> imgHeight;
  late List<double> estimatedImgHeight;
  late List<double> realImgHeight;
  late List<double> realImgWidth;
  late List<GlobalKey> imgKeys;
  late List<bool> loadingEstimaed;

  /// this variable used in [vertical_viewer_page]
  /// this will be consumed on [_itemPositionsListener]
  bool onJump = false;

  ViewerController(
    BuildContext context,
    this.provider, {
    required this.close,
    required this.replace,
    required this.stopTimer,
    required this.startTimer,
  }) {
    articleId = provider.id;
    maxPage = provider.uris.length;
    thumb = provider.useFileSystem.obs;
    isImageLoaded =
        List.filled(provider.uris.length, provider.useFileSystem).obs;

    onTwoPage = (!Settings.disableTwoPageView &&
            MediaQuery.of(context).orientation == Orientation.landscape)
        .obs;

    headerCache = List<Map<String, String>?>.filled(maxPage, null);
    urlCache = List<RxString?>.filled(maxPage, null);
    imgHeight = List<double>.filled(maxPage, 0);
    estimatedImgHeight = List<double>.filled(maxPage, 0);
    realImgHeight = List<double>.filled(maxPage, 0);
    realImgHeight = List<double>.filled(maxPage, 0);
    imgKeys =
        List<GlobalKey>.generate(provider.uris.length, (index) => GlobalKey());
    loadingEstimaed = List<bool>.filled(maxPage, false);
  }

  jump(int page) {
    if (page < 0) return;
    if (page >= maxPage &&
        (!secondPageToSecondPage.value || page >= maxPage + 1)) return;

    this.page.value = page;

    if (viewType.value == ViewType.vertical) {
      verticalItemScrollController.scrollTo(
        index: page,
        duration: const Duration(microseconds: 1),
        alignment: 0.12,
      );
    } else {
      horizontalPageController.jumpToPage(onTwoPage.value ? page ~/ 2 : page);
    }
  }

  move(int page) {
    if (page < 0) return;
    if (page >= maxPage &&
        (!secondPageToSecondPage.value || page >= maxPage + 1)) return;

    if (!animation.value) {
      jump(page);
      return;
    }

    this.page.value = page;

    if (viewType.value == ViewType.vertical) {
      sliderOnChange = true;
      verticalItemScrollController
          .scrollTo(
            index: page,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.12,
          )
          .then(
            (value) => Future.delayed(const Duration(milliseconds: 300)).then(
              (value) {
                sliderOnChange = false;
              },
            ),
          );
    } else {
      horizontalPageController.animateToPage(
        onTwoPage.value ? page ~/ 2 : page,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  prev() => move(page.value - (onTwoPage.value ? 2 : 1));
  next() => move(page.value + (onTwoPage.value ? 2 : 1));

  Future<void> load(int index) async {
    if (provider.useProvider) {
      if (index < 0 || index >= maxPage) {
        return;
      }

      if (headerCache[index] == null) {
        var header = await provider.provider!.getHeader(index);
        headerCache[index] = header;
      }

      if (urlCache[index] == null) {
        var url = await provider.provider!.getImageUrl(index);
        urlCache[index] = RxString(url);
      }
    }
  }

  precache(BuildContext context, int index) async {
    if (index < 0 || maxPage <= index) return;

    await load(index);

    if (!context.mounted) return;
    await precacheImage(
      CachedNetworkImageProvider(
        urlCache[index]!.value,
        headers: headerCache[index],
        maxWidth: Settings.useLowPerf
            ? (MediaQuery.of(context).size.width * 1.5).toInt()
            : null,
      ),
      context,
    );
  }

  middleButton() {
    if (!overlay.value) {
      overlay.value = !overlay.value;
      opacity.value = 1.0;
      if (!Settings.disableFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
          SystemUiOverlay.top,
          SystemUiOverlay.bottom,
        ]);
      }
    } else {
      if (!Settings.disableFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      }
      opacity.value = 0.0;
      Future.delayed(const Duration(milliseconds: 300))
          .then((value) => overlay.value = !overlay.value);
    }
  }

  leftButton() {
    if (rightToLeft.value) {
      prev();
    } else {
      next();
    }
  }

  rightButton() {
    if (rightToLeft.value) {
      next();
    } else {
      prev();
    }
  }

  gotoSearchIndex() {
    final index = messages[messageIndex.value - 1].item3;

    jump(index);
  }

  onModifiedText() async {
    suggestionsBoxController!.close();
    if (latestSearch == searchText.text) return;
    latestSearch == searchText.text;
    messages = <Tuple5<double, int, int, double, List<double>>>[];

    final tmessages =
        (await VioletServer.searchMessageWord(articleId, searchText.text))
            as List<dynamic>;
    messages = tmessages
        .map((e) => Tuple5<double, int, int, double, List<double>>(
            double.parse(e['MatchScore'] as String),
            e['Id'] as int,
            e['Page'] as int,
            double.parse(e['Correctness'].toString()),
            (e['Rect'] as List<dynamic>)
                .map((e) => double.parse(e.toString()))
                .toList()))
        .toList();

    messages = messages.where((e) => e.item1 >= 80.0).toList();
    messages.sort((a, b) => a.item3.compareTo(b.item3));

    messageIndex.value = 1;

    gotoSearchIndex();
  }

  refreshImgUrlWhenRequired() async {
    if (ProviderManager.dirty(articleId)) {
      await ProviderManager.refresh(
          articleId, isImageLoaded.map((element) => !element).toList());
      for (var i = 0; i < isImageLoaded.length; i++) {
        if (!isImageLoaded[i]) {
          if (urlCache[i] == null) {
            urlCache[i] = RxString(await provider.provider!.getImageUrl(i));
          } else {
            urlCache[i]!.value = await provider.provider!.getImageUrl(i);
          }
        }
      }
    }
  }
}
