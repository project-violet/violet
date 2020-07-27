// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

// 네트워크 이미지들을 보기위한 위젯

//import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/settings.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/viewer/gallery_item.dart';
import 'package:violet/pages/viewer/horizontal_viewer_widget.dart';

class ViewerWidget extends StatefulWidget {
  final List<String> urls;
  final Map<String, String> headers;
  final String id;
  List<GalleryExampleItem> galleryItems;

  ViewerWidget({this.urls, this.headers, this.id}) {
    galleryItems = new List<GalleryExampleItem>();

    for (int i = 0; i < urls.length; i++) {
      galleryItems.add(GalleryExampleItem(
        id: i == 0 ? 'thumbnail' + id : urls[i],
        url: urls[i],
        headers: headers,
        loaded: false,
      ));
    }
  }

  @override
  _ViewerWidgetState createState() => _ViewerWidgetState();
}

class _ViewerWidgetState extends State<ViewerWidget>
    with SingleTickerProviderStateMixin {
  int prevPage = 0;
  @override
  void initState() {
    super.initState();

    scroll.addListener(() async {
      currentPage = offset2Page(scroll.offset);
      if (prevPage != currentPage) {
        // prevPage = 0;
        // print(currentPage);
        // var evictStarts = min(0, currentPage - 5);
        // var evictEnds = max(currentPage + 5, widget.urls.length);
        // for (int i = 0; i < evictStarts; i++)
        //   await CachedNetworkImageProvider(widget.urls[i]).evict();
        // for (int i = evictEnds; i < widget.urls.length; i++)
        //   await CachedNetworkImageProvider(widget.urls[i]).evict();
        prevPage = currentPage;
      }
    });
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    Future.delayed(Duration(milliseconds: 500)).then((value) {
      if (_controller.isCompleted) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });

    Future.delayed(Duration(milliseconds: 100))
        .then((value) => _checkLatestRead());
  }

  @override
  void dispose() {
    scroll.dispose();
    _controller.dispose();

    PaintingBinding.instance.imageCache.clear();

    widget.urls.forEach((element) async {
      await CachedNetworkImageProvider(element).evict();
    });

    SystemChrome.setEnabledSystemUIOverlays([
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);

    super.dispose();
  }

  ScrollController scroll = ScrollController();

  int offset2Page(double offset) {
    double xx = 0.0;
    for (int i = 0; i < widget.galleryItems.length; i++) {
      xx += widget.galleryItems[i].loaded ? widget.galleryItems[i].height : 300;
      xx += 4;
      if (offset < xx) {
        return i + 1;
      }
    }
    return widget.galleryItems.length;
  }

  double page2Offset(int page) {
    double xx = 0.0;
    for (int i = 0; i < page; i++) {
      xx += widget.galleryItems[i].loaded ? widget.galleryItems[i].height : 300;
      // xx += 4;
    }
    return xx;
  }

  void _transToGalleryView(BuildContext context, final int index) async {
    var w = GalleryPhotoViewWrapper(
      galleryItems: widget.galleryItems,
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      totalPage: widget.galleryItems.length,
      initialIndex: index,
      scrollDirection: Axis.horizontal,
    );
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => w),
    );
    SystemChrome.setEnabledSystemUIOverlays([]);

    if (w.currentIndex != index) {
      scroll.jumpTo(page2Offset(w.currentIndex));
    }
  }

  AnimationController _controller;

  void _checkLatestRead() {
    User.getInstance().then((value) => value.getUserLog().then((value) async {
          var x = value.where((e) => e.articleId().toString() == widget.id);
          if (x.length < 2) return;
          var e = x.elementAt(1);
          if (e.lastPage() == null) return;
          if (e.lastPage() > 1 &&
              DateTime.parse(e.datetimeStart())
                      .difference(DateTime.now())
                      .inDays <
                  7) {
            if (await Dialogs.yesnoDialog(
                context,
                Translations.of(context)
                    .trans('recordmessage')
                    .replaceAll('%s', e.lastPage().toString()),
                Translations.of(context).trans('record'))) {
              scroll.jumpTo(page2Offset(e.lastPage() - 1));
            }
          }
        }));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Stack(
            children: <Widget>[
              PhotoView.customChild(
                minScale: 1.0,
                child: Container(
                  color: const Color(0xff444444),
                  child: DraggableScrollbar(
                    backgroundColor:
                        Settings.themeWhat ? Colors.black : Colors.white,
                    controller: scroll,
                    labelTextBuilder: (double offset) =>
                        Text("${offset2Page(offset)}"),
                    child: ListView.builder(
                      itemCount: widget.urls.length,
                      controller: scroll,
                      cacheExtent: height * 4,
                      itemBuilder: (context, index) {
                        return Container(
                          // padding: EdgeInsets.all(2),
                          child: GalleryExampleItemThumbnail(
                            galleryExampleItem: widget.galleryItems[index],
                            onTap: () => _transToGalleryView(context, index),
                          ),
                        );
                      },
                    ),
                    heightScrollThumb: 48.0,
                    scrollThumbBuilder: (
                      Color backgroundColor,
                      Animation<double> thumbAnimation,
                      Animation<double> labelAnimation,
                      double height, {
                      Text labelText,
                      BoxConstraints labelConstraints,
                    }) {
                      if (labelText != null &&
                          labelText.data != null &&
                          labelText.data.trim() != '')
                        latestLabel = labelText.data;
                      return Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            ScrollLabel(
                              animation: labelAnimation,
                              child: Text(latestLabel),
                              backgroundColor: backgroundColor,
                            ),
                            FadeTransition(
                              opacity: thumbAnimation,
                              child: Container(
                                height: height,
                                width: 6.0,
                                color: backgroundColor.withOpacity(0.6),
                              ),
                            )
                          ]);
                    },
                  ),
                ),
              ),
              _touchArea(),
              _topAppBar(),
              _bottomAppBar(),
            ],
          ),
        ),
      ),
    );
  }

  bool _overlayOpend = false;
  Widget _touchArea() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.center,
      child: Container(
        color: null,
        width: width / 3,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (!_overlayOpend) {
              if (_controller.isCompleted) {
                _controller.reverse();
              } else {
                _controller.forward();
              }
              SystemChrome.setEnabledSystemUIOverlays(
                  [SystemUiOverlay.bottom, SystemUiOverlay.top]);
            } else {
              if (_controller.isCompleted) {
                _controller.reverse();
              } else {
                _controller.forward();
              }
              SystemChrome.setEnabledSystemUIOverlays([]);
            }
            _overlayOpend = !_overlayOpend;
          },
        ),
      ),
    );
  }

  Widget _topAppBar() {
    return Transform.translate(
      offset: Offset(0, -_controller.value * 64),
      child: Container(
        height: 56.0,
        child: AppBar(
          title: Text(widget.id.toString()),
          leading: InkWell(
            child: Icon(
              Icons.arrow_back,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _bottomAppBar() {
    final height = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Transform.translate(
      offset: Offset(0, _controller.value * 128),
      child: Container(
        // height: 128,
        padding: EdgeInsets.only(top: height - bottom - 128),
        child: BottomAppBar(
          color: Colors.black,
          child: Container(
            height: 128,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('???'),
                ]),
          ),
        ),
      ),
    );
  }

  String latestLabel = '';
}

class GalleryExampleItemThumbnail extends StatelessWidget {
  GalleryExampleItemThumbnail({
    Key key,
    this.galleryExampleItem,
    this.onTap,
  }) : super(key: key);

  final GalleryExampleItem galleryExampleItem;

  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 4;
    return Container(
      child: FutureBuilder(
        future: galleryExampleItem.loaded
            ? Future.value(1)
            : Future.delayed(Duration(milliseconds: 1000)).then((value) => 1),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return SizedBox(
              height:
                  galleryExampleItem.loaded ? galleryExampleItem.height : 300.0,
              child: Center(
                child: SizedBox(
                  child: CircularProgressIndicator(),
                  width: 30,
                  height: 30,
                ),
              ),
            );
          }
          return FutureBuilder(
            future: _calculateImageDimension(),
            builder: (context, AsyncSnapshot<Size> snapshot) {
              if (snapshot.hasData) {
                galleryExampleItem.loaded = true;
                galleryExampleItem.height = width / snapshot.data.aspectRatio;
              }
              return SizedBox(
                height: galleryExampleItem.loaded
                    ? galleryExampleItem.height
                    : 300.0,
                // child: GestureDetector(
                // onTap: onTap,
                child: Hero(
                  tag: galleryExampleItem.id.toString(),
                  child: CachedNetworkImage(
                    // galleryExampleItem.url,
                    // headers: galleryExampleItem.headers,
                    // height: galleryExampleItem.loaded
                    //     ? galleryExampleItem.height
                    //     : 300.0,
                    // // cacheWidth: width.toInt(),
                    // // placeholder: (context, url) => Center(
                    // //   child: SizedBox(
                    // //     child: CircularProgressIndicator(),
                    // //     width: 30,
                    // //     height: 30,
                    // //   ),
                    // // ),
                    // // placeholderFadeInDuration: Duration(microseconds: 500),
                    // // fadeInDuration: Duration(microseconds: 500),
                    // // fadeInCurve: Curves.easeIn,
                    // // fit: BoxFit.fill,
                    // loadingBuilder: (context, child, progress) {
                    //   if (progress == null) return child;
                    //   return Center(
                    //     child: SizedBox(
                    //       child: CircularProgressIndicator(
                    //           value: 1.0 *
                    //               progress.cumulativeBytesLoaded /
                    //               progress.expectedTotalBytes),
                    //       width: 30,
                    //       height: 30,
                    //     ),
                    //   );
                    // },
                    // memCacheWidth: width.toInt(),
                    // memCacheHeight: ,
                    imageUrl: galleryExampleItem.url,
                    httpHeaders: galleryExampleItem.headers,
                    // placeholder: (context, url) => Center(
                    //   child: SizedBox(
                    //     child: CircularProgressIndicator(),
                    //     width: 30,
                    //     height: 30,
                    //   ),
                    // ),
                    // placeholderFadeInDuration: Duration(microseconds: 500),
                    fadeInDuration: Duration(microseconds: 500),
                    fadeInCurve: Curves.easeIn,
                    progressIndicatorBuilder: (context, string, progress) {
                      return Center(
                        child: SizedBox(
                          child: CircularProgressIndicator(
                              value: progress.progress),
                          width: 30,
                          height: 30,
                        ),
                      );
                    },
                  ),
                  //   ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Size> _calculateImageDimension() async {
    Completer<Size> completer = Completer();
    Image image = new Image(
        image: CachedNetworkImageProvider(galleryExampleItem.url,
            headers: galleryExampleItem.headers));
    // Image image = new Image.network(
    // galleryExampleItem.url,
    // headers: galleryExampleItem.headers,
    // );

    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          if (!completer.isCompleted) completer.complete(size);
        },
      ),
    );
    return completer.future;
  }
}
