// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/image/file_image.dart' as file_image;
import 'package:violet/pages/viewer/image/provider_image.dart';
import 'package:violet/pages/viewer/others/scrollable_positioned_list/src/item_positions_listener.dart';
import 'package:violet/pages/viewer/others/scrollable_positioned_list/src/scrollable_positioned_list.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/pages/viewer/widget/custom_doubletap_gesture_detector.dart';
import 'package:violet/pages/viewer/widget/double_point_listener.dart';
import 'package:violet/settings/settings.dart';

typedef DoubleCallback = Future Function(double);
typedef BoolCallback = Function(bool);
typedef StringCallback = Future Function(String);

class VerticalViewerPage extends StatefulWidget {
  final String getxId;
  const VerticalViewerPage({
    super.key,
    required this.getxId,
  });

  @override
  State<VerticalViewerPage> createState() => _VerticalViewerPageState();
}

class _VerticalViewerPageState extends State<VerticalViewerPage>
    with SingleTickerProviderStateMixin {
  late final ViewerController c;

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

  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();

    c = Get.find(tag: widget.getxId);
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

      if (selected != null && c.page.value != selected) {
        c.page.value = selected;
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
      minCacheExtent: c.provider.useFileSystem ? height : height * 1.5,
      itemBuilder: _itemBuild,
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

  Widget _itemBuild(BuildContext context, int index) {
    Widget? image;

    if (c.provider.useFileSystem) {
      image = _storageImageItem(index);
    } else if (c.provider.useProvider) {
      image = _providerImageItem(index);
    }

    if (image == null) throw Exception('Dead Reaching');

    return DoublePointListener(
      child: Obx(
        () => Padding(
          padding: c.padding.value
              ? const EdgeInsets.fromLTRB(4, 0, 4, 4)
              : EdgeInsets.zero,
          child: Stack(
            children: [
              image!,
              if (_isExistsMessageSearchLayer(index))
                ..._messageSearchLayer(index),
            ],
          ),
        ),
      ),
      onStateChanged: (value) {
        setState(() {
          _scrollListEnable = value;
        });
      },
    );
  }

  _touchArea() {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Container(
      color: null,
      width: width,
      height: height,
      child: CustomDoubleTapGestureDectector(
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
          return file_image.FileImage(
            getxId: widget.getxId,
            index: index,
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

    if (c.loadingEstimaed[index] == false) {
      c.loadingEstimaed[index] = true;
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

            final image = Obx(
              () => ProviderImage(
                getxId: widget.getxId,
                index: index,
                imgKey: c.imgKeys[index],
                imgUrl: c.urlCache[index]!.value,
                imgHeader: c.headerCache[index],
                imageWidgetBuilder: (context, child) {
                  return _imageWidgetBuilder(index, width, child);
                },
              ),
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

  _isExistsMessageSearchLayer(int index) {
    return c.search.value &&
        c.imgHeight[index] != 0 &&
        c.messages.where((element) => element.$3 == index).isNotEmpty;
  }

  _messageSearchLayer(int index) {
    final ratio = c.imgHeight[index] / c.realImgHeight[index];
    final messages =
        c.messages.where((element) => element.$3 == index).toList();

    final boxes = messages.map((e) {
      var brtx = e.$5[0];
      var brty = e.$5[1];
      var brbx = e.$5[2];
      var brby = e.$5[3];

      return Positioned(
        top: brty * ratio - 4,
        left: brtx * ratio - 4,
        child: SizedBox(
          width: (brbx - brtx) * ratio + 8,
          height: (brby - brty) * ratio + 8,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                width: 3,
                color: Colors.red,
              ),
            ),
          ),
        ),
      );
    }).toList();

    return boxes;
  }
}
