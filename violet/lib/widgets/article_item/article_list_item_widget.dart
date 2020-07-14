// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:tuple/tuple.dart';
import 'package:vibration/vibration.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/locale.dart';
import 'package:violet/main.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/search/search_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/settings.dart';
import 'package:violet/database/user/user.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';
import 'package:violet/widgets/article_item/thumbnail_manager.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';

typedef void BookmarkCallback(int article);
typedef void BookmarkCheckCallback(int article, bool check);

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  final bool addBottomPadding;
  final bool showDetail;
  final QueryResult queryResult;
  final double width;
  final String thumbnailTag;
  final bool bookmarkMode;
  final BookmarkCallback bookmarkCallback;
  final BookmarkCheckCallback bookmarkCheckCallback;
  bool isChecked;
  final bool isCheckMode;

  ArticleListItemVerySimpleWidget({
    this.queryResult,
    this.addBottomPadding,
    this.showDetail,
    this.width,
    this.thumbnailTag,
    this.bookmarkMode = false,
    this.bookmarkCallback,
    this.bookmarkCheckCallback,
    this.isChecked = false,
    this.isCheckMode = false,
  });

  @override
  _ArticleListItemVerySimpleWidgetState createState() =>
      _ArticleListItemVerySimpleWidgetState();
}

