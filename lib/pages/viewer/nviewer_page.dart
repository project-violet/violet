// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';

int currentPage = 0;

class NViewerPage extends StatelessWidget {
  NViewerPage();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, currentPage);
        return new Future(() => false);
      },
      // child: AnnotatedRegion<SystemUiOverlayStyle>(
      //   value: SystemUiOverlayStyle(
      //     statusBarColor: Colors.transparent,
      //     systemNavigationBarColor: Colors.transparent,
      //   ),
      //   sized: false,
      //   child: Scaffold(
      //     resizeToAvoidBottomInset: false,
      //     resizeToAvoidBottomPadding: false,
      //     body: _VerticalImageViewer(),
      //   ),
      // ),
      child: _VerticalImageViewer(),
    );
  }
}

class _VerticalImageViewer extends StatefulWidget {
  @override
  __VerticalImageViewerState createState() => __VerticalImageViewerState();
}

class __VerticalImageViewerState extends State<_VerticalImageViewer> {
  ViewerPageProvider _pageInfo;
  Timer clearTimer;
  List<bool> _loaded;
  List<double> _cachedHeight;

  @override
  void initState() {
    super.initState();

    clearTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      imageCache.clearLiveImages();
      imageCache.clear();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageInfo = Provider.of<ViewerPageProvider>(context);
    _loaded = List<bool>.filled(_pageInfo.uris.length, false);
    _cachedHeight = List<double>.filled(_pageInfo.uris.length, 0);
  }

  @override
  void dispose() {
    clearTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Stack(children: <Widget>[
      ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _pageInfo.uris.length,
        cacheExtent: height * 2,
        itemBuilder: (context, index) {
          return _networkImageItem(index);
        },
      ),
      _touchArea(),
    ]);
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
              SystemChrome.setEnabledSystemUIOverlays(
                  [SystemUiOverlay.bottom, SystemUiOverlay.top]);
            } else {
              SystemChrome.setEnabledSystemUIOverlays([]);
            }
            _overlayOpend = !_overlayOpend;
          },
        ),
      ),
    );
  }

  _networkImageItem(index) {
    final width = MediaQuery.of(context).size.width - 4;
    return FutureBuilder(
      future: _loaded[index]
          ? Future.value(1)
          : Future.delayed(Duration(milliseconds: 1000)).then((value) => 1),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: _loaded[index] ? _cachedHeight[index] : 300.0,
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
          future: _calculateImageDimension(_pageInfo.uris[index]),
          builder: (context, AsyncSnapshot<Size> snapshot) {
            if (snapshot.hasData) {
              _loaded[index] = true;
              _cachedHeight[index] = width / snapshot.data.aspectRatio;
            }
            return SizedBox(
              height: _loaded[index] ? _cachedHeight[index] : 300.0,
              width: width,
              child: CachedNetworkImage(
                height: _loaded[index] ? _cachedHeight[index] : 300.0,
                width: width,
                imageUrl: _pageInfo.uris[index],
                httpHeaders: _pageInfo.headers,
                fit: BoxFit.cover,
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
            );
          },
        );
      },
    );
  }

  Future<Size> _calculateImageDimension(String url) async {
    Completer<Size> completer = Completer();
    Image image = new Image(
        image: CachedNetworkImageProvider(url, headers: _pageInfo.headers));
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
