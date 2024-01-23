// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_crop/image_crop.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';

typedef VImageWidgetBuilder = Widget Function(
    BuildContext context, Widget child);

typedef VProgressIndicatorBuilder = Widget Function(
  BuildContext context,
  String url,
  DownloadProgress progress,
);

typedef VLoadingErrorWidgetBuilder = Widget Function(
  BuildContext context,
  String url,
  dynamic error,
);

class ProviderImage extends StatefulWidget {
  final String getxId;
  final GlobalKey imgKey;
  final String imgUrl;
  final Map<String, String>? imgHeader;
  final VImageWidgetBuilder imageWidgetBuilder;
  final int index;

  const ProviderImage({
    super.key,
    required this.getxId,
    required this.imgKey,
    required this.imgUrl,
    required this.imgHeader,
    required this.imageWidgetBuilder,
    required this.index,
  });

  @override
  State<ProviderImage> createState() => _ProviderImageState();
}

class _ProviderImageState extends State<ProviderImage> {
  late final ViewerController c;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);
  }

  @override
  void dispose() {
    clearMemoryImageCache(widget.imgUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = ExtendedImage.network(
      widget.imgUrl,
      key: widget.imgKey,
      headers: widget.imgHeader,
      retries: 100,
      timeRetry: const Duration(milliseconds: 300),
      fit: BoxFit.cover,
      filterQuality: SettingsWrapper.imageQuality,
      clearMemoryCacheWhenDispose: true,
      handleLoadingProgress: true,
      loadStateChanged: _loadStateChanged,
      cacheHeight: Settings.useLowPerf
          ? (MediaQuery.of(context).size.width * 2.0).toInt()
          : null,
    );

    return GestureDetector(
      child: image,
      onLongPress: () {
        PlatformNavigator.navigateSlide(
          context,
          ImageCropBookmark(
            url: widget.imgUrl,
            headers: widget.imgHeader,
          ),
        );
      },
    );
  }

  Widget _loadStateChanged(ExtendedImageState state) {
    if (state.extendedImageLoadState == LoadState.failed) {
      Logger.error(
          '[viewer-provider_image] URL: ${widget.imgUrl}\nE: ${state.lastException}');
      state.reLoadImage();

      final iconButton = IconButton(
        icon: Icon(
          Icons.refresh,
          color: Settings.majorColor,
        ),
        onPressed: () => setState(() {
          c.imgKeys[widget.index] = GlobalKey();
        }),
      );

      return SizedBox(
        height: c.estimatedImgHeight[widget.index] != 0
            ? c.estimatedImgHeight[widget.index]
            : 300,
        child: Center(
          child: SizedBox(
            width: 50,
            height: 50,
            child: iconButton,
          ),
        ),
      );
    }

    final ImageInfo? imageInfo = state.extendedImageInfo;
    if ((state.extendedImageLoadState == LoadState.completed ||
            imageInfo != null) &&
        !_loaded) {
      _loaded = true;
      c.isImageLoaded[widget.index] = true;
      return widget.imageWidgetBuilder(
        context,
        state.completedWidget,
      );
    } else if (state.extendedImageLoadState == LoadState.loading) {
      return SizedBox(
        height: c.estimatedImgHeight[widget.index] != 0
            ? c.estimatedImgHeight[widget.index]
            : 300,
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: state.loadingProgress == null
                  ? null
                  : state.loadingProgress!.cumulativeBytesLoaded /
                      state.loadingProgress!.expectedTotalBytes!,
            ),
          ),
        ),
      );
    }

    c.isImageLoaded[widget.index] = true;

    return state.completedWidget;
  }
}

class ImageCropBookmark extends StatelessWidget {
  final GlobalKey<CropState> cropKey = GlobalKey<CropState>();
  final String url;
  final Map<String, String>? headers;

  ImageCropBookmark({
    super.key,
    required this.url,
    required this.headers,
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
              key: cropKey,
              image: NetworkImage(url, headers: headers),
              // aspectRatio: 4.0 / 3.0,
            ),
          ),
        ),
        TextButton(
          child: const Text(
            'Bookmark Image',
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () => bookmarkImage(),
        ),
        SizedBox.fromSize(size: const Size.fromHeight(24.0))
      ],
    );
  }

  Future<void> bookmarkImage() async {
    final scale = cropKey.currentState!.scale;
    final area = cropKey.currentState!.area;
    if (area == null) {
      // cannot crop, widget is not setup
      return;
    }

    print(area);

    // scale up to use maximum possible number of pixels
    // this will sample image in higher resolution to make cropped image larger
    // final sample = await ImageCrop.sampleImage(
    //   file: _file,
    //   preferredSize: (2000 / scale).round(),
    // );

    // final file = await ImageCrop.cropImage(
    //   file: sample,
    //   area: area,
    // );

    // sample.delete();

    // _lastCropped?.delete();
    // _lastCropped = file;

    // debugPrint('$file');
  }
}
