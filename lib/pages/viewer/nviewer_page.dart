// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
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
      child: _VerticalImageViewer(),
    );
  }
}

class _VerticalImageViewer extends StatefulWidget {
  @override
  __VerticalImageViewerState createState() => __VerticalImageViewerState();
}

class __VerticalImageViewerState extends State<_VerticalImageViewer>
    with SingleTickerProviderStateMixin {
  ViewerPageProvider _pageInfo;
  Timer _clearTimer;
  List<bool> _loaded;
  List<double> _cachedHeight;
  ScrollController _scroll = ScrollController();
  int _prevPage = 1;
  AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // _clearTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    //   imageCache.clearLiveImages();
    //   imageCache.clear();
    // });

    _scroll.addListener(() async {
      currentPage = offset2Page(_scroll.offset);
      if (_prevPage != currentPage) {
        if (currentPage > 0) {
          setState(() {
            _prevPage = currentPage;
          });
        }
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
      _checkLatestRead();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageInfo = Provider.of<ViewerPageProvider>(context);
    _loaded = List<bool>.filled(_pageInfo.uris.length, false);
    _cachedHeight = List<double>.filled(_pageInfo.uris.length, -1);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _clearTimer.cancel();
    PaintingBinding.instance.imageCache.clear();
    _pageInfo.uris.forEach((element) async {
      await CachedNetworkImageProvider(element).evict();
    });
    SystemChrome.setEnabledSystemUIOverlays([
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    super.dispose();
  }

  void _checkLatestRead() {
    User.getInstance().then((value) => value.getUserLog().then((value) async {
          var x = value.where((e) => e.articleId() == _pageInfo.id.toString());
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
              _scroll.jumpTo(page2Offset(e.lastPage() - 1));
            }
          }
        }));
  }

  int offset2Page(double offset) {
    double xx = 0.0;
    for (int i = 0; i < _cachedHeight.length; i++) {
      xx += _loaded[i] ? _cachedHeight[i] : 300;
      xx += 4;
      if (offset < xx) {
        return i + 1;
      }
    }
    return _cachedHeight.length;
  }

  double page2Offset(int page) {
    double xx = 0.0;
    for (int i = 0; i < page; i++) {
      xx += _loaded[i] ? _cachedHeight[i] : 300;
    }
    return xx;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      sized: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        resizeToAvoidBottomPadding: false,
        body: Stack(
          children: <Widget>[
            PhotoView.customChild(
              minScale: 1.0,
              child: Container(
                color: const Color(0xff444444),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _pageInfo.uris.length,
                  controller: _scroll,
                  cacheExtent: height * 2,
                  itemBuilder: (context, index) {
                    return _networkImageItem(index);
                  },
                ),
              ),
            ),
            _touchArea(),
            _bottomAppBar(),
          ],
        ),
      ),
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
              _prevPage = currentPage;
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

  _networkImageItem(index) {
    final width = MediaQuery.of(context).size.width - 4;

    if (_loaded[index] && _cachedHeight[index] >= 0) {
      return _neworkImageView(index);
    }

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
            return _neworkImageView(index);
          },
        );
      },
    );
  }

  _neworkImageView(index) {
    final width = MediaQuery.of(context).size.width - 4;
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
              child: CircularProgressIndicator(value: progress.progress),
              width: 30,
              height: 30,
            ),
          );
        },
      ),
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
                      value: _prevPage.toDouble(),
                      max: _pageInfo.uris.length.toDouble(),
                      min: 1,
                      label: _prevPage.toString(),
                      divisions: _pageInfo.uris.length,
                      onChanged: (value) {
                        _scroll.jumpTo(page2Offset(_prevPage - 1) - 32);
                        setState(() {
                          _prevPage = value.toInt();
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
}
