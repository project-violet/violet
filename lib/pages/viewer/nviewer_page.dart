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

enum _ViewAppBarAction {
  toggleViewer,
  openInBrowser,
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
  double _opacity = 0.0;
  bool _disableBottom = false;

  @override
  void initState() {
    super.initState();

    // _clearTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    //   imageCache.clearLiveImages();
    //   imageCache.clear();
    // });

    Future.delayed(Duration(milliseconds: 100))
        .then((value) => _checkLatestRead());

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
    imageCache.clearLiveImages();
    imageCache.clear();
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
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        resizeToAvoidBottomPadding: false,
        appBar: _opacity == 1.0
            ? AppBar(
                elevation: 0.0,
                backgroundColor: Colors.black.withOpacity(0.3),
                title: Text('$_prevPage/${_pageInfo.uris.length}'),
                leading: IconButton(
                  icon: new Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context, currentPage);
                    return new Future(() => false);
                  },
                ),
                actions: [
                  PopupMenuButton<_ViewAppBarAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _ViewAppBarAction.toggleViewer:
                          // Navigator.pushNamed(context, SettingScreen.routeName);
                          break;

                        case _ViewAppBarAction.openInBrowser:
                          // tryLaunch(client.getImageUrl(image.id));
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _ViewAppBarAction.toggleViewer,
                        child: Text('Toggle to Vertical'),
                      ),
                      PopupMenuItem(
                        value: _ViewAppBarAction.openInBrowser,
                        child: Text('asdf'),
                      ),
                    ],
                  ),
                ],
              )
            : null,
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
                    return _networkImageViewTest(index);
                  },
                ),
              ),
            ),
            _touchArea(),
            !_disableBottom ? _bottomAppBar() : Container(),
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
              setState(() {
                _opacity = 1.0;
                _disableBottom = false;
              });
              SystemChrome.setEnabledSystemUIOverlays(
                  [SystemUiOverlay.bottom, SystemUiOverlay.top]);
            } else {
              setState(() {
                _opacity = 0.0;
              });
              SystemChrome.setEnabledSystemUIOverlays([]);
              Future.delayed(Duration(milliseconds: 300)).then((value) {
                setState(() {
                  _disableBottom = true;
                });
              });
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
        memCacheWidth: width.toInt(),
        imageUrl: _pageInfo.uris[index],
        httpHeaders: _pageInfo.headers,
        fit: BoxFit.cover,
        fadeInDuration: Duration(microseconds: 500),
        fadeInCurve: Curves.easeIn,
        progressIndicatorBuilder: (context, string, progress) {
          return SizedBox(
            height: 300,
            child: Center(
              child: SizedBox(
                child: CircularProgressIndicator(value: progress.progress),
                width: 30,
                height: 30,
              ),
            ),
          );
        },
      ),
    );
  }

  _networkImageViewTest(index) {
    final width = MediaQuery.of(context).size.width;
    return FutureBuilder(
      future: _calculateImageDimension(_pageInfo.uris[index]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _loaded[index] = true;
          _cachedHeight[index] = width / snapshot.data.aspectRatio;
        }
        return CachedNetworkImage(
          imageUrl: _pageInfo.uris[index],
          httpHeaders: _pageInfo.headers,
          fit: BoxFit.cover,
          fadeInDuration: Duration(microseconds: 500),
          fadeInCurve: Curves.easeIn,
          progressIndicatorBuilder: (context, string, progress) {
            return SizedBox(
              height: 300,
              child: Center(
                child: SizedBox(
                  child: CircularProgressIndicator(value: progress.progress),
                  width: 30,
                  height: 30,
                ),
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

  _bottomAppBar() {
    final height = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;
    final mediaQuery = MediaQuery.of(context);
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Duration(milliseconds: 300),
      child: Padding(
        padding: EdgeInsets.only(
            top: height -
                (mediaQuery.padding + mediaQuery.viewInsets).bottom -
                (48)),
        child: Container(
          alignment: Alignment.bottomCenter,
          // padding: EdgeInsets.only(top: height - bottom - 48),
          color: Colors.black.withOpacity(0.2),
          height: 48,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Slider(
                value: _prevPage.toDouble() > 0 ? _prevPage.toDouble() : 1,
                max: _pageInfo.uris.length.toDouble(),
                min: 1,
                label: _prevPage.toString(),
                divisions: _pageInfo.uris.length,
                onChanged: (value) {
                  _scroll.jumpTo(page2Offset(_prevPage - 1) - 96);
                  setState(() {
                    _prevPage = value.toInt();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
