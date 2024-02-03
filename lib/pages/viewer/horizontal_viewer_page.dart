// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/viewer/image/file_image.dart' as f;
import 'package:violet/pages/viewer/image/provider_image.dart' as p;
import 'package:violet/pages/viewer/others/photo_view_gallery.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings_wrapper.dart';

class HorizontalViewerPage extends StatefulWidget {
  final String getxId;
  const HorizontalViewerPage({
    super.key,
    required this.getxId,
  });

  @override
  State<HorizontalViewerPage> createState() => _HorizontalViewerPageState();
}

class _HorizontalViewerPageState extends State<HorizontalViewerPage> {
  late final ViewerController c;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);
    sizes = List.generate(landscapeMaxPage(), (_) => ValueNotifier(Size.zero));
  }

  int landscapeMaxPage() {
    return c.maxPage ~/ 2 + (c.maxPage % 2);
  }

  bool onTwoPageMode() {
    return c.onTwoPage =
        MediaQuery.of(context).orientation == Orientation.landscape;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Obx(
      () => Stack(
        children: [
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
              itemCount: onTwoPageMode() ? landscapeMaxPage() : c.maxPage,
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              scrollDirection: c.viewScrollType.value == ViewType.vertical
                  ? Axis.vertical
                  : Axis.horizontal,
              pageController: c.horizontalPageController,
              reverse: c.rightToLeft.value,
              onPageChanged: _onPageChanged,
            ),
          ),
          if (c.overlayButton.value)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                color: null,
                width: width / 3,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: c.leftButton,
                ),
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: Container(
              color: null,
              width: width / 3,
              height: height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: c.middleButton,
              ),
            ),
          ),
          if (c.overlayButton.value)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                color: null,
                width: width / 3,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: c.rightButton,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onPageChanged(int page) async {
    if (onTwoPageMode()) {
      c.page.value = page * 2;
    } else {
      c.page.value = page;
    }
    if (c.provider.useProvider) {
      if (page.toInt() - 2 >= 0 && c.urlCache[page.toInt() - 2] != null) {
        CachedNetworkImage.evictFromCache(c.urlCache[page.toInt() - 2]!.value);
      }
      if (page.toInt() + 2 < c.maxPage &&
          c.urlCache[page.toInt() + 2] != null) {
        CachedNetworkImage.evictFromCache(c.urlCache[page.toInt() + 2]!.value);
      }
      await c.precache(context, page.toInt() - 1);
      await c.precache(context, page.toInt() + 1);
    }
  }

  late List<ValueNotifier<Size>> sizes;

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    late final Widget viewWidget;
    final height = MediaQuery.of(context).size.height;

    if (c.provider.useFileSystem) {
      if (onTwoPageMode()) {
        var firstIndex = index * 2;
        var secondIndex = index * 2 + 1;

        if (c.rightToLeft.value) {
          firstIndex += 1;
          secondIndex -= 1;
        }

        viewWidget = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (c.maxPage > firstIndex)
              Image(
                image: FileImage(File(c.provider.uris[firstIndex]))
                  ..resolve(ImageConfiguration.empty)
                      .addListener(ImageStreamListener((imageInfo, _) {
                    final width = sizes[firstIndex].value.width +
                        imageInfo.image.width / imageInfo.image.height * height;
                    sizes[firstIndex].value = Size(
                      width,
                      height,
                    );
                  })),
              ),
            if (c.maxPage > secondIndex)
              Image(
                image: FileImage(File(c.provider.uris[secondIndex]))
                  ..resolve(ImageConfiguration.empty)
                      .addListener(ImageStreamListener((imageInfo, _) {
                    final width = sizes[secondIndex].value.width +
                        imageInfo.image.width / imageInfo.image.height * height;
                    sizes[secondIndex].value = Size(
                      width,
                      height,
                    );
                  })),
              ),
          ],
        );
      } else {
        viewWidget = PhotoView(
          imageProvider: FileImage(File(c.provider.uris[index])),
          filterQuality: SettingsWrapper.imageQuality,
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained * 1.0,
          maxScale: PhotoViewComputedScale.contained * 5.0,
          gestureDetectorBehavior: HitTestBehavior.opaque,
        );
      }
    } else if (c.provider.useProvider) {
      viewWidget = FutureBuilder(
        future: c.load(index),
        builder: (context, snapshot) {
          if (c.urlCache[index] != null && c.headerCache[index] != null) {
            if (onTwoPageMode()) {
              var firstIndex = index * 2;
              var secondIndex = index * 2 + 1;

              if (c.rightToLeft.value) {
                firstIndex += 1;
                secondIndex -= 1;
              }

              return Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (c.maxPage > firstIndex)
                      Image(
                        image: ExtendedNetworkImageProvider(
                          c.urlCache[firstIndex]!.value,
                          headers: c.headerCache[firstIndex],
                          cache: true,
                          retries: 10,
                          timeRetry: const Duration(milliseconds: 300),
                        ),
                      ),
                    if (c.maxPage > secondIndex)
                      Image(
                        image: ExtendedNetworkImageProvider(
                          c.urlCache[secondIndex]!.value,
                          headers: c.headerCache[secondIndex],
                          cache: true,
                          retries: 10,
                          timeRetry: const Duration(milliseconds: 300),
                        ),
                      ),
                  ],
                ),
              );
            } else {
              return Obx(
                () => PhotoView(
                  imageProvider: ExtendedNetworkImageProvider(
                    c.urlCache[index]!.value,
                    headers: c.headerCache[index],
                    cache: true,
                    retries: 10,
                    timeRetry: const Duration(milliseconds: 300),
                  ),
                  filterQuality:
                      SettingsWrapper.getImageQuality(c.imgQuality.value),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 1.0,
                  maxScale: PhotoViewComputedScale.contained * 5.0,
                  gestureDetectorBehavior: HitTestBehavior.opaque,
                ),
              );
            }
          }

          return const SizedBox(
            height: 300,
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(),
              ),
            ),
          );
        },
      );
    } else {
      throw Exception('Dead Reaching');
    }

    final gestureDetector = GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: viewWidget,
      onLongPress: () {
        if (c.provider.useFileSystem) {
          PlatformNavigator.navigateSlide(
            context,
            f.ImageCropBookmark(
              url: c.provider.uris[index],
              articleId: c.articleId,
              page: index,
            ),
          );
        } else if (c.provider.useProvider) {
          PlatformNavigator.navigateSlide(
            context,
            p.ImageCropBookmark(
              url: c.provider.uris[index],
              headers: c.headerCache[index],
              articleId: c.articleId,
              page: index,
            ),
          );
        }
      },
    );

    if (onTwoPageMode()) {
      final width = MediaQuery.of(context).size.width;

      // TODO: supports real image size based width for supporting double tap zoom
      return PhotoViewGalleryPageOptions.customChild(
        childSize: Size(width, height),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
        gestureDetectorBehavior: HitTestBehavior.opaque,
        child: gestureDetector,
      );
    } else {
      return PhotoViewGalleryPageOptions.customChild(
        child: gestureDetector,
      );
    }
  }
}
