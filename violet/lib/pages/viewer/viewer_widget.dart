// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

// 네트워크 이미지들을 보기위한 위젯

//import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/settings.dart';
import 'package:violet/database/user/user.dart';
import 'package:violet/widgets/flutter_scrollable_positioned_list_with_draggable_scrollbar.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ViewerWidget extends StatelessWidget {
  final List<String> urls;
  final Map<String, String> headers;
  final String id;

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

    scroll.addListener(() {
      currentPage = offset2Page(scroll.offset);
    });
  }

  List<GalleryExampleItem> galleryItems;

  void open(BuildContext context, final int index) async {
    var w = GalleryPhotoViewWrapper(
      galleryItems: galleryItems,
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      totalPage: galleryItems.length,
      initialIndex: index,
      scrollDirection: Axis.horizontal,
    );
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => w),
    );
    SystemChrome.setEnabledSystemUIOverlays([]);
    // 지금 인덱스랑 다르면 그쪽으로 이동시킴
    //if (w.currentIndex != index)
    //  Scrollable.ensureVisible(moveKey[w.currentIndex].currentContext,
    //      alignment: 0.5);
    if (w.currentIndex != index) {
      scroll.jumpTo(page2Offset(w.currentIndex));
    }
    // isc.scrollTo(
    //   index: w.currentIndex,
    //   duration: Duration(microseconds: 500),
    //   alignment: 0.1,
    // );
  }

  int offset2Page(double offset) {
    double xx = 0.0;
    for (int i = 0; i < galleryItems.length; i++) {
      xx += galleryItems[i].loaded ? galleryItems[i].height : 300;
      xx += 4;
      if (offset < xx) {
        return i + 1;
      }
    }
    return galleryItems.length;
  }

  double page2Offset(int page) {
    double xx = 0.0;
    for (int i = 0; i < page; i++) {
      xx += galleryItems[i].loaded ? galleryItems[i].height : 300;
      xx += 4;
    }
    return xx;
  }

  int currentPage = 0;

  ScrollController scroll = ScrollController();

  bool once = false;

  @override
  Widget build(BuildContext context) {
    if (once == false) {
      once = true;
      User.getInstance().then((value) => value.getUserLog().then((value) async {
            var x = value.where((e) => e.articleId().toString() == this.id);
            if (x.length < 2) return;
            var e = x.elementAt(1);
            if (e.lastPage() == null) return;
            if (e.lastPage() > 1 &&
                DateTime.parse(e.datetimeStart())
                        .difference(DateTime.now())
                        .inDays <
                    7) {
              if (await Dialogs.yesnoDialog(context,
                  '이전에 ${e.lastPage()}페이지까지 읽었던 기록이 있습니다. 이어서 읽을까요?', '기록')) {
                scroll.jumpTo(page2Offset(e.lastPage() - 1));
              }
            }
          }));
    }
    return Container(
      color: const Color(0xff444444),
      // child: Scrollbar(
      //   controller: scroll,
      //   child: ScrollablePositionedList.builder(
      //     itemCount: urls.length,
      //     minCacheExtent: 100,
      //     itemScrollController: isc,
      //     itemBuilder: (context, index) {
      //       return Container(
      //         padding: EdgeInsets.all(2),
      //         child: GalleryExampleItemThumbnail(
      //           galleryExampleItem: galleryItems[index],
      //           onTap: () => open(context, index),
      //         ),
      //       );
      //     },
      //   ),
      // ),
      // child: DraggableScrollbar.arrows(
      //   backgroundColor: Settings.themeWhat ? Colors.black : Colors.white,
      //   controller: scroll,
      //   labelTextBuilder: (double offset) => Text("${offset2Page(offset)}"),
      //   child: ListView.builder(
      //     itemCount: urls.length,
      //     controller: scroll,
      //     itemBuilder: (context, index) {
      //       return Container(
      //         padding: EdgeInsets.all(2),
      //         child: GalleryExampleItemThumbnail(
      //           galleryExampleItem: galleryItems[index],
      //           onTap: () => open(context, index),
      //         ),
      //       );
      //     },
      //   ),
      // ),
      child: DraggableScrollbar(
        backgroundColor: Settings.themeWhat ? Colors.black : Colors.white,
        controller: scroll,
        labelTextBuilder: (double offset) => Text("${offset2Page(offset)}"),
        child: ListView.builder(
          itemCount: urls.length,
          controller: scroll,
          itemBuilder: (context, index) {
            return Container(
              padding: EdgeInsets.all(2),
              child: GalleryExampleItemThumbnail(
                galleryExampleItem: galleryItems[index],
                onTap: () => open(context, index),
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
              labelText.data.trim() != '') latestLabel = labelText.data;
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
    );
  }

  String latestLabel = '';
}

class GalleryExampleItem {
  GalleryExampleItem(
      {this.id,
      this.url,
      this.headers,
      this.isSvg = false,
      this.loaded = false});

  final String id;
  final String url;
  final Map<String, String> headers;
  final bool isSvg;
  double height;
  bool loaded;
}

class GalleryExampleItemThumbnail extends StatelessWidget {
  GalleryExampleItemThumbnail({Key key, this.galleryExampleItem, this.onTap})
      : super(key: key);

  final GalleryExampleItem galleryExampleItem;

  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 4;
    return Container(
      child: FutureBuilder(
        future: _calculateImageDimension(),
        builder: (context, AsyncSnapshot<Size> snapshot) {
          if (snapshot.hasData) {
            galleryExampleItem.loaded = true;
            galleryExampleItem.height = width / snapshot.data.aspectRatio;
          }
          return SizedBox(
            height:
                galleryExampleItem.loaded ? galleryExampleItem.height : 300.0,
            child: GestureDetector(
              onTap: onTap,
              child: Hero(
                tag: galleryExampleItem.id.toString(),
                child: CachedNetworkImage(
                  imageUrl: galleryExampleItem.url,
                  httpHeaders: galleryExampleItem.headers,
                  placeholder: (context, url) => Center(
                    child: SizedBox(
                      child: CircularProgressIndicator(),
                      width: 30,
                      height: 30,
                    ),
                  ),
                  placeholderFadeInDuration: Duration(microseconds: 500),
                  fadeInDuration: Duration(microseconds: 500),
                  fadeInCurve: Curves.easeIn,
                  progressIndicatorBuilder: (context, string, progress) {
                    return Center(
                      child: SizedBox(
                        child:
                            CircularProgressIndicator(value: progress.progress),
                        width: 30,
                        height: 30,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Size> _calculateImageDimension() {
    Completer<Size> completer = Completer();
    Image image = new Image(
        image: CachedNetworkImageProvider(
            galleryExampleItem.url)); // I modified this line
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

  // Widget get(BuildContext context, String string, DownloadProgress progress) {

  // }
}

class GalleryPhotoViewWrapper extends StatefulWidget {
  GalleryPhotoViewWrapper({
    this.loadingBuilder,
    this.backgroundDecoration,
    this.initialIndex,
    @required this.galleryItems,
    this.totalPage,
    this.scrollDirection = Axis.horizontal,
  }) : pageController = PageController(initialPage: initialIndex);

  final LoadingBuilder loadingBuilder;
  final Decoration backgroundDecoration;
  final int initialIndex;
  final PageController pageController;
  final List<GalleryExampleItem> galleryItems;
  final Axis scrollDirection;
  final int totalPage;
  int currentIndex;

  @override
  State<StatefulWidget> createState() {
    return _GalleryPhotoViewWrapperState();
  }
}

class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper> {
  @override
  void initState() {
    widget.currentIndex = widget.initialIndex;
    super.initState();
  }

  void onPageChanged(int index) {
    setState(() {
      widget.currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: widget.backgroundDecoration,
        constraints: BoxConstraints.expand(
          height: MediaQuery.of(context).size.height,
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: <Widget>[
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: _buildItem,
              itemCount: widget.galleryItems.length,
              loadingBuilder: widget.loadingBuilder,
              backgroundDecoration: widget.backgroundDecoration,
              pageController: widget.pageController,
              onPageChanged: onPageChanged,
              scrollDirection: widget.scrollDirection,
              reverse: true,
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "${widget.currentIndex + 1}/${widget.totalPage}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                  decoration: null,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    final GalleryExampleItem item = widget.galleryItems[index];
    return PhotoViewGalleryPageOptions(
      imageProvider: CachedNetworkImageProvider(
        item.url,
        headers: item.headers,
        //(context, url) => Image.file(File('assets/images/loading.gif')),
      ),
      // NetworkImage(item.url, headers: item.headers),
      initialScale: PhotoViewComputedScale.contained,
      //minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
      //maxScale: PhotoViewComputedScale.covered * 1.1,
      minScale: PhotoViewComputedScale.contained * 1.0,
      maxScale: PhotoViewComputedScale.contained * 5.0,
      heroAttributes: PhotoViewHeroAttributes(tag: item.id),
    );
  }
}
