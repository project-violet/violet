// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

// 네트워크 이미지들을 보기위한 위젯

//import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:violet/widgets/flutter_scrollable_positioned_list_with_draggable_scrollbar.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ViewerWidget extends StatefulWidget {
  final List<String> urls;
  final Map<String, String> headers;
  final String id;

  ViewerWidget({this.urls, this.headers, this.id});

  @override
  _ViewerWidgetState createState() => _ViewerWidgetState();
}

class _ViewerWidgetState extends State<ViewerWidget> {
  List<GalleryExampleItem> galleryItems;
  //List<GlobalKey> moveKey;

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
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    // 지금 인덱스랑 다르면 그쪽으로 이동시킴
    //if (w.currentIndex != index)
    //  Scrollable.ensureVisible(moveKey[w.currentIndex].currentContext,
    //      alignment: 0.5);
    if (w.currentIndex != index)
      isc.scrollTo(
        index: w.currentIndex,
        duration: Duration(microseconds: 500),
        alignment: 0.1,
      );
  }

  ScrollController sc = ScrollController();
  ScrollController sc1 = ScrollController();
  ItemScrollController isc = ItemScrollController();

  @override
  Widget build(BuildContext context) {
    //List<Widget> ww = List<Widget>();
    // List<GalleryExampleItem> galleryItems;
    // List<GlobalKey> moveKey;
    galleryItems = new List<GalleryExampleItem>();
    //moveKey = new List<GlobalKey>();
    // int i = 0;
    // for (var link in widget.urls) {
    //   galleryItems.add(
    //       GalleryExampleItem(id: link, url: link, headers: widget.headers));
    //   moveKey.add(new GlobalKey());
    //   int j = i;
    //   ww.add(
    //     Container(
    //       padding: EdgeInsets.all(2),
    //       decoration: BoxDecoration(
    //         color: const Color(0xff444444),
    //       ),
    //       child: GalleryExampleItemThumbnail(
    //         galleryExampleItem: galleryItems[j],
    //         onTap: () {
    //           print(j);
    //           open(context, j);
    //         },
    //         key: moveKey[j],
    //       ),
    //     ),
    //   );
    //   i++;
    // }

    //DraggableScrollbar.semicircle()

    // return Container(
    //   child: Scrollbar(
    //       child: SingleChildScrollView(
    //           child: Container(
    //               child: Center(
    //                   child: Column(
    //     mainAxisAlignment: MainAxisAlignment.center,
    //     children: ww,
    //   ))))),
    // );

    for (int i = 0; i < widget.urls.length; i++) {
      galleryItems.add(GalleryExampleItem(
          id: i == 0 ? 'thumbnail' + widget.id : widget.urls[i],
          url: widget.urls[i],
          headers: widget.headers));
      //moveKey.add(new GlobalKey());
    }

    print(galleryItems.length);
    return Container(
      //child: SingleChildScrollView(
      //  child: SingleChildScrollView(
      //      child: Container(
      //          child: Center(
      //              child: Column(
      //mainAxisAlignment: MainAxisAlignment.center,
      //children: ww,
      //rcontroller: null,
      //child: DraggableScrollbar.semicircle(
      //  labelTextBuilder: (double offset) => Text("${offset ~/ 100}"),
      //  controller: isc,
      color: const Color(0xff444444),
      child: Scrollbar(
        child: ScrollablePositionedList.builder(
          itemCount: widget.urls.length,
          //itemExtent: 100.0,
          minCacheExtent: 100,
          //shrinkWrap: true,
          // /,

          //controller: sc,
          itemScrollController: isc,

          itemBuilder: (context, index) {
            //return Container(child: Text('asdf'));

            //galleryItems.add(GalleryExampleItem(
            //    id: widget.urls[index],
            //    url: widget.urls[index],
            //    headers: widget.headers));
            //moveKey.add(new GlobalKey());
            //print('asdf');
            //int j = i;
            //ww.add(
            return Container(
              padding: EdgeInsets.all(2),
              // decoration: BoxDecoration(
              //   color: const Color(0xff444444),
              // ),
              child: GalleryExampleItemThumbnail(
                galleryExampleItem: galleryItems[index],
                onTap: () => open(context, index),
                //key: moveKey[index],
              ),
            );
          },
        ),
      ),
      //),
    );

    // return Container(
    //   //child: Scrollbar(
    //     //child: SingleChildScrollView(
    //       child: DraggableScrollbar.rrect(
    //         controller: sc,
    //         child: ListView.builder(
    //             controller: sc1,
    //             itemCount: 1,
    //             itemBuilder: (context, index) {
    //               return Column(
    //                 mainAxisAlignment: MainAxisAlignment.center,
    //                 children: ww,
    //               );
    //             }),
    //       ),
    //     //),
    //   //),
    // );
  }
}

class GalleryExampleItem {
  GalleryExampleItem({this.id, this.url, this.headers, this.isSvg = false});

  final String id;
  final String url;
  final Map<String, String> headers;
  final bool isSvg;
}

class GalleryExampleItemThumbnail extends StatelessWidget {
  const GalleryExampleItemThumbnail(
      {Key key, this.galleryExampleItem, this.onTap})
      : super(key: key);

  final GalleryExampleItem galleryExampleItem;

  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    // print(galleryExampleItem.url);
    return Container(
      child: VisibilityDetector(
        key: Key(galleryExampleItem.url),
        onVisibilityChanged: (info) {
          //print(info.toString());
        },
        child: ConstrainedBox(
          constraints: new BoxConstraints(
            minHeight: 100.0,
            //maxHeight: 100.0,
          ),
          //padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: GestureDetector(
            onTap: onTap,
            child: Hero(
              tag: galleryExampleItem.id.toString(),
              //child: Image.network(galleryExampleItem.url,
              //    headers: galleryExampleItem.headers),
              // child: FadeInImage(
              //   image: NetworkImage(
              //     galleryExampleItem.url,
              //     headers: galleryExampleItem.headers,
              //   ),
              //   placeholder: AssetImage('assets/images/loading.gif'),
              // )),
              child: CachedNetworkImage(
                  imageUrl: galleryExampleItem.url,
                  httpHeaders: galleryExampleItem.headers,
                  placeholder: (context, url) => Container(
                        padding: EdgeInsets.fromLTRB(150, 150, 150, 150),
                        child: CircularProgressIndicator(),
                      ),
                  placeholderFadeInDuration: Duration(microseconds: 500),
                  fadeInDuration: Duration(microseconds: 500),
                  fadeInCurve: Curves.easeIn,
                  progressIndicatorBuilder: (context, string, progress) {
                    //print(string);
                    return CircularProgressIndicator();
                  }
                  //height: 100,
                  //(context, url) => Image.file(File('assets/images/loading.gif')),
                  ),
            ),
          ),
        ),
      ),
    );
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
