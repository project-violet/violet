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
    alreadyCalculated = List.filled(c.maxPage, false);
  }

  int landscapeMaxPage() {
    return c.maxPage ~/ 2 + (c.maxPage % 2);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Obx(
      () => Stack(
        children: [
          Visibility.maintain(
            child: OrientationBuilder(builder: (context, orientation) {
              c.jump(c.page.value);
              return const SizedBox.shrink();
            }),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
            constraints: BoxConstraints.expand(
              height: MediaQuery.of(context).size.height,
            ),
            child: ValueListenableBuilder(
              valueListenable: sizeNoti,
              builder: (_, __, ___) {
                return Obx(
                  () => VPhotoViewGallery.builder(
                    scrollPhysics: const AlwaysScrollableScrollPhysics(),
                    builder: _buildItem,
                    itemCount:
                        c.onTwoPage.value ? landscapeMaxPage() : c.maxPage,
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
                );
              },
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
    if (c.onTwoPage.value) {
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
  late List<bool> alreadyCalculated;
  late ValueNotifier<bool> sizeNoti = ValueNotifier(false);

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    late final Widget viewWidget;
    final height = MediaQuery.of(context).size.height;

    Widget wrappingGestureDetector(Widget child, int index) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: child,
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
                url: c.urlCache[index]!.value,
                headers: c.headerCache[index],
                articleId: c.articleId,
                page: index,
              ),
            );
          }
        },
      );
    }

    void sizeNotification(int imageIndex, ImageInfo imageInfo) {
      if (alreadyCalculated[imageIndex]) return;
      alreadyCalculated[imageIndex] = true;
      final width = sizes[index].value.width +
          imageInfo.image.width / imageInfo.image.height * height;
      sizes[index].value = Size(
        width,
        height,
      );

      // TODO: how to optimize this logic?
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => sizeNoti.value = !sizeNoti.value,
      );
    }

    if (c.provider.useFileSystem) {
      if (c.onTwoPage.value) {
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
              wrappingGestureDetector(
                Image(
                  image: ExtendedFileImageProvider(
                    File(c.provider.uris[firstIndex]),
                    imageCacheName: c.provider.uris[firstIndex],
                  )..resolve(ImageConfiguration.empty)
                        .addListener(ImageStreamListener((imageInfo, _) {
                      sizeNotification(firstIndex, imageInfo);
                    })),
                ),
                firstIndex,
              ),
            if (c.maxPage > secondIndex)
              wrappingGestureDetector(
                Image(
                  image: ExtendedFileImageProvider(
                    File(c.provider.uris[secondIndex]),
                    imageCacheName: c.provider.uris[secondIndex],
                  )..resolve(ImageConfiguration.empty)
                        .addListener(ImageStreamListener((imageInfo, _) {
                      sizeNotification(secondIndex, imageInfo);
                    })),
                ),
                secondIndex,
              ),
          ],
        );
      } else {
        viewWidget = PhotoView(
          imageProvider: ExtendedFileImageProvider(
            File(c.provider.uris[index]),
            imageCacheName: c.provider.uris[index],
          ),
          filterQuality: SettingsWrapper.imageQuality,
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained * 1.0,
          maxScale: PhotoViewComputedScale.contained * 5.0,
          gestureDetectorBehavior: HitTestBehavior.opaque,
        );
      }
    } else if (c.provider.useProvider) {
      viewWidget = FutureBuilder(
        future: c.onTwoPage.value
            ? Future.wait([c.load(index * 2), c.load(index * 2 + 1)])
            : c.load(index),
        builder: (context, snapshot) {
          final checkLoad = c.onTwoPage.value
              ? c.urlCache[index * 2] != null &&
                  c.headerCache[index * 2] != null &&
                  (c.maxPage <= index * 2 + 1 ||
                      (c.urlCache[index * 2 + 1] != null &&
                          c.headerCache[index * 2 + 1] != null))
              : c.urlCache[index] != null && c.headerCache[index] != null;

          if (checkLoad) {
            if (c.onTwoPage.value) {
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
                      wrappingGestureDetector(
                        Image(
                          image: ExtendedNetworkImageProvider(
                            c.urlCache[firstIndex]!.value,
                            headers: c.headerCache[firstIndex],
                            cache: true,
                            retries: 10,
                            timeRetry: const Duration(milliseconds: 300),
                          )..resolve(ImageConfiguration.empty).addListener(
                                ImageStreamListener((imageInfo, _) {
                              sizeNotification(firstIndex, imageInfo);
                            })),
                        ),
                        firstIndex,
                      ),
                    if (c.maxPage > secondIndex)
                      wrappingGestureDetector(
                        Image(
                          image: ExtendedNetworkImageProvider(
                            c.urlCache[secondIndex]!.value,
                            headers: c.headerCache[secondIndex],
                            cache: true,
                            retries: 10,
                            timeRetry: const Duration(milliseconds: 300),
                          )..resolve(ImageConfiguration.empty).addListener(
                                ImageStreamListener((imageInfo, _) {
                              sizeNotification(secondIndex, imageInfo);
                            })),
                        ),
                        secondIndex,
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

    if (c.onTwoPage.value) {
      final width = MediaQuery.of(context).size.width;
      final firstIndex = index * 2;
      final secondIndex = index * 2 + 1;
      final size = alreadyCalculated[firstIndex] &&
              (c.maxPage <= secondIndex || alreadyCalculated[secondIndex])
          ? sizes[index].value
          : Size(width, height);

      return PhotoViewGalleryPageOptions.customChild(
        childSize: size,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
        gestureDetectorBehavior: HitTestBehavior.opaque,
        child: viewWidget,
      );
    } else {
      return PhotoViewGalleryPageOptions.customChild(
        child: wrappingGestureDetector(viewWidget, index),
      );
    }
  }
}
