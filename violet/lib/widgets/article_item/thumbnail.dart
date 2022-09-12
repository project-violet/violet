// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/log/log.dart';
import 'package:violet/settings/settings.dart';

class ThumbnailWidget extends StatelessWidget {
  final double pad;
  final bool showDetail;
  final String? thumbnail;
  final String thumbnailTag;
  final int imageCount;
  final ValueNotifier<bool> isBookmarked;
  final FlareControls? flareController;
  final String id;
  final bool isBlurred;
  final bool isLastestRead;
  final int latestReadPage;
  final bool disableFiltering;
  final Map<String, String>? headers;

  const ThumbnailWidget({
    Key? key,
    required this.pad,
    required this.showDetail,
    required this.thumbnail,
    required this.thumbnailTag,
    required this.imageCount,
    required this.isBookmarked,
    required this.flareController,
    required this.id,
    required this.isBlurred,
    required this.headers,
    required this.isLastestRead,
    required this.latestReadPage,
    required this.disableFiltering,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final result = Container(
      foregroundDecoration: isLastestRead &&
              imageCount - latestReadPage <= 2 &&
              !disableFiltering &&
              Settings.showArticleProgress
          ? BoxDecoration(
              color: Settings.themeWhat
                  ? Colors.grey.shade800
                  : Colors.grey.shade300,
              backgroundBlendMode: BlendMode.saturation,
            )
          : null,
      width: showDetail ? 100 - pad / 6 * 5 : null,
      child: thumbnail != null
          ? Stack(
              children: <Widget>[
                ThumbnailImageWidget(
                  headers: headers!,
                  thumbnail: thumbnail!,
                  thumbnailTag: thumbnailTag,
                  isBlurred: isBlurred,
                ),
                BookmarkIndicatorWidget(
                  flareController: flareController,
                  isBookmarked: isBookmarked,
                ),
                ReadProgressOverlayWidget(
                  imageCount: imageCount,
                  latestReadPage: latestReadPage,
                  isLastestRead: isLastestRead,
                ),
                PagesOverlayWidget(
                  imageCount: imageCount,
                  showDetail: showDetail,
                ),
              ],
            )
          : !Settings.simpleItemWidgetLoadingIcon
              ? const FlareActor(
                  'assets/flare/Loading2.flr',
                  alignment: Alignment.center,
                  fit: BoxFit.fitHeight,
                  animation: 'Alarm',
                )
              : Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Settings.majorColor.withAlpha(150),
                    ),
                  ),
                ),
    );

    if (showDetail) {
      return ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(3.0)),
        child: Material(child: result),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3.0),
        child: result,
      );
    }
  }
}

class ThumbnailImageWidget extends StatefulWidget {
  final String thumbnailTag;
  final String thumbnail;
  final Map<String, String> headers;
  final bool isBlurred;

  const ThumbnailImageWidget({
    Key? key,
    required this.thumbnail,
    required this.thumbnailTag,
    required this.headers,
    required this.isBlurred,
  }) : super(key: key);

  @override
  State<ThumbnailImageWidget> createState() => _ThumbnailImageWidgetState();
}

