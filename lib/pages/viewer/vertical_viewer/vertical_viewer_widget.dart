// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

// 네트워크 이미지들을 보기위한 위젯

//import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_statusbar_manager/flutter_statusbar_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/viewer/vertical_viewer/vertical_holder.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/gallery_image_item.dart';
import 'package:violet/pages/viewer/horizontal_viewer_widget.dart';

class ViewerWidget extends StatefulWidget {
  final List<String> urls;
  final Map<String, String> headers;
  final String id;
  List<GalleryImageItem> galleryItems;

  ViewerWidget({this.urls, this.headers, this.id}) {
    galleryItems = new List<GalleryImageItem>();

    for (int i = 0; i < urls.length; i++) {
      galleryItems.add(GalleryImageItem(
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
    // SystemChrome.setEnabledSystemUIOverlays([]);
    super.initState();

    scroll.addListener(() async {
      currentPage = offset2Page(scroll.offset);
      if (prevPage != currentPage) {
        // prevPage = 0;
        // print(currentPage);
        // print("cc: " + imageCache.currentSizeBytes.toString());
        // print("ss: " + imageCache.liveImageCount.toString());
        // var evictStarts = min(0, currentPage - 5);
        // var evictEnds = max(currentPage + 5, widget.urls.length);
        // for (int i = 0; i < evictStarts; i++) {
        //   await CachedNetworkImageProvider(widget.urls[i]).evict();
        //   final key = CachedNetworkImageProvider(widget.urls[i])
        //       .obtainKey(ImageConfiguration.empty);
        //   imageCache.maximumSizeBytes = 500 * 1024 * 1024;
        //   // imageCache.putIfAbsent(key, () => null);
        //   imageCache.evict(key);
        // }
        // for (int i = evictEnds; i < widget.urls.length; i++) {
        //   await CachedNetworkImageProvider(widget.urls[i]).evict();
        //   final key = CachedNetworkImageProvider(widget.urls[i])
        //       .obtainKey(ImageConfiguration.empty);
        //   imageCache.maximumSizeBytes = 500 * 1024 * 1024;
        //   // imageCache.putIfAbsent(key, () => null);
        //   imageCache.evict(key);
        // }
        // print("ee: " + imageCache.liveImageCount.toString());
        // void provider1 = CachedNetworkImageProvider(widget.urls[0]);
        // final key = await provider1.obtainKey(ImageConfiguration.empty);
        // final key = CachedNetworkImageProvider(widget.urls[0])
        //     .obtainKey(ImageConfiguration.empty);
        // imageCache.maximumSizeBytes = 500 * 1024 * 1024;
        // imageCache.putIfAbsent(key, () => null);
        // imageCache.clearLiveImages();
        // imageCache.clear();
        prevPage = currentPage;
        setState(() {
          page = currentPage;
        });
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

    clearTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      imageCache.clearLiveImages();
      imageCache.clear();
    });
  }

  Timer clearTimer;

  @override
  void dispose() {
    scroll.dispose();
    _controller.dispose();
    clearTimer.cancel();

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
    print('asdf');

    final height = MediaQuery.of(context).size.height;

    // var ll = List<Widget>();

    // widget.galleryItems.forEach((element) {
    //   ll.add(VerticalViewerHolder(
    //     galleryExampleItem: element,
    //     // onTap: () => _transToGalleryView(context, index),
    //   ));
    // });

    return
        //Scaffold(
        //  resizeToAvoidBottomInset: false,
        //  resizeToAvoidBottomPadding: false,
//
        //  body:
        //      //  SafeArea(
        //      //   child:
        Stack(
      children: <Widget>[
        // ZoomableWidget(
        //   maxScale: 5.0,
        //   minScale: 0.5,
        //   multiFingersPan: false,
        //   // autoCenter: true,
        //   child: Container(
        //     color: const Color(0xff444444),
        //     child: ListView.builder(
        //       itemCount: widget.urls.length,
        //       controller: scroll,
        //       cacheExtent: height * 4,
        //       itemBuilder: (context, index) {
        //         return Container(
        //           child: GalleryExampleItemThumbnail(
        //             galleryExampleItem: widget.galleryItems[index],
        //             onTap: () => _transToGalleryView(context, index),
        //           ),
        //         );
        //       },
        //     ),
        //   ),
        // ),
        // ListView.builder(
        //   itemCount: widget.urls.length,
        //   controller: scroll,
        //   cacheExtent: height * 2,
        //   itemBuilder: (context, index) {
        //     return Container(
        //       child: VerticalViewerHolder(
        //         galleryExampleItem: widget.galleryItems[index],
        //         onTap: () => _transToGalleryView(context, index),
        //       ),
        //     );
        //   },
        // ),
        PhotoView.customChild(
          minScale: 1.0,
          child: Container(
            color: const Color(0xff444444),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.urls.length,
              controller: scroll,
              cacheExtent: height * 2,
              itemBuilder: (context, index) {
                return Container(
                  child: VerticalViewerHolder(
                    galleryExampleItem: widget.galleryItems[index],
                    onTap: () => _transToGalleryView(context, index),
                  ),
                );
              },
            ),
          ),
        ),
        // ZoomableWidget(
        //   child: ListView.builder(
        //     itemCount: widget.urls.length,
        //     controller: scroll,
        //     cacheExtent: height * 4,
        //     itemBuilder: (context, index) {
        //       return Container(
        //         child: GalleryExampleItemThumbnail(
        //           galleryExampleItem: widget.galleryItems[index],
        //           onTap: () => _transToGalleryView(context, index),
        //         ),
        //       );
        //     },
        //   ),
        // ),
        // ZoomableWidget(
        //   maxScale: 5.0,
        //   minScale: 0.5,
        //   multiFingersPan: false,
        // ZoomableList(
        //   maxScale: 2.0,
        //   flingFactor: 1.0,
        //   // child: ListView.builder(
        //   //   itemCount: widget.urls.length,
        //   //   controller: scroll,
        //   //   cacheExtent: height * 4,
        //   //   itemBuilder: (context, index) {
        //   //     return Container(
        //   //       child: GalleryExampleItemThumbnail(
        //   //         galleryExampleItem: widget.galleryItems[index],
        //   //         onTap: () => _transToGalleryView(context, index),
        //   //       ),
        //   //     );
        //   //   },
        //   // ),
        //   child: Column(
        //     mainAxisSize: MainAxisSize.min,
        //     children: ll,
        //     // children: <Widget>[
        //     //   Image(
        //     //       image: AdvancedNetworkImage(widget.galleryItems[0].url,
        //     //           header: widget.galleryItems[0].headers)),
        //     //   Image(
        //     //       image: AdvancedNetworkImage(widget.galleryItems[1].url,
        //     //           header: widget.galleryItems[1].headers)),
        //     //   Image(
        //     //       image: AdvancedNetworkImage(widget.galleryItems[2].url,
        //     //           header: widget.galleryItems[2].headers)),
        //     //   Image(
        //     //       image: AdvancedNetworkImage(widget.galleryItems[3].url,
        //     //           header: widget.galleryItems[3].headers)),
        //     //   Image(
        //     //       image: AdvancedNetworkImage(widget.galleryItems[4].url,
        //     //           header: widget.galleryItems[4].headers)),
        //     // ],
        //   ),
        // ),
        _touchArea(),
        // _topAppBar(),
        _bottomAppBar(),
      ],
      // ),
      // ),
    );
  }

  bool _overlayOpend = false;
  _touchArea() {
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
          onTap: () async {
            if (!_overlayOpend) {
              page = currentPage;
              if (_controller.isCompleted) {
                _controller.reverse();
              } else {
                _controller.forward();
              }
              // SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              //   statusBarColor: Colors.transparent,
              //   systemNavigationBarDividerColor: Colors.transparent,
              //   systemNavigationBarColor: Colors.transparent,
              // ));
              SystemChrome.setEnabledSystemUIOverlays(
                  [SystemUiOverlay.bottom, SystemUiOverlay.top]);
              // await FlutterStatusbarManager.setHidden(false,
              // animation: StatusBarAnimation.SLIDE);
              // await FlutterStatusbarManager.setTranslucent(true);
            } else {
              if (_controller.isCompleted) {
                _controller.reverse();
              } else {
                _controller.forward();
              }
              SystemChrome.setEnabledSystemUIOverlays([]);
              // await FlutterStatusbarManager.setHidden(true,
              // animation: StatusBarAnimation.SLIDE);
            }
            _overlayOpend = !_overlayOpend;
          },
        ),
      ),
    );
  }

  _topAppBar() {
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

  _bottomAppBar() {
    final height = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;
    final mediaQuery = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _controller.value * (128)),
        child: Container(
          // height: 128,
          padding: EdgeInsets.only(
              top: height - bottom - 128,
              bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
          child: BottomAppBar(
            color: Colors.black.withOpacity(0.2),
            child: Container(
              height: 64,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Slider(
                      value: page.toDouble(),
                      max: widget.galleryItems.length.toDouble(),
                      min: 1,
                      label: page.toString(),
                      divisions: widget.galleryItems.length,
                      onChanged: (value) {
                        scroll.jumpTo(page2Offset(page - 1) - 32);
                        setState(() {
                          page = value.toInt();
                        });
                      },
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  int page = 1;
  String latestLabel = '';
}
