// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/vertical_viewer_page.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';

class FileImage extends StatefulWidget {
  final String getxId;
  final String path;
  final double? cachedHeight;
  final DoubleCallback? heightCallback;

  const FileImage({
    super.key,
    required this.getxId,
    required this.path,
    this.heightCallback,
    this.cachedHeight,
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
      child: image,
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
