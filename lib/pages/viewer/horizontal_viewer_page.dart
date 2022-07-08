// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:violet/pages/viewer/others/photo_view_gallery.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings_wrapper.dart';

class HorizontalViewerPage extends StatefulWidget {
  final String getxId;
  const HorizontalViewerPage({
    Key? key,
    required this.getxId,
  }) : super(key: key);

  @override
  State<HorizontalViewerPage> createState() => _HorizontalViewerPageState();
}

class _HorizontalViewerPageState extends State<HorizontalViewerPage> {
  late final ViewerController c;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);
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
              itemCount: c.maxPage,
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
    c.page.value = page;
    if (c.provider.useProvider) {
      if (page.toInt() - 2 >= 0 && c.urlCache[page.toInt() - 2] != null) {
        CachedNetworkImage.evictFromCache(c.urlCache[page.toInt() - 2]!);
      }
      if (page.toInt() + 2 < c.maxPage &&
          c.urlCache[page.toInt() + 2] != null) {
        CachedNetworkImage.evictFromCache(c.urlCache[page.toInt() + 2]!);
      }
      await c.precache(context, page.toInt() - 1);
      await c.precache(context, page.toInt() + 1);
    }
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    if (c.provider.useFileSystem) {
      return PhotoViewGalleryPageOptions(
        imageProvider: FileImage(File(c.provider.uris[index])),
        filterQuality: SettingsWrapper.imageQuality,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    } else if (c.provider.useProvider) {
      return PhotoViewGalleryPageOptions.customChild(
        child: FutureBuilder(
          future: c.load(index),
          builder: (context, snapshot) {
            if (c.urlCache[index] != null && c.headerCache[index] != null) {
              return Obx(
                () => PhotoView(
                  imageProvider: ExtendedNetworkImageProvider(
                    c.urlCache[index]!,
                    headers: c.headerCache[index],
                    cache: true,
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
        ),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    }
    throw Exception('Dead Reaching');
  }
}
