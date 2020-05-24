// 네트워크 이미지들을 보기위한 위젯

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ViewerWidget extends StatefulWidget {
  final List<String> urls;
  final Map<String, String> headers;

  ViewerWidget({this.urls, this.headers});

  @override
  _ViewerWidgetState createState() => _ViewerWidgetState();
}

class _ViewerWidgetState extends State<ViewerWidget> {
  List<GalleryExampleItem> galleryItems;
  List<GlobalKey> moveKey;

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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => w),
    );
    // 지금 인덱스랑 다르면 그쪽으로 이동시킴
    if (w.currentIndex != index)
      Scrollable.ensureVisible(moveKey[w.currentIndex].currentContext,
          alignment: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> ww = List<Widget>();
    galleryItems = new List<GalleryExampleItem>();
    moveKey = new List<GlobalKey>();
    int i = 0;
    for (var link in widget.urls) {
      galleryItems
          .add(GalleryExampleItem(id: link, url: link, headers: widget.headers));
      moveKey.add(new GlobalKey());
      int j = i;
      ww.add(
        Container(
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xff444444),
          ),
          child: GalleryExampleItemThumbnail(
            galleryExampleItem: galleryItems[j],
            onTap: () {
              print(j);
              open(context, j);
            },
            key: moveKey[j],
          ),
        ),
      );
      i++;
    }

    return Container(
      child: Scrollbar(
          child: SingleChildScrollView(
              child: Container(
                  child: Center(
                      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ww,
      ))))),
    );
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
    return Container(
      //padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: galleryExampleItem.id.toString(),
          child: Image.network(galleryExampleItem.url,
              headers: galleryExampleItem.headers),
        ),
      ),
    );
  }
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
      imageProvider: NetworkImage(item.url, headers: item.headers),
      initialScale: PhotoViewComputedScale.contained,
      //minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
      //maxScale: PhotoViewComputedScale.covered * 1.1,
      minScale: PhotoViewComputedScale.contained * 1.0,
      maxScale: PhotoViewComputedScale.contained * 3.0,
      heroAttributes: PhotoViewHeroAttributes(tag: item.id),
    );
  }
}