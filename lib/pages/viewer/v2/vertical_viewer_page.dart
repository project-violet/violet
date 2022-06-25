import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/viewer/others/scrollable_positioned_list/src/item_positions_listener.dart';
import 'package:violet/pages/viewer/others/scrollable_positioned_list/src/scrollable_positioned_list.dart';
import 'package:violet/pages/viewer/v2/viewer_controller.dart';
import 'package:violet/pages/viewer/v_cached_network_image.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/settings/settings_wrapper.dart';

typedef DoubleCallback = Future Function(double);
typedef BoolCallback = Function(bool);
typedef StringCallback = Future Function(String);

class VerticalViewerPage extends StatefulWidget {
  const VerticalViewerPage({Key? key}) : super(key: key);

  @override
  State<VerticalViewerPage> createState() => _VerticalViewerPageState();
}

class _VerticalViewerPageState extends State<VerticalViewerPage>
    with SingleTickerProviderStateMixin {
  final ViewerController c = Get.find();

  /// this is used for interactive viewer widget
  /// double-tap a specific location to zoom in on that location.
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  /// lock scroll after zoom gesture
  /// this prevents paging on zoom gesture are performed
  bool _scrollListEnable = true;

  /// these are used on [_patchHeightForDynamicLoadedImage]
  int _latestIndex = 0;
  double _latestAlign = 0;
  bool _onScroll = false;

  /// this is used on provider
  /// determine estimaed height is loaded
  bool _loadingEstimaed = false;

  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });

    _itemPositionsListener.itemPositions.addListener(() {
      if (!c.onSession.value) return;
      if (c.sliderOnChange) return;

      var v = _itemPositionsListener.itemPositions.value.toList();
      int? selected;

      v.sort((x, y) => x.itemLeadingEdge.compareTo(y.itemLeadingEdge));

      for (var e in v) {
        if (e.itemLeadingEdge <= 0.125) {
          selected = e.index;
        } else {
          break;
        }
      }

      _getLatestHeight();

      if (selected != null && c.page.value != selected + 1) {
        /// TODO: this login must implements to [viewer_overlay]
        // if (_isThumbMode && !_sliderOnChange) {
        //   _thumbAnimateTo(selected);
        // }

        c.page.value = selected + 1;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    final scrollablePositionedList = ScrollablePositionedList.builder(
      physics: _scrollListEnable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: c.maxPage,
      itemScrollController: c.verticalItemScrollController,
      itemPositionsListener: _itemPositionsListener,
      minCacheExtent: c.provider.useFileSystem ? height * 3.0 : height * 1.5,
      itemBuilder: (context, index) {
        Widget? image;
        if (!c.padding.value) {
          if (c.provider.useFileSystem) {
            image = _storageImageItem(index);
          } else if (c.provider.useProvider) {
            image = _providerImageItem(index);
          }
        } else {
          if (c.provider.useFileSystem) {
            image = Padding(
              child: _storageImageItem(index),
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            );
          } else if (c.provider.useProvider) {
            image = Padding(
              child: _providerImageItem(index),
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            );
          }
        }

        if (image == null) throw Exception('Dead Reaching');

        return _DoublePointListener(
          child: image,
          onStateChanged: (value) {
            setState(() {
              _scrollListEnable = value;
            });
          },
        );
      },
    );

    final notificationListener = NotificationListener(
      child: scrollablePositionedList,
      onNotification: (t) {
        if (t is ScrollStartNotification) {
          _onScroll = true;
        } else if (t is ScrollEndNotification) {
          _onScroll = false;
        }
        return false;
      },
    );

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          child: AbsorbPointer(
            absorbing: !_scrollListEnable,
            child: ColoredBox(
              color: Settings.themeWhat && Settings.themeBlack
                  ? Colors.black
                  : const Color(0xff444444),
              child: notificationListener,
            ),
          ),
        ),
        _touchArea(),
      ],
    );
  }

  _touchArea() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Container(
      color: null,
      width: width,
      height: height,
      child: _CustomDoubleTapGestureDectector(
        onTap: _touchEvent,
        onDoubleTap: _doubleTapEvent,
      ),
    );
  }

  void _touchEvent(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    if (details.localPosition.dx < width / 3) {
      if (!Settings.disableOverlayButton) c.leftButton();
    } else if (width / 3 * 2 < details.localPosition.dx) {
      if (!Settings.disableOverlayButton) c.rightButton();
    } else {
      c.middleButton();
    }
  }

  void _doubleTapEvent(TapDownDetails details) {
    Matrix4 endMatrix;
    Offset position = details.localPosition;

    if (_transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
    } else {
      endMatrix = Matrix4.identity()
        ..translate(-position.dx * 1, -position.dy * 1)
        ..scale(2.0);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );
    _animationController.forward(from: 0);
  }

  /// This function is used for [_patchHeightForDynamicLoadedImage].
  /// The height of the widget with the initial image is set to 300,
  /// and when the image is loaded, the height is reset based on the
  /// aspect ratio of the image, which automatically adjusts the page
  /// currently being viewed by the user. This is a problem caused
  /// by the minCacheExtent of the listview, and we could not reduce
  /// the minCacheExtent to solve this problem.
  _getLatestHeight() {
    var v = _itemPositionsListener.itemPositions.value.toList();
    int? selected;
    ItemPosition? selectede;

    v.sort((x, y) => y.itemLeadingEdge.compareTo(x.itemLeadingEdge));

    for (var e in v) {
      if (e.itemLeadingEdge >= 0.0) {
        selected = e.index;
        selectede = e;
      } else {
        break;
      }
    }

    _latestIndex = selected ?? 0;
    _latestAlign = selectede?.itemLeadingEdge ?? 0;
  }

  _patchHeightForDynamicLoadedImage() {
    if (c.sliderOnChange) return;
    c.verticalItemScrollController.scrollTo(
      index: _latestIndex,
      duration: const Duration(microseconds: 1),
      alignment: _latestAlign,
    );
  }

  _storageImageItem(index) {
    Future<dynamic> future;

    if (c.imgHeight[index] == 0) {
      future = Future.delayed(const Duration(milliseconds: 300));
    } else {
      future = Future.value(0);
    }

    return FutureBuilder(
      // to avoid loading all images when fast scrolling
      future: future.then((value) async {
        return 0;
      }),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _FileImage(
            path: c.provider.uris[index],
            cachedHeight: c.imgHeight[index] != 0 ? c.imgHeight[index] : null,
            heightCallback: c.imgHeight[index] != 0
                ? null
                : (height) async {
                    c.imgHeight[index] = height;
                  },
          );
        }

        return SizedBox(
          height: c.imgHeight[index] != 0 ? c.imgHeight[index] : 300,
          child: const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }

  _providerImageItem(int index) {
    final width = MediaQuery.of(context).size.width;

    if (_loadingEstimaed == false) {
      _loadingEstimaed = true;
      Future.delayed(const Duration(milliseconds: 1)).then((value) async {
        if (!c.onSession.value) return;
        final h =
            await c.provider.provider!.getEstimatedImageHeight(index, width);
        final oh = await c.provider.provider!.getOriginalImageHeight(index);
        if (h > 0) {
          setState(() {
            c.realImgHeight[index] = oh;
            c.estimatedImgHeight[index] = h;
          });
        }
      });
    }

    Future<dynamic> future;

    if (c.imgHeight[index] == 0) {
      future = Future.delayed(const Duration(milliseconds: 300));
    } else {
      future = Future.value(0);
    }

    return FutureBuilder(
      // to avoid loading all images when fast scrolling
      future: future.then((value) => 1),
      builder: (context, snapshot) {
        // To prevent the scroll from being chewed,
        // it is necessary to put an empty box for the invisible part.
        if (!snapshot.hasData && c.imgHeight[index] == 0) {
          return _loadingWidget(index);
        }

        return FutureBuilder(
          future: c.load(index),
          builder: (context, snapshot) {
            if (c.urlCache[index] == null || c.headerCache[index] == null) {
              return _loadingWidget(index);
            }

            final image = _ProviderImage(
              imgKey: c.imgKeys[index],
              imgUrl: c.urlCache[index]!,
              imgHeader: c.headerCache[index],
              imageWidgetBuilder: (context, imageProvider, child) {
                return _imageWidgetBuilder(index, width, child);
              },
              progressIndicatorBuilder: (context, string, progress) {
                return _progresIndicatorBuilder(index, progress);
              },
              loadingErrorWidgetBuilder: (context, url, error) {
                return _loadingErrorWidgetBuilder(error, index);
              },
            );

            return Container(
              constraints: c.imgHeight[index] != 0
                  ? BoxConstraints(minHeight: c.imgHeight[index])
                  : c.estimatedImgHeight[index] != 0
                      ? BoxConstraints(minHeight: c.estimatedImgHeight[index])
                      : null,
              child: image,
            );
          },
        );
      },
    );
  }

  _loadingWidget(int index) {
    return SizedBox(
      height:
          c.estimatedImgHeight[index] != 0 ? c.estimatedImgHeight[index] : 300,
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  _imageWidgetBuilder(int index, double width, Widget child) {
    if (c.imgHeight[index] == 0 || c.imgHeight[index] == 300) {
      Future.delayed(const Duration(milliseconds: 50)).then((value) {
        try {
          final RenderBox renderBoxRed =
              c.imgKeys[index].currentContext!.findRenderObject() as RenderBox;
          final sizeRender = renderBoxRed.size;
          if (sizeRender.height != 300) {
            c.imgHeight[index] =
                (width / sizeRender.aspectRatio - 1.5).floor().toDouble();
          }
          if (_latestIndex >= index && !_onScroll) {
            _patchHeightForDynamicLoadedImage();
          }
        } catch (_) {}
      });
    }
    return child;
  }

  _progresIndicatorBuilder(int index, DownloadProgress progress) {
    return SizedBox(
      height:
          c.estimatedImgHeight[index] != 0 ? c.estimatedImgHeight[index] : 300,
      child: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(value: progress.progress),
        ),
      ),
    );
  }

  _loadingErrorWidgetBuilder(error, int index) {
    Logger.error('[Viewer] E: image load failed\n'
        '$error');

    final iconButton = IconButton(
      icon: Icon(
        Icons.refresh,
        color: Settings.majorColor,
      ),
      onPressed: () => setState(() {
        c.imgKeys[index] = GlobalKey();
      }),
    );

    return SizedBox(
      height:
          c.estimatedImgHeight[index] != 0 ? c.estimatedImgHeight[index] : 300,
      child: Center(
        child: SizedBox(
          width: 50,
          height: 50,
          child: iconButton,
        ),
      ),
    );
  }
}

