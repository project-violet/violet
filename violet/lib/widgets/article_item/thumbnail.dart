// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:violet/pages/viewer/v_optimized_cached_image.dart';
import 'package:violet/settings/settings.dart';

class ThumbnailWidget extends StatelessWidget {
  final double pad;
  final bool showDetail;
  final String thumbnail;
  final String thumbnailTag;
  final int imageCount;
  final bool isBookmarked;
  final FlareControls flareController;
  final String id;
  final bool isBlurred;
  final bool isLastestRead;
  final int latestReadPage;
  final bool disableFiltering;
  final Map<String, String> headers;

  ThumbnailWidget({
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  ? BorderRadius.horizontal(left: Radius.circular(3.0))
                  : BorderRadius.circular(3.0),
              child: Stack(
                children: <Widget>[
                  _thumbnailImage(),
                  _bookmarkIndicator(),
                  _readProgress(),
                  _pages(),
                ],
              ),
            )
          : FlareActor(
              "assets/flare/Loading2.flr",
              alignment: Alignment.center,
              fit: BoxFit.fitHeight,
              animation: "Alarm",
            ),
    );
  }

  Widget _thumbnailImage() {
    // var headers = {"Referer": "https://hitomi.la/reader/${id}.html/"};
    return Hero(
      tag: thumbnailTag,
      child: CachedNetworkImage(
        imageUrl: thumbnail,
        fit: BoxFit.cover,
        httpHeaders: headers,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
          child: isBlurred
              ? BackdropFilter(
                  filter: new ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: new Container(
                    decoration:
                        new BoxDecoration(color: Colors.white.withOpacity(0.0)),
                  ),
                )
              : Container(),
        ),
        placeholder: (b, c) {
          return FlareActor(
            "assets/flare/Loading2.flr",
            alignment: Alignment.center,
            fit: BoxFit.fitHeight,
            animation: "Alarm",
          );
        },
      ),
    );
  }

  Widget _bookmarkIndicator() {
    return Align(
      alignment: FractionalOffset.topLeft,
      child: Transform(
        transform: new Matrix4.identity()..scale(0.9),
        child: SizedBox(
          width: 35,
          height: 35,
          child: FlareActor(
            'assets/flare/likeUtsua.flr',
            animation: isBookmarked ? "Like" : "IdleUnlike",
            controller: flareController,
          ),
        ),
      ),
    );
  }

  Widget _readProgress() {
    return !isLastestRead || !Settings.showArticleProgress
        ? Container()
        : Align(
            alignment: FractionalOffset.topRight,
            child: Container(
              // margin: EdgeInsets.symmetric(vertical: 10),
              margin: EdgeInsets.all(4),
              width: 50,
              height: 5,
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  value: isLastestRead && imageCount - latestReadPage <= 2
                      ? 1.0
                      : latestReadPage / imageCount,
                  backgroundColor: Colors.grey.withAlpha(100),
                ),
              ),
            ),
          );
  }

  Widget _pages() {
    return Visibility(
      visible: !showDetail,
      child: Align(
        alignment: FractionalOffset.bottomRight,
        child: Transform(
          transform: new Matrix4.identity()..scale(0.9),
          child: Theme(
            data: ThemeData(canvasColor: Colors.transparent),
            child: RawChip(
              labelPadding: EdgeInsets.all(0.0),
              label: Text(
                '' + imageCount.toString() + ' Page',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              elevation: 6.0,
              shadowColor: Colors.grey[60],
              padding: EdgeInsets.all(6.0),
            ),
          ),
        ),
      ),
    );
  }
}