class _ArticleListItemVerySimpleWidgetState
    extends State<ArticleListItemVerySimpleWidget>
    with TickerProviderStateMixin {
  String thumbnail;
  int imageCount = 0;
  double pad = 0.0;
  double scale = 1.0;
  bool onScaling = false;
  AnimationController scaleAnimationController;
  bool isBlurred = false;
  bool disposed = false;
  bool isBookmarked = false;
  bool animating = false;
  final FlareControls _flareController = FlareControls();

  @override
  void initState() {
    super.initState();
    scaleAnimationController = AnimationController(
      vsync: this,
      lowerBound: 1.0,
      upperBound: 1.08,
      duration: Duration(milliseconds: 180),
    );
    scaleAnimationController.addListener(() {
      setState(() {
        scale = scaleAnimationController.value;
      });
    });

    Bookmark.getInstance().then((value) async {
      isBookmarked = await value.isBookmark(widget.queryResult.id());
      if (isBookmarked) setState(() {});
    });
    artist = (widget.queryResult.artists() as String)
        .split('|')
        .where((x) => x.length != 0)
        .join(',');
    if (artist == 'N/A') {
      var group = widget.queryResult.groups() != null
          ? widget.queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    title = HtmlUnescape().convert(widget.queryResult.title());
    dateTime = widget.queryResult.getDateTime() != null
        ? DateFormat('yyyy/MM/dd HH:mm')
            .format(widget.queryResult.getDateTime())
        : '';
    if (!ThumbnailManager.isExists(widget.queryResult.id())) {
      HitomiManager.getImageList(widget.queryResult.id().toString())
          .then((images) {
        thumbnail = images.item2[0];
        imageCount = images.item2.length;
        ThumbnailManager.insert(widget.queryResult.id(), images);
        setState(() {});
      });
    } else {
      var thumbnails = ThumbnailManager.get(widget.queryResult.id()).item2;
      thumbnail = thumbnails[0];
      imageCount = thumbnails.length;
    }
  }

  String artist;
  String title;
  String dateTime;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
    scaleAnimationController.dispose();
  }

  bool firstChecked = false;

  @override
  Widget build(BuildContext context) {
    if (disposed) return null;
    if (widget.bookmarkMode &&
        !widget.isCheckMode &&
        !onScaling &&
        scale != 1.0) {
      setState(() {
        scale = 1.0;
      });
    } else if (widget.bookmarkMode &&
        widget.isCheckMode &&
        widget.isChecked &&
        scale != 0.95) {
      setState(() {
        scale = 0.95;
      });
    }

    double ww = widget.showDetail
        ? widget.width - 16
        : widget.width - (widget.addBottomPadding ? 100 : 0);
    double hh = widget.showDetail
        ? 130.0
        : widget.addBottomPadding ? 500.0 : widget.width * 4 / 3;

    var headers = {
      "Referer": "https://hitomi.la/reader/${widget.queryResult.id()}.html/"
    };
    return PimpedButton(
        particle: Rectangle2DemoParticle(),
        pimpedWidgetBuilder: (context, controller) {
          return GestureDetector(
            child: SizedBox(
              width: ww,
              height: hh,
              child: AnimatedContainer(
                // alignment: FractionalOffset.center,
                curve: Curves.easeInOut,
                duration: Duration(milliseconds: 300),
                // padding: EdgeInsets.all(pad),
                transform: Matrix4.identity()
                  ..translate(ww / 2, hh / 2)
                  ..scale(scale)
                  ..translate(-ww / 2, -hh / 2),
                child: buildBody(),
              ),
            ),
            // onScaleStart: (detail) {
            //   onScaling = true;
            //   setState(() {
            //     pad = 0;
            //   });
            // },
            // onScaleUpdate: (detail) async {
            //   if (detail.scale > 1.1 &&
            //       !scaleAnimationController.isAnimating &&
            //       !scaleAnimationController.isCompleted) {
            //     scaleAnimationController.forward(from: 1.0);
            //   }
            //   if (detail.scale > 1.1 && !scaleAnimationController.isCompleted) {
            //     var sz = await _calculateImageDimension(thumbnail);
            //     Navigator.of(context).push(PageRouteBuilder(
            //       opaque: false,
            //       transitionDuration: Duration(milliseconds: 500),
            //       pageBuilder: (_, __, ___) => ThumbnailViewPage(
            //         size: sz,
            //         thumbnail: thumbnail,
            //         headers: headers,
            //       ),
            //     ));
            //   }
            // },
            // onScaleEnd: (detail) {
            //   onScaling = false;
            //   scaleAnimationController.reverse();
            // },
            onTapDown: (detail) {
              if (onScaling) return;
              onScaling = true;
              setState(() {
                // pad = 10.0;
                scale = 0.95;
              });
            },
            onTapUp: (detail) {
              // if (onScaling) return;
              onScaling = false;
              if (widget.isCheckMode) {
                widget.isChecked = !widget.isChecked;
                widget.bookmarkCheckCallback(
                    widget.queryResult.id(), widget.isChecked);
                setState(() {
                  if (widget.isChecked)
                    scale = 0.95;
                  else
                    scale = 1.0;
                });
                return;
              }
              if (firstChecked) return;
              setState(() {
                // pad = 0;
                scale = 1.0;
              });
              if (false) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (context) {
                      return ViewerPage(
                        id: widget.queryResult.id().toString(),
                        images:
                            ThumbnailManager.get(widget.queryResult.id()).item1,
                        headers: headers,
                      );
                    },
                  ),
                );
              } else {
                Navigator.of(context).push(PageRouteBuilder(
                  // opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder: (BuildContext context,
                      Animation<double> animation,
                      Animation<double> secondaryAnimation,
                      Widget wi) {
                    // return wi;
                    return new FadeTransition(opacity: animation, child: wi);
                  },
                  pageBuilder: (_, __, ___) => ArticleInfoPage(
                    queryResult: widget.queryResult,
                    thumbnail: thumbnail,
                    headers: headers,
                    heroKey: widget.thumbnailTag,
                    isBookmarked: isBookmarked,
                  ),
                ));
              }
            },
            onLongPress: () async {
              onScaling = false;
              if (widget.bookmarkMode) {
                if (widget.isCheckMode) {
                  widget.isChecked = !widget.isChecked;
                  setState(() {
                    scale = 1.0;
                  });
                  return;
                }
                widget.isChecked = true;
                firstChecked = true;
                setState(() {
                  scale = 0.95;
                });
                widget.bookmarkCallback(widget.queryResult.id());
                return;
              }

              if (isBookmarked) {
                if (!await Dialogs.yesnoDialog(context, '북마크를 삭제할까요?', '북마크'))
                  return;
              }
              try {
                Scaffold.of(context).showSnackBar(SnackBar(
                  duration: Duration(seconds: 2),
                  content: new Text(
                    isBookmarked
                        ? '${widget.queryResult.id()}${Translations.of(context).trans('removetobookmark')}'
                        : '${widget.queryResult.id()}${Translations.of(context).trans('addtobookmark')}',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.grey.shade800,
                ));
              } catch (e) {}
              isBookmarked = !isBookmarked;
              if (isBookmarked)
                await (await Bookmark.getInstance())
                    .bookmark(widget.queryResult.id());
              else
                await (await Bookmark.getInstance())
                    .unbookmark(widget.queryResult.id());
              if (!isBookmarked)
                _flareController.play('Unlike');
              else {
                controller.forward(from: 0.0);
                _flareController.play('Like');
              }
              await HapticFeedback.vibrate();

              // await Vibration.vibrate(duration: 50, amplitude: 50);
              setState(() {
                pad = 0;
                scale = 1.0;
              });
            },
            onLongPressEnd: (detail) {
              onScaling = false;
              if (firstChecked) {
                firstChecked = false;
                return;
              }
              setState(() {
                pad = 0;
                scale = 1.0;
              });
            },
            onTapCancel: () {
              onScaling = false;
              setState(() {
                pad = 0;
                scale = 1.0;
              });
            },
            onDoubleTap: () async {
              onScaling = false;
              var sz = await _calculateImageDimension(thumbnail);
              Navigator.of(context).push(PageRouteBuilder(
                opaque: false,
                transitionDuration: Duration(milliseconds: 500),
                transitionsBuilder: (BuildContext context,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                    Widget wi) {
                  return new FadeTransition(opacity: animation, child: wi);
                },
                pageBuilder: (_, __, ___) => ThumbnailViewPage(
                  size: sz,
                  thumbnail: thumbnail,
                  headers: headers,
                  heroKey: widget.thumbnailTag,
                ),
              ));
              setState(() {
                pad = 0;
              });
            },
          );
        });
  }

  Widget buildBody() {
    return Container(
        margin: widget.addBottomPadding
            ? widget.showDetail
                ? EdgeInsets.only(bottom: 6)
                : EdgeInsets.only(bottom: 50)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: widget.showDetail
              ? Settings.themeWhat ? Colors.grey.shade800 : Colors.white70
              : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.all(Radius.circular(5)),
          boxShadow: [
            BoxShadow(
              color: Settings.themeWhat
                  ? Colors.grey.withOpacity(0.08)
                  : Colors.grey.withOpacity(0.4),
              spreadRadius: 5,
              blurRadius: 7,
              offset: Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: widget.showDetail
            ? Row(
                children: <Widget>[
                  buildThumbnail(),
                  Expanded(child: buildDetail())
                ],
              )
            : buildThumbnail());
  }

  Widget buildThumbnail() {
    return ThumbnailWidget(
      id: widget.queryResult.id().toString(),
      showDetail: widget.showDetail,
      thumbnail: thumbnail,
      thumbnailTag: widget.thumbnailTag,
      imageCount: imageCount,
      isBookmarked: isBookmarked,
      flareController: _flareController,
      pad: pad,
      isBlurred: isBlurred,
    );
  }

  Widget buildDetail() {
    return _DetailWidget(
      artist: artist,
      title: title,
      imageCount: imageCount.toString(),
      dateTime: dateTime,
    );
  }

  Future<Size> _calculateImageDimension(String url) {
    Completer<Size> completer = Completer();
    Image image = new Image(image: CachedNetworkImageProvider(url));
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }
}

// Artist List Item Details
class _DetailWidget extends StatelessWidget {
  final String title;
  final String artist;
  final String imageCount;
  final String dateTime;

  _DetailWidget({this.title, this.artist, this.imageCount, this.dateTime});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      margin: EdgeInsets.fromLTRB(8, 4, 4, 4),
      duration: Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            artist,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(children: <Widget>[
                    Icon(
                      Icons.photo,
                      size: 18,
                    ),
                    Text(' ' + imageCount.toString() + ' Page',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                  Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 4, 0),
                      child: Text(dateTime, style: TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
