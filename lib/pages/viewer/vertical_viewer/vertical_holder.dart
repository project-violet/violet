// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:violet/model/gallery_image_item.dart';

class VerticalViewerHolder extends StatelessWidget {
  VerticalViewerHolder({
    Key key,
    this.galleryExampleItem,
    this.onTap,
  }) : super(key: key);

  final GalleryImageItem galleryExampleItem;

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
                width: width,
                // child: GestureDetector(
                // onTap: onTap,
                child: Hero(
                  tag: galleryExampleItem.id.toString(),
                  child: CachedNetworkImage(
                    height: galleryExampleItem.loaded
                        ? galleryExampleItem.height
                        : 300.0,
                    width: width,
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
                    fit: BoxFit.cover,
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
