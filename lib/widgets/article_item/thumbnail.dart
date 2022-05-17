// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/settings/settings.dart';

class ThumbnailWidget extends StatelessWidget {
  final double pad;
  final bool showDetail;
  final String thumbnail;
  final String thumbnailTag;
  final int imageCount;
  final ValueNotifier<bool> isBookmarked;
  final FlareControls flareController;
  final String id;
  final bool isBlurred;
  final bool isLastestRead;
  final int latestReadPage;
  final bool disableFiltering;
  final Map<String, String> headers;

  const ThumbnailWidget({
    Key key,
    this.pad,
    this.showDetail,
    this.thumbnail,
    this.thumbnailTag,
    this.imageCount,
    this.isBookmarked,
    this.flareController,
    this.id,
    this.isBlurred,
    this.headers,
    this.isLastestRead,
    this.latestReadPage,
    this.disableFiltering,
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
          ? ClipRRect(
              borderRadius: showDetail
                  ? const BorderRadius.horizontal(left: Radius.circular(3.0))
                  : BorderRadius.circular(3.0),
              child: Stack(
                children: <Widget>[
                  ThumbnailImageWidget(
                    headers: headers,
                    thumbnail: thumbnail,
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
              ),
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
      return Material(child: result);
    } else {
      return result;
    }
  }
}

class ThumbnailImageWidget extends StatelessWidget {
  final String thumbnailTag;
  final String thumbnail;
  final Map<String, String> headers;
  final bool isBlurred;

  const ThumbnailImageWidget(
      {Key key,
      this.thumbnail,
      this.thumbnailTag,
      this.headers,
      this.isBlurred})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: thumbnailTag,
      child: CachedNetworkImage(
        memCacheWidth: Settings.useLowPerf ? 30 : null,
        imageUrl: thumbnail,
        fit: BoxFit.cover,
        httpHeaders: headers,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
          child: isBlurred
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    decoration:
                        BoxDecoration(color: Colors.white.withOpacity(0.0)),
                  ),
                )
              : Container(),
        ),
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
    );
  }
}

class BookmarkIndicatorWidget extends StatelessWidget {
  final ValueNotifier<bool> isBookmarked;
  final FlareControls flareController;

  const BookmarkIndicatorWidget(
      {Key key, this.isBookmarked, this.flareController})
      : super(key: key);

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
            builder: (BuildContext context, bool value, Widget child) {
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

  const ReadProgressOverlayWidget(
      {Key key, this.isLastestRead, this.latestReadPage, this.imageCount})
      : super(key: key);

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

  const PagesOverlayWidget({Key key, this.showDetail, this.imageCount})
      : super(key: key);

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
                style: const TextStyle(color: Colors.white),
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
