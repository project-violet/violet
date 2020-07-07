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
import 'package:violet/database.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/article_info_page.dart';
import 'package:violet/pages/search_page.dart';
import 'package:violet/pages/viewer_page.dart';
import 'package:violet/settings.dart';
import 'package:violet/user.dart';

class ThumbnailManager {
  static HashMap<int, Tuple3<List<String>, List<String>, List<String>>> _ids =
      HashMap<int, Tuple3<List<String>, List<String>, List<String>>>();

  static bool isExists(int id) {
    return _ids.containsKey(id);
  }

  static void insert(
      int id, Tuple3<List<String>, List<String>, List<String>> url) {
    _ids[id] = url;
  }

  static Tuple3<List<String>, List<String>, List<String>> get(int id) {
    return _ids[id];
  }

  static void clear() {
    _ids.clear();
  }
}

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  final bool addBottomPadding;
  final bool showDetail;
  final QueryResult queryResult;
  final double width;
  final String thumbnailTag;

  ArticleListItemVerySimpleWidget(
      {this.queryResult,
      this.addBottomPadding,
      this.showDetail,
      this.width,
      this.thumbnailTag});

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

  @override
  Widget build(BuildContext context) {
    if (disposed) return null;

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
              setState(() {
                // pad = 10.0;
                scale = 0.95;
              });
            },
            onTapUp: (detail) {
              if (onScaling) return;
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
              setState(() {
                pad = 0;
                scale = 1.0;
              });
            },
            onTapCancel: () {
              setState(() {
                pad = 0;
                scale = 1.0;
              });
            },
            onDoubleTap: () async {
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
                  // Expanded(
                  //   flex: 4,
                  //   child: buildThumbnail(),
                  // ),
                  buildThumbnail(),
                  // Expanded(flex: 8, child: Text('asdf'),)
                  Expanded(child: buildDetail())
                ],
              )
            : buildThumbnail()
        //     ),
        // ),
        );
  }

  Widget buildThumbnail() {
    return _ThumbnailWidget(
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

// Article List Item Thumbnail
class _ThumbnailWidget extends StatelessWidget {
  final double pad;
  final bool showDetail;
  final String thumbnail;
  final String thumbnailTag;
  final int imageCount;
  final bool isBookmarked;
  final FlareControls flareController;
  final String id;
  final bool isBlurred;

  _ThumbnailWidget({
    this.pad,
    this.showDetail,
    this.thumbnail,
    this.thumbnailTag,
    this.imageCount,
    this.isBookmarked,
    this.flareController,
    this.id,
    this.isBlurred,
  });

  @override
  Widget build(BuildContext context) {
    var headers = {"Referer": "https://hitomi.la/reader/${id}.html/"};
    return Container(
      width: showDetail ? 100 - pad / 6 * 5 : null,
      child: thumbnail != null
          ? ClipRRect(
              borderRadius: showDetail
                  ? BorderRadius.horizontal(left: Radius.circular(5.0))
                  : BorderRadius.circular(5.0),
              child: Stack(
                children: <Widget>[
                  Hero(
                    tag: thumbnailTag,
                    child: CachedNetworkImage(
                      imageUrl: thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                              image: imageProvider, fit: BoxFit.cover),
                        ),
                        child: isBlurred
                            ? BackdropFilter(
                                filter: new ImageFilter.blur(
                                    sigmaX: 5.0, sigmaY: 5.0),
                                child: new Container(
                                  decoration: new BoxDecoration(
                                      color: Colors.white.withOpacity(0.0)),
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
                  ),
                  Align(
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
                  ),
                  Visibility(
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
                  ),
                ],
              ),
            )
          // : Container(),
          : FlareActor(
              "assets/flare/Loading2.flr",
              alignment: Alignment.center,
              fit: BoxFit.fitHeight,
              animation: "Alarm",
            ),
    );
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

class ThumbnailViewPage extends StatefulWidget {
  final String thumbnail;
  final String heroKey;
  final Map<String, String> headers;
  final Size size;

  ThumbnailViewPage({this.thumbnail, this.headers, this.size, this.heroKey});

  @override
  _ThumbnailViewPageState createState() => _ThumbnailViewPageState();
}

class _ThumbnailViewPageState extends State<ThumbnailViewPage> {
  double scale = 1.0;
  double latest = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        // loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        padding: EdgeInsets.all(0),
        child: Transform.scale(
          scale: scale,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Hero(
                  tag: widget.heroKey,
                  child: CachedNetworkImage(
                    imageUrl: widget.thumbnail,
                    fit: BoxFit.cover,
                    httpHeaders: widget.headers,
                    placeholder: (b, c) {
                      return FlareActor(
                        "assets/flare/Loading2.flr",
                        alignment: Alignment.center,
                        fit: BoxFit.fitHeight,
                        animation: "Alarm",
                      );
                    },
                  ),
                ),
              ]),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(1)),
          boxShadow: [
            BoxShadow(
              color: Settings.themeWhat
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 1,
              offset: Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
      ),
      onScaleStart: (detail) {
        tapCount = 2;
      },
      onScaleUpdate: (detail) {
        setState(() {
          scale = latest * detail.scale;
        });

        if (scale < 0.6) Navigator.pop(context);
      },
      onScaleEnd: (detail) {
        latest = scale;
        tapCount = 0;
      },
      onVerticalDragStart: (detail) {
        dragStart = detail.localPosition.dy;
      },
      onVerticalDragUpdate: (detail) {
        if (zooming || tapCount == 2) {
          setState(() {
            scale += (detail.delta.dy) / 100;
          });
          latest = scale;
          if (scale < 0.6) Navigator.pop(context);
        } else if (tapCount != 2 ||
            (detail.localPosition.dy - dragStart).abs() > 70)
          Navigator.pop(context);
      },
      onTapDown: (detail) {
        tapCount++;
        DateTime now = DateTime.now();
        if (currentBackPressTime == null ||
            now.difference(currentBackPressTime) >
                Duration(milliseconds: 300)) {
          currentBackPressTime = now;
          return;
        }
        zooming = true;
      },
      onTapUp: (detail) {
        tapCount--;
        zooming = false;
      },
      onTapCancel: () {
        tapCount = 0;
      },
    );
  }

  int tapCount = 0;
  double dragStart;
  bool zooming = false;
  DateTime currentBackPressTime;
}

// class ArticleListItemDetailWidget extends StatefulWidget {
//   @override
//   _ArticleListItemDetailWidgetState createState() =>
//       _ArticleListItemDetailWidgetState();
// }

// class _ArticleListItemDetailWidgetState
//     extends State<ArticleListItemDetailWidget> {

//   @override
//   void initState() {
//     super.initState();
//     scaleAnimationController = AnimationController(
//       vsync: this,
//       lowerBound: 1.0,
//       upperBound: 1.08,
//       duration: Duration(milliseconds: 180),
//     );
//     scaleAnimationController.addListener(() {
//       setState(() {
//         scale = scaleAnimationController.value;
//       });
//     });
//     _animationController =
//         AnimationController(duration: Duration(milliseconds: 300), vsync: this);
//     _tween = Tween(begin: 0.0, end: 5.0);
//     _animation = _tween.animate(_animationController)
//       ..addListener(() {
//         setState(() {});
//       })
//       ..addStatusListener((status) {
//         if (status == AnimationStatus.completed ||
//             status == AnimationStatus.dismissed) {
//           checkSearchPageBlur = searchPageBlur;
//           animating = false;
//         }
//       });
//     Bookmark.getInstance().then((value) async {
//       isBookmarked = await value.isBookmark(widget.queryResult.id());
//       if (isBookmarked) setState(() {});
//     });
//   }

//   @override
//   void dispose() {
//     disposed = true;
//     super.dispose();
//     scaleAnimationController.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }
// }
