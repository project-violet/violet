// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/others/preload_page_view.dart';
import 'package:violet/pages/viewer/others/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/settings/settings.dart';

enum ViewType {
  vertical,
  horizontal,
}

class ViewerController extends GetxController {
  final ViewerPageProvider provider;
  var page = 0.obs;
  var viewType =
      Settings.isHorizontal ? ViewType.horizontal.obs : ViewType.vertical.obs;
  var viewScrollType =
      Settings.scrollVertical ? ViewType.vertical.obs : ViewType.horizontal.obs;
  var padding = Settings.padding.obs;
  var animation = Settings.animation.obs;
  var rightToLeft = Settings.rightToLeft.obs;
  var leftRightButton = (!Settings.disableOverlayButton).obs;
  var appBarToBottom = Settings.moveToAppBarToBottom.obs;
  var showSlider = Settings.showSlider.obs;
  var indicator = Settings.showPageNumberIndicator.obs;
  var fullscreen = (!Settings.disableFullScreen).obs;
  var imgQuality = Settings.imageQuality.obs;
  late RxBool thumb;
  var thumbSize = Settings.thumbSize.obs;
  var timer = false.obs;
  var timerTick = Settings.timerTick.obs;
  var search = false.obs;
  var onSession = true.obs;
  var bookmark = false.obs;
  var sliderOnChange = false;
  var overlay = false.obs;
  late RxInt articleId;

  final ItemScrollController verticalItemScrollController =
      ItemScrollController();
  final PreloadPageController horizontalPageController =
      PreloadPageController();

  late int maxPage;

  late RxList<bool> isImageLoaded;

  late List<String?> urlCache;
  late List<Map<String, String>?> headerCache;
  late List<double> imgHeight;
  late List<double> estimatedImgHeight;
  late List<double> realImgHeight;
  late List<double> realImgWidth;
  late List<GlobalKey> imgKeys;

  /// this variable used in [vertical_viewer_page]
  /// this will consume on [_itemPositionsListener]
  bool onJump = false;

  ViewerController(this.provider) {
    articleId = provider.id.obs;
    maxPage = provider.uris.length;
    thumb = provider.useFileSystem.obs;
    isImageLoaded =
        List.filled(provider.uris.length, provider.useFileSystem).obs;

    headerCache = List<Map<String, String>?>.filled(maxPage, null);
    urlCache = List<String?>.filled(maxPage, null);
    imgHeight = List<double>.filled(maxPage, 0);
    estimatedImgHeight = List<double>.filled(maxPage, 0);
    realImgHeight = List<double>.filled(maxPage, 0);
    realImgHeight = List<double>.filled(maxPage, 0);
    imgKeys =
        List<GlobalKey>.generate(provider.uris.length, (index) => GlobalKey());
  }

  jump(int page) {
    if (page < 0) return;
    if (page >= maxPage) return;

    this.page.value = page;

    if (viewType.value == ViewType.vertical) {
      verticalItemScrollController.scrollTo(
        index: page,
        duration: const Duration(microseconds: 1),
        alignment: 0.12,
      );
    } else {
      horizontalPageController.jumpToPage(page);
    }
  }

  move(int page) {
    if (page < 0) return;
    if (page >= maxPage) return;

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
        page,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  prev() => move(rightToLeft.value ^ (viewType.value == ViewType.vertical)
      ? page.value - 1
      : page.value + 1);
  next() => move(rightToLeft.value ^ (viewType.value == ViewType.vertical)
      ? page.value + 1
      : page.value - 1);

  // _preprocessImageInfoForFileImage() {
  //   _thumbHeight = [140.0, 120.0, 96.0][Settings.thumbSize];
  //   _isThumbMode = Settings.enableThumbSlider;

  //   var imageSizes = _pageInfo.uris.map((e) {
  //     final image = File(e);
  //     if (!image.existsSync()) return null;
  //     return ImageSizeGetter.ImageSizeGetter.getSize(FileInput(image));
  //   }).toList();

  //   _thumbImageStartPos = List.filled(imageSizes.length + 1, 0);
  //   _thumbImageWidth = List.filled(imageSizes.length, 0);

  //   _originalImageHeight = List.filled(imageSizes.length, 0);

  //   for (var i = 0; i < imageSizes.length; i++) {
  //     final sz = imageSizes[i];

  //     if (sz != null) {
  //       _thumbImageStartPos[i + 1] =
  //           (_thumbHeight - 14.0) * sz.width / sz.height;
  //     } else {
  //       _thumbImageStartPos[i + 1] = (_thumbHeight - 14.0) / 36 * 25;
  //     }

  //     _thumbImageWidth[i] = _thumbImageStartPos[i + 1];
  //     _thumbImageStartPos[i + 1] += _thumbImageStartPos[i];

  //     _originalImageHeight![i] = sz!.height.toDouble();
  //   }
  // }

  load(int index) async {
    if (headerCache[index] == null) {
      var header = await provider.provider!.getHeader(index);
      headerCache[index] = header;
    }

    if (urlCache[index] == null) {
      var url = await provider.provider!.getImageUrl(index);
      urlCache[index] = url;
    }
  }

  precache(BuildContext context, int index) async {
    if (index < 0 || maxPage <= index) return;

    await load(index);
    await precacheImage(
      CachedNetworkImageProvider(
        urlCache[index]!,
        headers: headerCache[index],
        maxWidth: Settings.useLowPerf
            ? (MediaQuery.of(context).size.width * 1.5).toInt()
            : null,
      ),
      context,
    );
  }

  middleButton() {
    overlay.value = !overlay.value;
    if (overlay.value) {
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
    }
  }

  leftButton() {
    prev();
  }

  rightButton() {
    next();
  }
}
