// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:tuple/tuple.dart';
import 'package:optimized_cached_image/optimized_cached_image.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/viewer/others/photo_view_gallery.dart';
import 'package:violet/pages/viewer/others/preload_page_view.dart';
import 'package:violet/pages/viewer/v_optimized_cached_image.dart';
import 'package:violet/pages/viewer/viewer_gallery.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/pages/viewer/viewer_setting_panel.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

int currentPage = 0;
const volumeKeyChannel = const EventChannel('xyz.project.violet/volume');

class ViewerPage extends StatelessWidget {
  ViewerPage();

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
  int _prevPage = 1;
  double _opacity = 0.0;
  bool _disableBottom = true;
  PreloadPageController _pageController = PreloadPageController();
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  bool _sliderOnChange = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100))
        .then((value) => _checkLatestRead());

    itemPositionsListener.itemPositions.addListener(() {
      if (_sliderOnChange) return;
      var v = itemPositionsListener.itemPositions.value.toList();
      var selected;

      v.sort((x, y) => x.itemLeadingEdge.compareTo(y.itemLeadingEdge));

      for (var e in v) {
        if (e.itemLeadingEdge <= 0.125) {
          selected = e.index;
        } else {
          break;
        }
      }

      if (selected != null && _prevPage != selected + 1) {
        setState(() {
          _prevPage = selected + 1;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageInfo = Provider.of<ViewerPageProvider>(context);
    volumeKeyChannel.receiveBroadcastStream().listen((event) {
      if (event as String == 'down') {
        _rightButtonEvent();
      } else if (event as String == 'up') {
        _leftButtonEvent();
      }
    });

    // _pageInfo.uris.forEach((element) {
    //   print("'$element',");
    // });
  }

  @override
  void dispose() {
    if (_clearTimer != null) _clearTimer.cancel();
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
              if (!Settings.isHorizontal) {
                // _scroll.jumpTo(page2Offset(e.lastPage() - 1));
                itemScrollController.jumpTo(
                    index: e.lastPage() - 1, alignment: 0.12);
              } else {
                _pageController.jumpToPage(e.lastPage() - 1);
              }
            }
          }
        }));
  }

  @override
  Widget build(BuildContext context) {
    ImageCache _imageCache = PaintingBinding.instance.imageCache;
    final mediaQuery = MediaQuery.of(context);
    if (_imageCache.currentSizeBytes >= (1024 + 256) << 20
        // || _imageCache.currentSize >= 50
        ) {
      _imageCache.clear();
      _imageCache.clearLiveImages();
    }
    // return Container(
    //   padding: EdgeInsets.only(top: statusBarHeight),
    if (Settings.disableFullScreen) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        resizeToAvoidBottomPadding: false,
        // appBar: _opacity == 1.0
        //     ? PreferredSize(
        //         preferredSize: const Size.fromHeight(100), child: _appBar())
        //     : null,
        body: Padding(
          padding: mediaQuery.padding + mediaQuery.viewInsets,
          child: Settings.isHorizontal ? _bodyHorizontal() : _bodyVertical(),
        ),
      );
    } else {
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
          // appBar: _opacity == 1.0 ? _appBar() : null,
          body: Settings.isHorizontal ? _bodyHorizontal() : _bodyVertical(),
        ),
      );
    }
  }

  _appBar() {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Duration(milliseconds: 300),
      child: Material(
        color: Colors.black.withOpacity(0.8),
        child: Container(
          padding: EdgeInsets.only(
              top: !Settings.disableFullScreen
                  ? Variables.statusBarHeight
                  : 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                alignment: Alignment.topLeft,
                icon: new Icon(Icons.arrow_back),
                color: Colors.white,
                onPressed: () {
                  Navigator.pop(context, currentPage);
                  return new Future(() => false);
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(MdiIcons.folderImage),
                      color: Colors.white,
                      onPressed: () async {
                        if (!Platform.isIOS) {
                          Navigator.of(context)
                              .push(
                            PageRouteBuilder(
                              transitionDuration: Duration(milliseconds: 500),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                var begin = Offset(0.0, 1.0);
                                var end = Offset.zero;
                                var curve = Curves.ease;

                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));

                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                              pageBuilder: (_, __, ___) =>
                                  Provider<ViewerPageProvider>.value(
                                value: _pageInfo,
                                child: ViewerGallery(),
                              ),
                            ),
                          )
                              .then(
                            (value) {
                              if (value != null) {
                                if (!Settings.isHorizontal) {
                                  itemScrollController.jumpTo(
                                      index: value, alignment: 0.12);
                                } else {
                                  _pageController.jumpToPage(value - 1);
                                }
                                currentPage = value;
                                setState(() {
                                  _prevPage = value;
                                });
                              }
                            },
                          );
                        } else {
                          Navigator.of(context)
                              .push(
                            CupertinoPageRoute(
                              builder: (_) =>
                                  Provider<ViewerPageProvider>.value(
                                value: _pageInfo,
                                child: ViewerGallery(),
                              ),
                            ),
                          )
                              .then(
                            (value) {
                              if (value != null) {
                                if (!Settings.isHorizontal) {
                                  itemScrollController.jumpTo(
                                      index: _prevPage - 1, alignment: 0.12);
                                } else {
                                  _pageController.jumpToPage(value - 1);
                                }
                                currentPage = value;
                                setState(() {
                                  _prevPage = value;
                                });
                              }
                            },
                          );
                        }
                      },
                    ),
                    // IconButton(
                    //     icon: Icon(MdiIcons.fileDownload),
                    //     color: Colors.white,
                    //     onPressed: () async {}),
                    IconButton(
                      icon: Icon(Icons.settings),
                      color: Colors.white,
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: false,
                          builder: (context) => ViewerSettingPanel(
                            viewerStyleChangeEvent: () {
                              if (Settings.isHorizontal) {
                                _pageController = new PreloadPageController(
                                    initialPage: _prevPage - 1);
                              } else {
                                var npage = _prevPage;
                                _sliderOnChange = true;
                                Future.delayed(Duration(milliseconds: 100))
                                    .then((value) {
                                  itemScrollController.jumpTo(
                                      index: npage - 1, alignment: 0.12);
                                  _sliderOnChange = false;
                                });
                              }
                              setState(() {});
                            },
                            setStateCallback: () {
                              setState(() {});
                            },
                          ),
                        );
                        return;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _bodyVertical() {
    final height = MediaQuery.of(context).size.height;

    return Stack(
      children: <Widget>[
        PhotoView.customChild(
          minScale: 1.0,
          child: Container(
            color: const Color(0xff444444),
            child: ScrollablePositionedList.builder(
              padding: EdgeInsets.zero,
              itemCount: _pageInfo.uris.length,
              itemScrollController: itemScrollController,
              itemPositionsListener: itemPositionsListener,
              minCacheExtent: height * 3.0,
              itemBuilder: (context, index) {
                if (!Settings.padding) {
                  if (_pageInfo.useWeb)
                    return _networkImageItem(index);
                  else if (_pageInfo.useFileSystem)
                    return _storageImageItem(index);
                  else if (_pageInfo.useProvider)
                    return _providerImageItem(index);
                } else {
                  if (_pageInfo.useWeb)
                    return Padding(
                      child: _networkImageItem(index),
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                    );
                  else if (_pageInfo.useFileSystem)
                    return Padding(
                      child: _storageImageItem(index),
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                    );
                  else if (_pageInfo.useProvider)
                    return Padding(
                      child: _providerImageItem(index),
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                    );
                }
                throw new Exception('Dead Reaching');
              },
            ),
          ),
        ),
        _verticalPageLabel(),
        _touchAreaMiddle(),
        !Settings.disableOverlayButton ? _touchAreaLeft() : Container(),
        !Settings.disableOverlayButton ? _touchAreaRight() : Container(),
        !_disableBottom ? _bottomAppBar() : Container(),
        !_disableBottom ? _appBar() : Container(),
      ],
    );
  }

  _bodyHorizontal() {
    return Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          constraints: BoxConstraints.expand(
            height: MediaQuery.of(context).size.height,
          ),
          child: VPhotoViewGallery.builder(
            scrollPhysics: const AlwaysScrollableScrollPhysics(),
            builder: _buildItem,
            itemCount: _pageInfo.uris.length,
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
            pageController: _pageController,
            onPageChanged: (page) async {
              currentPage = page.toInt() + 1;
              setState(() {
                _prevPage = page.toInt() + 1;
              });
              await _precache(page.toInt() - 1);
              await _precache(page.toInt() + 1);
            },
            scrollDirection:
                Settings.scrollVertical ? Axis.vertical : Axis.horizontal,
            reverse: Settings.rightToLeft,
          ),
        ),
        _verticalPageLabel(),
        _touchAreaMiddle(),
        !Settings.disableOverlayButton ? _touchAreaLeft() : Container(),
        !Settings.disableOverlayButton ? _touchAreaRight() : Container(),
        !_disableBottom ? _bottomAppBar() : Container(),
        !_disableBottom ? _appBar() : Container(),
      ],
    );
  }

  _precache(int index) async {
    if (_pageInfo.useWeb) {
      if (index < 0 || _pageInfo.uris.length <= index) return;
      await precacheImage(
        OptimizedCacheImageProvider(
          _pageInfo.uris[index],
          headers: _pageInfo.headers,
        ),
        context,
      );
    } else if (_pageInfo.useProvider) {
      if (index < 0 || _pageInfo.provider.length() <= index) return;
      if (_headerCache == null) {
        _headerCache =
            List<Map<String, String>>.filled(_pageInfo.uris.length, null);
        _urlCache = List<String>.filled(_pageInfo.uris.length, null);
      }
      if (_height == null) {
        _height = List<double>.filled(_pageInfo.uris.length, 0);
        _keys = List<GlobalKey>.generate(
            _pageInfo.uris.length, (index) => GlobalKey());
      }

      if (_headerCache[index] == null) {
        var header = await _pageInfo.provider.getHeader(index);
        _headerCache[index] = header;
      }

      if (_urlCache[index] == null) {
        var url = await _pageInfo.provider.getImageUrl(index);
        _urlCache[index] = url;
      }

      await precacheImage(
        OptimizedCacheImageProvider(
          _urlCache[index],
          headers: _headerCache[index],
        ),
        context,
      );
    }
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    if (_pageInfo.useWeb)
      return PhotoViewGalleryPageOptions(
        imageProvider: OptimizedCacheImageProvider(
          _pageInfo.uris[index],
          headers: _pageInfo.headers,
        ),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    else if (_pageInfo.useFileSystem) {
      return PhotoViewGalleryPageOptions(
        imageProvider: FileImage(File(_pageInfo.uris[index])),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    } else if (_pageInfo.useProvider) {
      return PhotoViewGalleryPageOptions.customChild(
        child: FutureBuilder(
          future: Future.sync(() async {
            if (_headerCache == null) {
              _headerCache =
                  List<Map<String, String>>.filled(_pageInfo.uris.length, null);
              _urlCache = List<String>.filled(_pageInfo.uris.length, null);
            }
            if (_height == null) {
              _height = List<double>.filled(_pageInfo.uris.length, 0);
              _keys = List<GlobalKey>.generate(
                  _pageInfo.uris.length, (index) => GlobalKey());
            }

            if (_headerCache[index] == null) {
              var header = await _pageInfo.provider.getHeader(index);
              _headerCache[index] = header;
            }

            if (_urlCache[index] == null) {
              var url = await _pageInfo.provider.getImageUrl(index);
              _urlCache[index] = url;
            }

            return Tuple2<Map<String, String>, String>(
                _headerCache[index], _urlCache[index]);
          }),
          builder: (context, snapshot) {
            if (_urlCache[index] != null && _headerCache[index] != null) {
              return PhotoView(
                imageProvider: OptimizedCacheImageProvider(
                  _urlCache[index],
                  headers: _headerCache[index],
                ),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 1.0,
                maxScale: PhotoViewComputedScale.contained * 5.0,
                gestureDetectorBehavior: HitTestBehavior.opaque,
              );
            }

            return SizedBox(
              height: 300,
              child: Center(
                child: SizedBox(
                  child: CircularProgressIndicator(),
                  width: 30,
                  height: 30,
                ),
              ),
            );
          },
        ),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 1.0,
        maxScale: PhotoViewComputedScale.contained * 5.0,
      );
    }
    throw new Exception('Dead Reaching');
  }

  bool _overlayOpend = false;
  _touchAreaMiddle() {
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
              if (!Settings.isHorizontal) _prevPage = currentPage;
              // setState(() {});
              setState(() {
                _opacity = 1.0;
                _disableBottom = false;
              });
              if (!Settings.disableFullScreen) {
                SystemChrome.setEnabledSystemUIOverlays(
                    [SystemUiOverlay.bottom, SystemUiOverlay.top]);
              }
            } else {
              setState(() {
                _opacity = 0.0;
              });
              if (!Settings.disableFullScreen) {
                SystemChrome.setEnabledSystemUIOverlays([]);
              }
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

  _touchAreaLeft() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        color: null,
        width: width / 3,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _leftButtonEvent,
        ),
      ),
    );
  }

  _leftButtonEvent() async {
    var next = Settings.rightToLeft ^ Settings.isHorizontal
        ? _prevPage - 1
        : _prevPage + 1;
    if (next < 1 || next > _pageInfo.uris.length) return;
    if (!Settings.isHorizontal) {
      if (!Settings.animation) {
        itemScrollController.jumpTo(index: next - 1, alignment: 0.12);
      } else {
        _sliderOnChange = true;
        await itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
        Future.delayed(Duration(milliseconds: 300)).then((value) {
          _sliderOnChange = false;
        });
      }
    } else {
      if (!Settings.animation) {
        _pageController.jumpToPage(next - 1);
      } else {
        _pageController.animateToPage(
          next - 1,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
    currentPage = next;
    setState(() {
      _prevPage = next;
    });
  }

  _touchAreaRight() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        color: null,
        width: width / 3,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _rightButtonEvent,
        ),
      ),
    );
  }

  _rightButtonEvent() async {
    var next = Settings.rightToLeft ^ Settings.isHorizontal
        ? _prevPage + 1
        : _prevPage - 1;
    if (next < 1 || next > _pageInfo.uris.length) return;
    if (!Settings.isHorizontal) {
      if (!Settings.animation) {
        itemScrollController.jumpTo(index: next - 1, alignment: 0.12);
      } else {
        _sliderOnChange = true;
        await itemScrollController.scrollTo(
          index: next - 1,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
        Future.delayed(Duration(milliseconds: 300)).then((value) {
          _sliderOnChange = false;
        });
      }
    } else {
      if (!Settings.animation) {
        _pageController.jumpToPage(next - 1);
      } else {
        _pageController.animateToPage(
          next - 1,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
    currentPage = next;
    setState(() {
      _prevPage = next;
    });
  }

  List<double> _height;
  List<GlobalKey> _keys;
  _networkImageItem(index) {
    final width =
        MediaQuery.of(context).size.width - (Settings.padding ? 8 : 0);
    if (_height == null) {
      _height = List<double>.filled(_pageInfo.uris.length, 0);
      _keys = List<GlobalKey>.generate(
          _pageInfo.uris.length, (index) => GlobalKey());
    }
    return FutureBuilder(
      // to avoid loading all images when fast scrolling
      future: Future.delayed(Duration(milliseconds: 300)).then((value) => 1),
      builder: (context, snapshot) {
        // To prevent the scroll from being chewed,
        // it is necessary to put an empty box for the invisible part.
        if (!snapshot.hasData && _height[index] == 0) {
          return SizedBox(
            height: 300,
            child: Center(
              child: SizedBox(
                child: CircularProgressIndicator(),
                width: 30,
                height: 30,
              ),
            ),
          );
        }

        return Container(
          constraints: BoxConstraints(
              minHeight: _height[index] != 0 ? _height[index] : 300),
          child: VOptimizedCacheImage(
            key: _keys[index],
            imageUrl: _pageInfo.uris[index],
            httpHeaders: _pageInfo.headers,
            fit: BoxFit.cover,
            fadeInDuration: Duration(microseconds: 500),
            fadeInCurve: Curves.easeIn,
            imageBuilder: (context, imageProvider, child) {
              if (_height[index] == 0 || _height[index] == 300) {
                try {
                  final RenderBox renderBoxRed =
                      _keys[index].currentContext.findRenderObject();
                  final sizeRender = renderBoxRed.size;
                  if (sizeRender.height != 300)
                    _height[index] = width / sizeRender.aspectRatio;
                } catch (e) {}
              }
              return child;
            },
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
      },
    );
  }

  _storageImageItem(index) {
    final width = MediaQuery.of(context).size.width;
    if (_height == null) {
      _height = List<double>.filled(_pageInfo.uris.length, 0);
    }
    if (_height[index] == 0) {
      return FutureBuilder(
        // to avoid loading all images when fast scrolling
        future: Future.delayed(Duration(milliseconds: 300)).then((value) async {
          return await _calculateImageDimension(_pageInfo.uris[index]);
        }),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _height[index] = width / snapshot.data.aspectRatio;
            return Container(
              height: _height[index],
              child: Image(
                image: FileImage(File(_pageInfo.uris[index])),
                fit: BoxFit.cover,
              ),
            );
          }

          return SizedBox(
            height: _height[index] != 0 ? _height[index] : 300,
            child: Center(
              child: SizedBox(
                child: CircularProgressIndicator(),
                width: 30,
                height: 30,
              ),
            ),
          );
        },
      );
    } else {
      // Prevent flicking when no animate jump page
      return Container(
        height: _height[index],
        child: Image(
          image: FileImage(File(_pageInfo.uris[index])),
          fit: BoxFit.cover,
        ),
      );
    }
  }

  Future<Size> _calculateImageDimension(String uri) async {
    Completer<Size> completer = Completer();
    Image image = Image.file(File(uri));
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

  Future<Size> _calculateNetworkImageDimension(String uri) async {
    Completer<Size> completer = Completer();
    Image image = new Image(
        image: OptimizedCacheImageProvider(uri, headers: _pageInfo.headers));
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

  List<Map<String, String>> _headerCache;
  List<String> _urlCache;
  _providerImageItem(index) {
    if (_headerCache == null) {
      _headerCache =
          List<Map<String, String>>.filled(_pageInfo.uris.length, null);
      _urlCache = List<String>.filled(_pageInfo.uris.length, null);
    }

    final width = MediaQuery.of(context).size.width;
    if (_height == null) {
      _height = List<double>.filled(_pageInfo.uris.length, 0);
      _keys = List<GlobalKey>.generate(
          _pageInfo.uris.length, (index) => GlobalKey());
    }
    return FutureBuilder(
      // to avoid loading all images when fast scrolling
      future: Future.delayed(Duration(milliseconds: 300)).then((value) => 1),
      builder: (context, snapshot) {
        // To prevent the scroll from being chewed,
        // it is necessary to put an empty box for the invisible part.
        if (!snapshot.hasData && _height[index] == 0) {
          return SizedBox(
            height: 300,
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
          future: Future.delayed(Duration(milliseconds: 1)).then((value) async {
            if (_headerCache[index] == null) {
              var header = await _pageInfo.provider.getHeader(index);
              _headerCache[index] = header;
            }

            if (_urlCache[index] == null) {
              var url = await _pageInfo.provider.getImageUrl(index);
              _urlCache[index] = url;
            }

            return 1;
          }),
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                (_urlCache[index] == null || _headerCache[index] == null)) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: SizedBox(
                    child: CircularProgressIndicator(),
                    width: 30,
                    height: 30,
                  ),
                ),
              );
            }
            return Container(
              // height: _height[index] != 0 ? _height[index] : null,
              constraints: _height[index] != 0
                  ? BoxConstraints(minHeight: _height[index])
                  : null,
              child: VOptimizedCacheImage(
                key: _keys[index],
                imageUrl: _urlCache[index],
                httpHeaders: _headerCache[index],
                fit: BoxFit.cover,
                fadeInDuration: Duration(microseconds: 500),
                fadeInCurve: Curves.easeIn,
                imageBuilder: (context, imageProvider, child) {
                  if (_height[index] == 0 || _height[index] == 300) {
                    Future.delayed(Duration(milliseconds: 50)).then((value) {
                      try {
                        final RenderBox renderBoxRed =
                            _keys[index].currentContext.findRenderObject();
                        final sizeRender = renderBoxRed.size;
                        if (sizeRender.height != 300) {
                          _height[index] = width / sizeRender.aspectRatio;
                        }
                      } catch (e) {}
                    });
                  }
                  return child;
                },
                progressIndicatorBuilder: (context, string, progress) {
                  return SizedBox(
                    height: 300,
                    child: Center(
                      child: SizedBox(
                        child:
                            CircularProgressIndicator(value: progress.progress),
                        width: 30,
                        height: 30,
                      ),
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

  _bottomAppBar() {
    final statusBarHeight =
        Settings.disableFullScreen ? MediaQuery.of(context).padding.top : 0;
    final height = MediaQuery.of(context).size.height;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: Duration(milliseconds: 300),
      child: Stack(
        children: [
          !Settings.disableFullScreen
              ? Padding(
                  padding: EdgeInsets.only(top: statusBarHeight.toDouble()),
                  child: Container(
                    height: Variables.statusBarHeight,
                    color: Colors.black,
                  ),
                )
              : Container(),
          Padding(
            padding: EdgeInsets.only(
                top: height -
                    Variables.bottomBarHeight -
                    (48) -
                    statusBarHeight),
            child: Container(
              alignment: Alignment.bottomCenter,
              color: Colors.black.withOpacity(0.8),
              height: 48 + Variables.bottomBarHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_prevPage',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16.0)),
                      Container(
                        width: 200,
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: Colors.blue,
                            inactiveTrackColor: Color(0xffd0d2d3),
                            trackHeight: 3,
                            thumbShape:
                                RoundSliderThumbShape(enabledThumbRadius: 6.0),
                            // thumbShape: SliderThumbShape(),
                          ),
                          child: Slider(
                            value: _prevPage.toDouble() > 0
                                ? _prevPage <= _pageInfo.uris.length
                                    ? _prevPage.toDouble()
                                    : _pageInfo.uris.length.toDouble()
                                : 1,
                            max: _pageInfo.uris.length.toDouble(),
                            min: 1,
                            label: _prevPage.toString(),
                            divisions: _pageInfo.uris.length,
                            inactiveColor: Settings.majorColor.withOpacity(0.7),
                            activeColor: Settings.majorColor,
                            onChangeStart: (value) {
                              _sliderOnChange = true;
                            },
                            onChangeEnd: (value) {
                              _sliderOnChange = false;
                            },
                            onChanged: (value) {
                              if (!Settings.isHorizontal) {
                                itemScrollController.jumpTo(
                                    index: value.toInt() - 1, alignment: 0.12);
                              } else {
                                _pageController.jumpToPage(value.toInt() - 1);
                              }
                              currentPage = value.toInt();
                              setState(() {
                                _prevPage = value.toInt();
                              });
                            },
                          ),
                        ),
                      ),
                      Text('${_pageInfo.uris.length}',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 15.0)),
                    ],
                  ),
                  !Settings.disableFullScreen
                      ? Container(
                          height: Variables.bottomBarHeight,
                          color: Colors.black,
                        )
                      : Container(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _verticalPageLabel() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.all(8),
      child: Stack(
        children: [
          Text(
            '$_prevPage/${_pageInfo.uris.length}',
            style: TextStyle(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = Colors.black,
            ),
          ),
          Text(
            '$_prevPage/${_pageInfo.uris.length}',
            style: TextStyle(
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}
