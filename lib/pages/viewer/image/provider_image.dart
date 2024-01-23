// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_crop/image_crop.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';
import 'package:violet/widgets/toast.dart';

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
            articleId: c.articleId,
            page: widget.index,
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
  final int articleId;
  final int page;

  ImageCropBookmark({
    super.key,
    required this.url,
    required this.headers,
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
          onPressed: () => bookmarkImage(context),
        ),
        SizedBox.fromSize(size: const Size.fromHeight(24.0))
      ],
    );
  }

  Future<void> bookmarkImage(BuildContext context) async {
    // final scale = cropKey.currentState!.scale;
    final area = cropKey.currentState!.area;
    if (area == null) {
      // cannot crop, widget is not setup
      return;
    }

    await (await Bookmark.getInstance()).insertCropImage(articleId, page,
        '${area.left},${area.top},${area.right},${area.bottom}');

    FToast ftoast = FToast();
    ftoast.init(context);
    ftoast.showToast(
      child: ToastWrapper(
        isCheck: true,
        isWarning: false,
        icon: Icons.check,
        msg:
            '$articleId(${page}p): [${area.toString().split('(')[1].split(')')[0]}] Saved!',
      ),
      ignorePointer: true,
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 4),
    );
  }
}