/// GestureDetector uses a delay to distinguish between tap events
/// and double taps. By default, this delay cannot be modified, so
/// I created a separate class.
class _CustomDoubleTapGestureDectector extends StatefulWidget {
  final GestureTapDownCallback onTap;
  final GestureTapDownCallback onDoubleTap;
  final Duration doubleTapMaxDelay;

  const _CustomDoubleTapGestureDectector({
    required this.onTap,
    required this.onDoubleTap,
    // ignore: unused_element
    this.doubleTapMaxDelay = const Duration(milliseconds: 200),
  });

  @override
  State<_CustomDoubleTapGestureDectector> createState() =>
      __CustomDoubleTapGestureDectectorState();
}

class __CustomDoubleTapGestureDectectorState
    extends State<_CustomDoubleTapGestureDectector> {
  /// these are used for double tap check
  Timer? _doubleTapCheckTimer;
  bool _isPressed = false;
  bool _isDoubleTap = false;
  bool _isSingleTap = false;

  /// this is used for onTap, onDoubleTap event
  late TapDownDetails _onTapDetails;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      onTapDown: (TapDownDetails details) {
        _onTapDetails = details;

        _isPressed = true;
        if (_doubleTapCheckTimer != null && _doubleTapCheckTimer!.isActive) {
          _isDoubleTap = true;
          _doubleTapCheckTimer!.cancel();
        } else {
          _doubleTapCheckTimer =
              Timer(widget.doubleTapMaxDelay, _doubleTapTimerElapsed);
        }
      },
      onTapCancel: () {
        _isPressed = _isSingleTap = _isDoubleTap = false;
        if (_doubleTapCheckTimer != null && _doubleTapCheckTimer!.isActive) {
          _doubleTapCheckTimer!.cancel();
        }
      },
    );
  }

  void _doubleTapTimerElapsed() {
    if (_isPressed) {
      _isSingleTap = true;
    } else {
      widget.onTap(_onTapDetails);
    }
  }

  void _handleTap() {
    _isPressed = false;
    if (_isSingleTap) {
      _isSingleTap = false;
      widget.onTap(_onTapDetails);
    }
    if (_isDoubleTap) {
      _isDoubleTap = false;
      widget.onDoubleTap(_onTapDetails);
    }
  }
}

