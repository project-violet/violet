// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database.dart';
import 'package:violet/pages/viewer_page.dart';

class ThumbnailManager {
  static HashMap<int, List<String>> _ids = HashMap<int, List<String>>();

  static bool isExists(int id) {
    return _ids.containsKey(id);
  }

  static void insert(int id, List<String> url) {
    _ids[id] = url;
  }

  static List<String> get(int id) {
    return _ids[id];
  }

  static void clear() {
    _ids.clear();
  }
}

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  final QueryResult queryResult;

  ArticleListItemVerySimpleWidget({this.queryResult});

  @override
  _ArticleListItemVerySimpleWidgetState createState() =>
      _ArticleListItemVerySimpleWidgetState();
}

class _ArticleListItemVerySimpleWidgetState
    extends State<ArticleListItemVerySimpleWidget>
    with TickerProviderStateMixin {
  String thumbnail;
  double pad = 0.0;
  double scale = 1.0;
  bool onScaling = false;
  AnimationController scaleAnimationController;

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
    super.dispose();
    scaleAnimationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var windowWidth = MediaQuery.of(context).size.width;
    if (!ThumbnailManager.isExists(widget.queryResult.id())) {
      HitomiManager.getImageList(widget.queryResult.id().toString())
          .then((images) {
        thumbnail = images[0];
        ThumbnailManager.insert(widget.queryResult.id(), images);
        setState(() {});
      });
    } else
      thumbnail = ThumbnailManager.get(widget.queryResult.id())[0];

    var headers = {
      "Referer": "https://hitomi.la/reader/${widget.queryResult.id()}.html/"
    };

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
              margin: EdgeInsets.only(bottom: 50),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.all(Radius.circular(10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: Container(
                child: thumbnail != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Hero(
                          tag: thumbnail,
                          child: CachedNetworkImage(
                            imageUrl: thumbnail,
                            fit: BoxFit.cover,
                            httpHeaders: headers,
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
                      )
                    : FlareActor(
                        "assets/flare/Loading2.flr",
                        alignment: Alignment.center,
                        fit: BoxFit.fitHeight,
                        animation: "Alarm",
                      ),
              ),
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
                images: ThumbnailManager.get(widget.queryResult.id()),
                headers: headers,
              );
            },
          ),
        );
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
          pageBuilder: (_, __, ___) => ThumbnailViewPage(
            size: sz,
            thumbnail: thumbnail,
            headers: headers,
          ),
        ));
      },
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

class ThumbnailViewPage extends StatefulWidget {
  final String thumbnail;
  final Map<String, String> headers;
  final Size size;

  ThumbnailViewPage({this.thumbnail, this.headers, this.size});

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
                  tag: widget.thumbnail,
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
              color: Colors.grey.withOpacity(0.2),
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
    );
  }
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