class _ThumbnailImageWidgetState extends State<ThumbnailImageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final Animation<double> _animation;
  UniqueKey _thumbnailKey = UniqueKey();

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.thumbnailTag,
      child: CachedNetworkImage(
        key: _thumbnailKey,
        memCacheWidth: Settings.useLowPerf ? 300 : null,
        imageUrl: widget.thumbnail,
        fit: BoxFit.cover,
        httpHeaders: widget.headers,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
          child: Container(),
        ),
        errorWidget: (context, url, error) {
          Future.delayed(const Duration(milliseconds: 300)).then((value) {
            setState(() {
              _thumbnailKey = UniqueKey();
            });
          });
          return Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Settings.majorColor.withAlpha(150),
              ),
            ),
          );
        },
        progressIndicatorBuilder: (context, url, progress) {
          return Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Settings.majorColor.withAlpha(150),
              ),
            ),
          );
        },
        placeholder: (b, c) {
          if (!Settings.simpleItemWidgetLoadingIcon) {
            return const FlareActor(
              'assets/flare/Loading2.flr',
              alignment: Alignment.center,
              fit: BoxFit.fitHeight,
              animation: 'Alarm',
            );
          } else {
            return Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Settings.majorColor.withAlpha(150),
                ),
              ),
            );
          }
        },
      ),

      // child: ExtendedImage.network(
      //   widget.thumbnail,
      //   headers: widget.headers,
      //   retries: 100,
      //   timeRetry: const Duration(milliseconds: 1000),
      //   fit: BoxFit.cover,
      //   handleLoadingProgress: true,
      //   loadStateChanged: _loadStateChanged,
      //   cacheWidth: Settings.useLowPerf ? 300 : null,
      // ),
    );
  }

  Widget _loadStateChanged(ExtendedImageState state) {
    if (state.extendedImageLoadState == LoadState.failed) {
      Logger.error(
          '[article_item-thumbnail] URL: ${widget.thumbnail}\nE: ${state.lastException}');
      state.reLoadImage();
    }

    if (state.extendedImageLoadState == LoadState.loading) {
      if (!Settings.simpleItemWidgetLoadingIcon) {
        return const FlareActor(
          'assets/flare/Loading2.flr',
          alignment: Alignment.center,
          fit: BoxFit.fitHeight,
          animation: 'Alarm',
        );
      } else {
        return Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: Settings.majorColor.withAlpha(150),
            ),
          ),
        );
      }
    }

    if (state.wasSynchronouslyLoaded) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: state.imageProvider, fit: BoxFit.cover),
        ),
        child: widget.isBlurred
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  decoration:
                      BoxDecoration(color: Colors.white.withOpacity(0.0)),
                ),
              )
            : Container(),
      );
    }

    _controller.forward();

    return FadeTransition(
      opacity: _animation,
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: state.imageProvider, fit: BoxFit.cover),
        ),
        child: widget.isBlurred
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  decoration:
                      BoxDecoration(color: Colors.white.withOpacity(0.0)),
                ),
              )
            : Container(),
      ),
    );
  }
}

class BookmarkIndicatorWidget extends StatelessWidget {
  final ValueNotifier<bool> isBookmarked;
  final FlareControls? flareController;

  const BookmarkIndicatorWidget({
    Key? key,
    required this.isBookmarked,
    required this.flareController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: FractionalOffset.topLeft,
      child: Transform(
        transform: Matrix4.identity()..scale(0.9),
        child: SizedBox(
          width: 35,
          height: 35,
          child: ValueListenableBuilder(
            valueListenable: isBookmarked,
            builder: (BuildContext context, bool value, Widget? child) {
              if (!Settings.simpleItemWidgetLoadingIcon) {
                return FlareActor(
                  'assets/flare/likeUtsua.flr',
                  animation: value ? 'Like' : 'IdleUnlike',
                  controller: flareController,
                );
              } else {
                return Icon(
                  value ? MdiIcons.heart : MdiIcons.heartOutline,
                  color: value ? const Color(0xFFE2264D) : null,
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class ReadProgressOverlayWidget extends StatelessWidget {
  final bool isLastestRead;
  final int latestReadPage;
  final int imageCount;

  const ReadProgressOverlayWidget({
    Key? key,
    required this.isLastestRead,
    required this.latestReadPage,
    required this.imageCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return !isLastestRead || !Settings.showArticleProgress
        ? Container()
        : Align(
            alignment: FractionalOffset.topRight,
            child: Container(
              // margin: EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.all(4),
              width: 50,
              height: 5,
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: LinearProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  value: isLastestRead && imageCount - latestReadPage <= 2
                      ? 1.0
                      : latestReadPage / imageCount,
                  backgroundColor: Colors.grey.withAlpha(100),
                ),
              ),
            ),
          );
  }
}

class PagesOverlayWidget extends StatelessWidget {
  final bool showDetail;
  final int imageCount;

  const PagesOverlayWidget({
    Key? key,
    required this.showDetail,
    required this.imageCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !showDetail,
      child: Align(
        alignment: FractionalOffset.bottomRight,
        child: Transform(
          transform: Matrix4.identity()..scale(0.9),
          child: Theme(
            data: ThemeData(canvasColor: Colors.transparent),
            child: RawChip(
              labelPadding: const EdgeInsets.all(0.0),
              label: Text(
                '$imageCount Page',
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              elevation: 6.0,
              shadowColor: Colors.grey[60],
              padding: const EdgeInsets.all(6.0),
            ),
          ),
        ),
      ),
    );
  }
}
