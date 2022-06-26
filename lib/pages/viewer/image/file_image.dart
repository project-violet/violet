// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';

import '../vertical_viewer_page.dart';

class FileImage extends StatefulWidget {
  final String getxId;
  final String path;
  final double? cachedHeight;
  final DoubleCallback? heightCallback;

  const FileImage({
    Key? key,
    required this.getxId,
    required this.path,
    this.heightCallback,
    this.cachedHeight,
  }) : super(key: key);

  @override
  State<FileImage> createState() => _FileImageState();
}

class _FileImageState extends State<FileImage> {
  late final ViewerController c;
  late double _height;
  bool _loaded = false;

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
          ? (MediaQuery.of(context).size.width * 1.5).toInt()
          : null,
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
    final width = MediaQuery.of(context).size.width;

    if (widget.cachedHeight != null && widget.cachedHeight! > 0) {
      return state.completedWidget;
    }

    final ImageInfo? imageInfo = state.extendedImageInfo;
    if ((state.extendedImageLoadState == LoadState.completed ||
            imageInfo != null) &&
        !_loaded) {
      _loaded = true;
      Future.delayed(const Duration(milliseconds: 100)).then((value) {
        final aspectRatio = imageInfo!.image.width / imageInfo.image.height;
        if (widget.heightCallback != null) {
          widget.heightCallback!(width / aspectRatio);
        }
        setState(() {
          _height = width / aspectRatio;
        });
      });
    } else if (state.extendedImageLoadState == LoadState.loading) {
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
}
