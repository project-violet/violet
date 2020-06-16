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
import 'package:photo_view/photo_view.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/viewer_page.dart';
import 'package:violet/settings.dart';

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
  final QueryResult queryResult;

  ArticleListItemVerySimpleWidget({this.queryResult, this.addBottomPadding});

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
  FlareControls _flareController = FlareControls();

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
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
    scaleAnimationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (disposed) return null;
    var windowWidth = MediaQuery.of(context).size.width;
    if (!ThumbnailManager.isExists(widget.queryResult.id())) {
      HitomiManager.getImageList(widget.queryResult.id().toString())
          .then((images) {
        thumbnail = images.item2[0];
        imageCount = images.item2.length;
        ThumbnailManager.insert(widget.queryResult.id(), images);
        if (disposed) return null;
        setState(() {});
      });
    } else {
      var thumbnails = ThumbnailManager.get(widget.queryResult.id()).item2;
      thumbnail = thumbnails[0];
      imageCount = thumbnails.length;
    }

    var headers = {
      "Referer": "https://hitomi.la/reader/${widget.queryResult.id()}.html/"
    };

    return PimpedButton(
        particle: Rectangle2DemoParticle(),
        pimpedWidgetBuilder: (context, controller) {
          return GestureDetector(
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: windowWidth - 100,
                height: 500,
                child: AnimatedContainer(
                  curve: Curves.easeInOut,
                  duration: Duration(milliseconds: 300),
                  padding: EdgeInsets.all(pad),
                  child: Container(
                    margin: widget.addBottomPadding
                        ? EdgeInsets.only(bottom: 50)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
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
                    child: Container(
                      child: thumbnail != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(5.0),
                              child: Stack(
                                children: <Widget>[
                                  Hero(
                                    tag: 'thumbnail' +
                                        widget.queryResult.id().toString(),
                                    child: CachedNetworkImage(
                                      imageUrl: thumbnail,
                                      fit: BoxFit.cover,
                                      httpHeaders: headers,
                                      imageBuilder: (context, imageProvider) =>
                                          Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                              image: imageProvider,
                                              fit: BoxFit.cover),
                                        ),
                                        child: isBlurred
                                            ? new BackdropFilter(
                                                filter: new ImageFilter.blur(
                                                    sigmaX: 5.0, sigmaY: 5.0),
                                                child: new Container(
                                                  decoration: new BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.0)),
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
                                      transform: new Matrix4.identity()
                                        ..scale(0.9),
                                      child: SizedBox(
                                        width: 35,
                                        height: 35,
                                        child: FlareActor(
                                          'assets/flare/likeUtsua.flr',
                                          animation: isBookmarked
                                              ? "Like"
                                              : "IdleUnlike",
                                          controller: _flareController,
                                          // color: Colors.orange,
                                          // snapToEnd: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: FractionalOffset.bottomRight,
                                    child: Transform(
                                      transform: new Matrix4.identity()
                                        ..scale(0.9),
                                      child: Theme(
                                        data: ThemeData(
                                            canvasColor: Colors.transparent),
                                        child: RawChip(
                                          labelPadding: EdgeInsets.all(0.0),
                                          // avatar: CircleAvatar(
                                          //   backgroundColor: Colors.grey.shade600,
                                          //   child: Text('P'),
                                          // ),
                                          label: Text(
                                            '' +
                                                imageCount.toString() +
                                                ' Page',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),

                                          // backgroundColor: Colors.pink,
                                          elevation: 6.0,
                                          shadowColor: Colors.grey[60],
                                          padding: EdgeInsets.all(6.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : FlareActor(
                              "assets/flare/Loading2.flr",
                              alignment: Alignment.center,
                              fit: BoxFit.fitHeight,
                              animation: "Alarm",
                            ),
                    ),
                    //     ),
                    // ),
                  ),
                ),
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
                pad = 10.0;
              });
            },
            onTapUp: (detail) {
              if (onScaling) return;
              setState(() {
                pad = 0;
              });
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
            },
            onLongPress: () async {
              Scaffold.of(context).showSnackBar(SnackBar(
                duration: Duration(seconds: 2),
                content: new Text(
                  isBookmarked
                      ? '${widget.queryResult.id()}가 북마크에서 삭제되었습니다.'
                      : '${widget.queryResult.id()}가 북마크에 추가되었습니다.',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.grey.shade800,
              ));
              isBookmarked = !isBookmarked;
              if (!isBookmarked)
                _flareController.play('Unlike');
              else {
                controller.forward(from: 0.0);
                _flareController.play('Like');
              }
              await HapticFeedback.vibrate();
              setState(() {
                pad = 0;
              });
            },
            onLongPressEnd: (detail) {
              setState(() {
                pad = 0;
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
                  heroKey: 'thumbnail' + widget.queryResult.id().toString(),
                ),
              ));
            },
          );
        });
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
      onScaleUpdate: (detail) {
        setState(() {
          scale = latest * detail.scale;
        });

        if (scale < 0.6) Navigator.pop(context);
      },
      onScaleEnd: (detail) {
        latest = scale;
      },
      onVerticalDragStart: (detail) {
        dragStart = detail.localPosition.dy;
      },
      onVerticalDragUpdate: (detail) {
        if (detail.localPosition.dy - dragStart > 100)
          Navigator.pop(context);
      },
    );
  }

  double dragStart;
}

class ArticleListItemDetailWidget extends StatefulWidget {
  @override
  _ArticleListItemDetailWidgetState createState() =>
      _ArticleListItemDetailWidgetState();
}

class _ArticleListItemDetailWidgetState
    extends State<ArticleListItemDetailWidget> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
