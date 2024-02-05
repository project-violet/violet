// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/viewer/image/file_image.dart' as f;
import 'package:violet/pages/viewer/image/provider_image.dart' as p;
import 'package:violet/pages/viewer/others/photo_view_gallery.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/pages/viewer/widget/tap_litstener.dart';
import 'package:violet/settings/settings.dart';
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
    sizes = List.filled(c.maxPage, Size.zero);
    alreadyCalculated = List.filled(c.maxPage, false);
  }

  int landscapeMaxPage() {
    var maxPage = c.maxPage;
    if (c.secondPageToSecondPage.value) {
      maxPage += 1;
    }
    return maxPage ~/ 2 + (maxPage % 2);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // orientation 변경 감지를 위한 콜백
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // orientation 변경이 아닌 twoPage 설정 변경인 경우에도 트리거됨
      if (c.onTwoPageJump) return;

      final orientation = MediaQuery.of(context).orientation;
      final candidate = (!Settings.disableTwoPageView &&
          orientation == Orientation.landscape);

      // orientation이 변경되고, twoPage 설정이 바뀌는 경우라면 페이지 재설정이 필요함
      if (c.onTwoPage.value != candidate) {
        c.onTwoPage.value = candidate;
        c.onTwoPageJump = true;

        final curPage = c.page.value;
        if (c.onTwoPage.value) {
          c.page.value = curPage ~/ 2 * 2;
          c.horizontalPageController.jumpToPage(curPage ~/ 2);
        } else {
          c.page.value = curPage;
          c.horizontalPageController.jumpToPage(curPage);
        }

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => c.onTwoPageJump = false,
        );
      }
    });
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
                child: Obx(
                  () => CustomDelayTapListener(
                    onTap: c.leftButton,
                    delay: c.onTwoPage.value
                        ? const Duration(milliseconds: 1)
                        : const Duration(milliseconds: 200),
                  ),
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
                child: Obx(
                  () => CustomDelayTapListener(
                    onTap: c.rightButton,
                    delay: c.onTwoPage.value
                        ? const Duration(milliseconds: 1)
                        : const Duration(milliseconds: 200),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onPageChanged(int page) async {
    if (c.onTwoPageJump) return;
    if (c.onTwoPage.value) {
      c.page.value = page * 2;
    } else {
      c.page.value = page;
    }
    if (c.provider.useProvider) {
      if (c.onTwoPage.value) {
        const evict = [-4, -3, 4, 5];
        for (final i in evict) {
          final target = c.page.value + i;

          if (target < 0 || c.maxPage <= target || c.urlCache[target] == null) {
            continue;
          }

          CachedNetworkImage.evictFromCache(c.urlCache[target]!.value);
        }

        const precache = [-2, -1, 2, 3];
        for (final i in precache) {
          final target = c.page.value + i;

          if (target < 0 || c.maxPage <= target || c.urlCache[target] == null) {
            continue;
          }

          await c.precache(context, target);
        }
      } else {
        if (page.toInt() - 2 >= 0 && c.urlCache[page.toInt() - 2] != null) {
          CachedNetworkImage.evictFromCache(
              c.urlCache[page.toInt() - 2]!.value);
        }
        if (page.toInt() + 2 < c.maxPage &&
            c.urlCache[page.toInt() + 2] != null) {
          CachedNetworkImage.evictFromCache(
              c.urlCache[page.toInt() + 2]!.value);
        }
        await c.precache(context, page.toInt() - 1);
        await c.precache(context, page.toInt() + 1);
      }
    }
  }

  late List<Size> sizes;
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
      sizes[imageIndex] = Size(
          imageInfo.image.width.toDouble(), imageInfo.image.height.toDouble());

      // TODO: how to optimize this logic?
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => sizeNoti.value = !sizeNoti.value,
      );
    }

    if (c.provider.useFileSystem) {
      if (c.onTwoPage.value) {
        var firstIndex = index * 2;
        var secondIndex = index * 2 + 1;

        if (c.secondPageToSecondPage.value) {
          firstIndex -= 1;
          secondIndex -= 1;
        }

        if (c.rightToLeft.value) {
          firstIndex += 1;
          secondIndex -= 1;
        }

        viewWidget = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (c.maxPage > firstIndex && firstIndex >= 0)
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
              )
            else if (c.secondPageToSecondPage.value && firstIndex == -1)
              SizedBox(
                width: sizes[0].aspectRatio * height,
                height: sizes[0].height,
              )
            else if (c.maxPage <= firstIndex)
              SizedBox(
                width: sizes.last.aspectRatio * height,
                height: sizes.last.height,
              ),
            if (c.maxPage > secondIndex && secondIndex >= 0)
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
              )
            else if (c.secondPageToSecondPage.value && secondIndex == -1)
              SizedBox(
                width: sizes[0].aspectRatio * height,
                height: sizes[0].height,
              )
            else if (c.maxPage <= secondIndex)
              SizedBox(
                width: sizes.last.aspectRatio * height,
                height: sizes.last.height,
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
      var indexPad = 0;
      if (c.onTwoPage.value && c.secondPageToSecondPage.value) {
        indexPad = 1;
      }

      viewWidget = FutureBuilder(
        future: c.onTwoPage.value
            ? Future.wait([
                c.load(index * 2 - indexPad),
                c.load(index * 2 + 1 - indexPad)
              ])
            : c.load(index),
        builder: (context, snapshot) {
          var twoPageLoaded = true;
          if (c.onTwoPage.value) {
            final firstIndex = index * 2 - indexPad;
            final firstLoaded = (firstIndex < 0 ||
                c.urlCache[firstIndex] != null &&
                    c.headerCache[firstIndex] != null);
            final secondIndex = index * 2 + 1 - indexPad;
            final secondLoaded = c.maxPage <= secondIndex ||
                (c.urlCache[secondIndex] != null &&
                    c.headerCache[secondIndex] != null);

            twoPageLoaded = firstLoaded && secondLoaded;
          }

          final checkLoad = c.onTwoPage.value
              ? twoPageLoaded
              : c.urlCache[index] != null && c.headerCache[index] != null;

          if (checkLoad) {
            if (c.onTwoPage.value) {
              var firstIndex = index * 2;
              var secondIndex = index * 2 + 1;

              if (c.secondPageToSecondPage.value) {
                firstIndex -= 1;
                secondIndex -= 1;
              }

              if (c.rightToLeft.value) {
                firstIndex += 1;
                secondIndex -= 1;
              }

              return Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (c.maxPage > firstIndex && firstIndex >= 0)
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
                      )
                    else if (c.secondPageToSecondPage.value && firstIndex == -1)
                      SizedBox(
                        width: sizes[0].aspectRatio * height,
                        height: sizes[0].height,
                      )
                    else if (c.maxPage <= firstIndex)
                      SizedBox(
                        width: sizes.last.aspectRatio * height,
                        height: sizes.last.height,
                      ),
                    if (c.maxPage > secondIndex && secondIndex >= 0)
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
                      )
                    else if (c.secondPageToSecondPage.value &&
                        secondIndex == -1)
                      SizedBox(
                        width: sizes[0].aspectRatio * height,
                        height: sizes[0].height,
                      )
                    else if (c.maxPage <= secondIndex)
                      SizedBox(
                        width: sizes.last.aspectRatio * height,
                        height: sizes.last.height,
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
      var firstIndex = index * 2;
      var secondIndex = index * 2 + 1;

      var size = Size(width, height);
      var calculatedWidth = 0.0;

      if (c.secondPageToSecondPage.value) {
        firstIndex -= 1;
        secondIndex -= 1;
      }

      if (0 <= firstIndex && alreadyCalculated[firstIndex]) {
        calculatedWidth += sizes[firstIndex].aspectRatio * height;
        if (c.maxPage <= secondIndex) {
          calculatedWidth *= 2;
        }
      }
      if (secondIndex < c.maxPage && alreadyCalculated[secondIndex]) {
        calculatedWidth += sizes[secondIndex].aspectRatio * height;
        if (firstIndex == -1) {
          calculatedWidth *= 2;
        }
      }

      if (calculatedWidth != 0.0) {
        size = Size(calculatedWidth, height);
      }

      return PhotoViewGalleryPageOptions.customChild(
        childSize: size,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
        gestureDetectorBehavior: HitTestBehavior.opaque,
        child: viewWidget,
        scaleStateCycle: (actual) => actual,
      );
    } else {
      return PhotoViewGalleryPageOptions.customChild(
        child: wrappingGestureDetector(viewWidget, index),
      );
    }
  }
}
