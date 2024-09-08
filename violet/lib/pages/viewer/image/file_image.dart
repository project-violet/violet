// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as ui;
import 'package:get/get.dart';
import 'package:image_crop/image_crop.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/viewer/vertical_viewer_page.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';

class FileImage extends StatefulWidget {
  final String getxId;
  final String path;
  final double? cachedHeight;
  final DoubleCallback? heightCallback;
  final int index;

  const FileImage({
    super.key,
    required this.getxId,
    required this.path,
    this.heightCallback,
    this.cachedHeight,
    required this.index,
  });

  @override
  State<FileImage> createState() => _FileImageState();
}

class _FileImageState extends State<FileImage> {
  late final ViewerController c;
  late double _height;
  bool _loaded = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    c = Get.find(tag: widget.getxId);

    if (widget.cachedHeight != null && widget.cachedHeight! > 0) {
      _height = widget.cachedHeight!;
    } else {
      _height = 300;
    }
  }

  @override
  void dispose() {
    clearMemoryImageCache(widget.path);
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = ExtendedImage.file(
      File(widget.path),
      fit: BoxFit.contain,
      imageCacheName: widget.path,
      filterQuality: SettingsWrapper.getImageQuality(c.imgQuality.value),
      cacheWidth: Settings.useLowPerf
          ? (MediaQuery.of(context).size.width * 2.0).toInt()
          : null,
      enableMemoryCache: false,
      clearMemoryCacheWhenDispose: true,
      loadStateChanged: _loadStateChanged,
    );

    return AnimatedContainer(
      alignment: Alignment.center,
      height: _height,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: GestureDetector(
        child: image,
        onLongPress: () {
          PlatformNavigator.navigateSlide(
            context,
            ImageCropBookmark(
              url: widget.path,
              articleId: c.articleId,
              page: widget.index,
            ),
          );
        },
      ),
    );
  }

  Widget _loadStateChanged(ExtendedImageState state) {
    if (widget.cachedHeight != null && widget.cachedHeight! > 0) {
      return state.completedWidget;
    }

    final ImageInfo? imageInfo = state.extendedImageInfo;
    if (imageInfo != null && !_loaded) {
      _loaded = true;
      _setHeight(imageInfo);
    }

    if (state.extendedImageLoadState == LoadState.loading) {
      return SizedBox(
        height: _height,
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return state.completedWidget;
  }

  _setHeight(ImageInfo imageInfo) {
    Future.delayed(const Duration(milliseconds: 100)).then((value) {
      if (_disposed) return;

      final width = MediaQuery.of(context).size.width;

      final aspectRatio = imageInfo.image.width / imageInfo.image.height;
      if (widget.heightCallback != null) {
        widget.heightCallback!(width / aspectRatio);
      }

      setState(() {
        _height = width / aspectRatio;
      });
    });
  }
}

class ImageCropBookmark extends StatelessWidget {
  final GlobalKey<CropState> cropKey = GlobalKey<CropState>();
  final String url;
  final int articleId;
  final int page;
  late final double aspectRatio;

  ImageCropBookmark({
    super.key,
    required this.url,
    required this.articleId,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(20.0),
            child: Crop(
              image: ui.FileImage(File(url))
                ..resolve(ImageConfiguration.empty)
                    .addListener(ImageStreamListener((imageInfo, _) {
                  aspectRatio = imageInfo.image.width / imageInfo.image.height;
                })),
              key: cropKey,
            ),
          ),
        ),
        TextButton(
          child: const Text(
            'Bookmark Image',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () => bookmarkImage(context),
        ),
        SizedBox.fromSize(size: const Size.fromHeight(24.0))
      ],
    );
  }

  Future<void> bookmarkImage(BuildContext context) async {
    final area = cropKey.currentState!.area;
    if (area == null) {
      // cannot crop, widget is not setup
      return;
    }

    await (await Bookmark.getInstance()).insertCropImage(articleId, page,
        '${area.left},${area.top},${area.right},${area.bottom}', aspectRatio);

    showToast(
      level: ToastLevel.check,
      message:
          '$articleId(${page}p): [${area.toString().split('(')[1].split(')')[0]}] Saved!',
    );

    if (!context.mounted) return;
    Navigator.pop(context);
  }
}