typedef VImageWidgetBuilder = Widget Function(
    BuildContext context, ImageProvider imageProvider, Widget child);

typedef VProgressIndicatorBuilder = Widget Function(
  BuildContext context,
  String url,
  DownloadProgress progress,
);

typedef VLoadingErrorWidgetBuilder = Widget Function(
  BuildContext context,
  String url,
  dynamic error,
);

class _ProviderImage extends StatefulWidget {
  final GlobalKey imgKey;
  final String imgUrl;
  final Map<String, String>? imgHeader;
  final VImageWidgetBuilder imageWidgetBuilder;
  final VProgressIndicatorBuilder progressIndicatorBuilder;
  final VLoadingErrorWidgetBuilder loadingErrorWidgetBuilder;

  const _ProviderImage({
    Key? key,
    required this.imgKey,
    required this.imgUrl,
    required this.imgHeader,
    required this.imageWidgetBuilder,
    required this.progressIndicatorBuilder,
    required this.loadingErrorWidgetBuilder,
  }) : super(key: key);

  @override
  State<_ProviderImage> createState() => __ProviderImageState();
}

class __ProviderImageState extends State<_ProviderImage> {
  @override
  void dispose() {
    CachedNetworkImage.evictFromCache(widget.imgUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VCachedNetworkImage(
      key: widget.imgKey,
      imageUrl: widget.imgUrl,
      httpHeaders: widget.imgHeader,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(microseconds: 500),
      fadeInCurve: Curves.easeIn,
      filterQuality: SettingsWrapper.imageQuality,
      imageBuilder: widget.imageWidgetBuilder,
      progressIndicatorBuilder: widget.progressIndicatorBuilder,
      errorWidget: widget.loadingErrorWidgetBuilder,
      memCacheWidth: Settings.useLowPerf
          ? (MediaQuery.of(context).size.width * 1.5).toInt()
          : null,
    );
  }
}

/// Raises an event when two or more fingers touch the screen.
class _DoublePointListener extends StatefulWidget {
  final Widget child;
  final BoolCallback onStateChanged;

