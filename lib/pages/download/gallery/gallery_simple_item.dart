// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:violet/pages/download/gallery/gallery_item.dart';

class GallerySimpleItem extends StatefulWidget {
  final GalleryItem item;
  final int size;

  GallerySimpleItem({this.item, this.size});

  @override
  _GallerySimpleItemState createState() => _GallerySimpleItemState();
}

class _GallerySimpleItemState extends State<GallerySimpleItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: widget.item == null
          ? Container()
          : widget.item.isPhoto
              ? Stack(
                  children: <Widget>[
                    Hero(
                        tag: Key('gallery-' + widget.item.path),
                        child: Image.file(
                          File(widget.item.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          isAntiAlias: true,
                          cacheWidth: widget.size,
                          filterQuality: FilterQuality.high,
                        )),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GalleryPhotoViewWrapper(
                                  galleryItems: widget.item.files,
                                  backgroundDecoration: const BoxDecoration(
                                    color: Colors.black,
                                  ),
                                  minScale: 1.0,
                                  maxScale: 3.0,
                                  initialIndex: widget.item.filesIndex,
                                  scrollDirection: Axis.horizontal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  ],
                )
              : InkWell(
                  child: Center(
                    child: Icon(
                      MdiIcons.movieOpen,
                    ),
                  ),
                  onTap: () {
                    OpenFile.open(widget.item.path);
                  },
                ),
    );
  }
}

class GalleryPhotoViewWrapper extends StatefulWidget {
  GalleryPhotoViewWrapper({
    this.loadingBuilder,
    this.backgroundDecoration,
    this.minScale,
    this.maxScale,
    this.initialIndex,
    @required this.galleryItems,
    this.scrollDirection = Axis.horizontal,
  }) : pageController = PageController(initialPage: initialIndex);

  final LoadingBuilder loadingBuilder;
  final Decoration backgroundDecoration;
  final dynamic minScale;
  final dynamic maxScale;
  final int initialIndex;
  final PageController pageController;
  final List<String> galleryItems;
  final Axis scrollDirection;

  @override
  State<StatefulWidget> createState() {
    return _GalleryPhotoViewWrapperState();
  }
}

class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper> {
  int currentIndex;

  @override
  void initState() {
    currentIndex = widget.initialIndex;
    super.initState();
  }

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
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
            ),
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "${currentIndex + 1}/${widget.galleryItems.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17.0,
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
    final String item = widget.galleryItems[index];
    return PhotoViewGalleryPageOptions(
      imageProvider: FileImage(File(item)),
      initialScale: PhotoViewComputedScale.contained,
      // minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
      // maxScale: PhotoViewComputedScale.covered * 1.1,
      // initialScale: 1.0,
      // minScale: widget.minScale,
      // maxScale: widget.maxScale,
      heroAttributes: PhotoViewHeroAttributes(tag: Key('gallery-' + item)),
    );
  }
}
