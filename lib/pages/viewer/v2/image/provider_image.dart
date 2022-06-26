// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:violet/pages/viewer/v_cached_network_image.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';

typedef VImageWidgetBuilder = Widget Function(
    BuildContext context, ImageProvider imageProvider, Widget child);

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
  final GlobalKey imgKey;
  final String imgUrl;
  final Map<String, String>? imgHeader;
  final VImageWidgetBuilder imageWidgetBuilder;
  final VProgressIndicatorBuilder progressIndicatorBuilder;
  final VLoadingErrorWidgetBuilder loadingErrorWidgetBuilder;

  const ProviderImage({
    Key? key,
    required this.imgKey,
    required this.imgUrl,
    required this.imgHeader,
    required this.imageWidgetBuilder,
    required this.progressIndicatorBuilder,
    required this.loadingErrorWidgetBuilder,
  }) : super(key: key);

  @override
  State<ProviderImage> createState() => _ProviderImageState();
}

class _ProviderImageState extends State<ProviderImage> {
  @override
  void dispose() {
    CachedNetworkImage.evictFromCache(widget.imgUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VCachedNetworkImage(
      key: widget.imgKey,
      imageUrl: widget.imgUrl,
      httpHeaders: widget.imgHeader,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(microseconds: 500),
      fadeInCurve: Curves.easeIn,
      filterQuality: SettingsWrapper.imageQuality,
      imageBuilder: widget.imageWidgetBuilder,
      progressIndicatorBuilder: widget.progressIndicatorBuilder,
      errorWidget: widget.loadingErrorWidgetBuilder,
      memCacheWidth: Settings.useLowPerf
          ? (MediaQuery.of(context).size.width * 1.5).toInt()
          : null,
    );
  }
}