  const _DoublePointListener({
    required this.child,
    required this.onStateChanged,
  });

  @override
  State<_DoublePointListener> createState() => __DoublePointListener();
}

class __DoublePointListener extends State<_DoublePointListener> {
  /// How many fingers are on the screen?
  int _mpPoints = 0;

  ///
  bool _onStateChanged = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _mpPoints++;
        if (_mpPoints >= 2) {
          if (_onStateChanged) {
            _onStateChanged = false;
            widget.onStateChanged(false);
          }
        }
      },
      onPointerUp: (event) {
        _mpPoints--;
        if (_mpPoints < 1) {
          _onStateChanged = true;
          widget.onStateChanged(true);
        }
      },
      child: widget.child,
    );
  }
}

class _FileImage extends StatefulWidget {
  final String path;
  final double? cachedHeight;
  final DoubleCallback? heightCallback;

  const _FileImage(
      {required this.path, this.heightCallback, this.cachedHeight});

  @override
  State<_FileImage> createState() => __FileImageState();
}

class __FileImageState extends State<_FileImage> {
  final ViewerController c = Get.find();
  late double _height;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    if (widget.cachedHeight != null && widget.cachedHeight! > 0) {
      _height = widget.cachedHeight!;
    } else {
      _height = 300;
    }
  }

  @override
  void dispose() {
    clearMemoryImageCache(widget.path);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = ExtendedImage.file(
      File(widget.path),
      fit: BoxFit.contain,
      imageCacheName: widget.path,
      filterQuality: SettingsWrapper.getImageQuality(c.imgQuality.value),
      cacheWidth: Settings.useLowPerf
          ? (MediaQuery.of(context).size.width * 1.5).toInt()
          : null,
      loadStateChanged: _loadStateChanged,
    );

    return AnimatedContainer(
      alignment: Alignment.center,
      height: _height,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Obx(() => image),
    );
  }

  Widget _loadStateChanged(ExtendedImageState state) {
    final width = MediaQuery.of(context).size.width;

    if (widget.cachedHeight != null && widget.cachedHeight! > 0) {
      return state.completedWidget;
    }

    final ImageInfo? imageInfo = state.extendedImageInfo;
    if ((state.extendedImageLoadState == LoadState.completed ||
            imageInfo != null) &&
        !_loaded) {
      _loaded = true;
      Future.delayed(const Duration(milliseconds: 100)).then((value) {
        final aspectRatio = imageInfo!.image.width / imageInfo.image.height;
        if (widget.heightCallback != null) {
          widget.heightCallback!(width / aspectRatio);
        }
        setState(() {
          _height = width / aspectRatio;
        });
      });
    } else if (state.extendedImageLoadState == LoadState.loading) {
      return SizedBox(
        height: _height,
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return state.completedWidget;
  }
}
