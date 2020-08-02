// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';
import 'package:violet/widgets/article_item/thumbnail_manager.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';

typedef void BookmarkCallback(int article);
typedef void BookmarkCheckCallback(int article, bool check);

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  // final bool addBottomPadding;
  // final bool showDetail;
  // final QueryResult queryResult;
  // final double width;
  // final String thumbnailTag;
  // final bool bookmarkMode;
  // final BookmarkCallback bookmarkCallback;
  // final BookmarkCheckCallback bookmarkCheckCallback;
  // bool isChecked;
  // final bool isCheckMode;

  // ArticleListItemVerySimpleWidget({
  //   this.queryResult,
  //   this.addBottomPadding,
  //   this.showDetail,
  //   this.width,
  //   this.thumbnailTag,
  //   this.bookmarkMode = false,
  //   this.bookmarkCallback,
  //   this.bookmarkCheckCallback,
  //   this.isChecked = false,
  //   this.isCheckMode = false,
  // });

  @override
  _ArticleListItemVerySimpleWidgetState createState() =>
      _ArticleListItemVerySimpleWidgetState();
}

class _ArticleListItemVerySimpleWidgetState
    extends State<ArticleListItemVerySimpleWidget>
    with TickerProviderStateMixin {
  ArticleListItem data;

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

  bool _inited = false;

  _init() {
    if (_inited) return;
    _inited = true;
    data = Provider.of<ArticleListItem>(context);
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
      isBookmarked = await value.isBookmark(data.queryResult.id());
      if (isBookmarked) setState(() {});
    });
    artist = (data.queryResult.artists() as String)
        .split('|')
        .where((x) => x.length != 0)
        .join(',');
    if (artist == 'N/A') {
      var group = data.queryResult.groups() != null
          ? data.queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    title = HtmlUnescape().convert(data.queryResult.title());
    dateTime = data.queryResult.getDateTime() != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(data.queryResult.getDateTime())
        : '';
    if (!ThumbnailManager.isExists(data.queryResult.id())) {
      HitomiManager.getImageList(data.queryResult.id().toString())
          .then((images) {
        thumbnail = images.item2[0];
        imageCount = images.item2.length;
        ThumbnailManager.insert(data.queryResult.id(), images);
        if (!disposed) setState(() {});
      });
    } else {
      var thumbnails = ThumbnailManager.get(data.queryResult.id()).item2;
      thumbnail = thumbnails[0];
      imageCount = thumbnails.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (disposed) return null;
    _init();
    if (data.bookmarkMode && !data.isCheckMode && !onScaling && scale != 1.0) {
      setState(() {
        scale = 1.0;
      });
    } else if (data.bookmarkMode &&
        data.isCheckMode &&
        data.isChecked &&
        scale != 0.95) {
      setState(() {
        scale = 0.95;
      });
    }

    double ww = data.showDetail
        ? data.width - 16
        : data.width - (data.addBottomPadding ? 100 : 0);
    double hh = data.showDetail
        ? 130.0
        : data.addBottomPadding ? 500.0 : data.width * 4 / 3;

    var headers = {
      "Referer": "https://hitomi.la/reader/${data.queryResult.id()}.html/"
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
              if (data.isCheckMode) {
                data.isChecked = !data.isChecked;
                data.bookmarkCheckCallback(
                    data.queryResult.id(), data.isChecked);
                setState(() {
                  if (data.isChecked)
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
                        id: data.queryResult.id().toString(),
                        images:
                            ThumbnailManager.get(data.queryResult.id()).item1,
                        headers: headers,
                      );
                    },
                  ),
                );
              } else {
                // Navigator.of(context).push(PageRouteBuilder(
                //   // opaque: false,
                //   transitionDuration: Duration(milliseconds: 500),
                //   transitionsBuilder: (BuildContext context,
                //       Animation<double> animation,
                //       Animation<double> secondaryAnimation,
                //       Widget wi) {
                //     // return wi;
                //     return new FadeTransition(opacity: animation, child: wi);
                //   },
                //   pageBuilder: (_, __, ___) => ArticleInfoPage(
                //     queryResult: widget.queryResult,
                //     thumbnail: thumbnail,
                //     headers: headers,
                //     heroKey: widget.thumbnailTag,
                //     isBookmarked: isBookmarked,
                //   ),
                // ));
                final height = MediaQuery.of(context).size.height;

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) {
                    return DraggableScrollableSheet(
                      initialChildSize: 350 / height,
                      minChildSize: 350 / height,
                      maxChildSize: 1.0,
                      expand: false,
                      builder: (_, controller) {
                        return Provider<ArticleInfo>.value(
                          child: ArticleInfoPage(
                            key: ObjectKey('asdfasdf'),
                          ),
                          value: ArticleInfo.fromArticleInfo(
                            queryResult: data.queryResult,
                            thumbnail: thumbnail,
                            headers: headers,
                            heroKey: data.thumbnailTag,
                            isBookmarked: isBookmarked,
                            controller: controller,
                          ),
                        );
                      },
                    );
                  },
                );
              }
            },
            onLongPress: () async {
              onScaling = false;
              if (data.bookmarkMode) {
                if (data.isCheckMode) {
                  data.isChecked = !data.isChecked;
                  setState(() {
                    scale = 1.0;
                  });
                  return;
                }
                data.isChecked = true;
                firstChecked = true;
                setState(() {
                  scale = 0.95;
                });
                data.bookmarkCallback(data.queryResult.id());
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
                        ? '${data.queryResult.id()}${Translations.of(context).trans('removetobookmark')}'
                        : '${data.queryResult.id()}${Translations.of(context).trans('addtobookmark')}',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.grey.shade800,
                ));
              } catch (e) {}
              isBookmarked = !isBookmarked;
              if (isBookmarked)
                await (await Bookmark.getInstance())
                    .bookmark(data.queryResult.id());
              else
                await (await Bookmark.getInstance())
                    .unbookmark(data.queryResult.id());
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
                  heroKey: data.thumbnailTag,
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
        margin: data.addBottomPadding
            ? data.showDetail
                ? EdgeInsets.only(bottom: 6)
                : EdgeInsets.only(bottom: 50)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: data.showDetail
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
        child: data.showDetail
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
      id: data.queryResult.id().toString(),
      showDetail: data.showDetail,
      thumbnail: thumbnail,
      thumbnailTag: data.thumbnailTag,
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
