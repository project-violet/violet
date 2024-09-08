// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/query.dart';
import 'package:violet/util/iter_helper.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/dots_indicator.dart';

typedef IntCallback = Future Function(int);

class PreviewAreaWidget extends StatelessWidget {
  final QueryResult queryResult;
  final PageController pageController = PageController(
    initialPage: 0,
  );
  final IntCallback onPageTapped;

  PreviewAreaWidget({
    super.key,
    required this.queryResult,
    required this.onPageTapped,
  });

  @override
  Widget build(BuildContext context) {
    var columnLength = 3;

    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      columnLength = 6;
    } else {
      columnLength = 3;
    }

    if (ProviderManager.isExists(queryResult.id())) {
      return FutureBuilder(
        future: Future.value(1).then((value) async {
          VioletImageProvider prov =
              await ProviderManager.get(queryResult.id());

          return (await prov.getSmallImagesUrl(), await prov.getHeader(0));
        }),
        builder: (context,
            AsyncSnapshot<(List<String>, Map<String, String>)> snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }

          final pages = (snapshot.data!.$1)
              .chunk(30)
              .map((chunk) => GridView.count(
                    controller: null,
                    physics: const ScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: columnLength,
                    childAspectRatio: 3 / 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: chunk.$2
                        .asMap()
                        .map((i, e) => MapEntry(
                            i,
                            _buildTappableItem(context, chunk.$1 * 30 + i, e,
                                snapshot.data!.$2)))
                        .values
                        .toList(),
                  ))
              .toList();

          return ExpandablePageView(children: pages);
        },
      );
    }
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Align(
            child: Text(
              '??? Unknown Error!',
              textAlign: TextAlign.center,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildTappableItem(BuildContext context, int index, String image,
      Map<String, String> headers) {
    return SizedBox.expand(
      child: Stack(
        children: <Widget>[
          SizedBox.expand(
              child: CachedNetworkImage(
            imageUrl: image,
            httpHeaders: headers,
          )),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 1),
              width: double.infinity,
              color: Colors.black.withOpacity(0.7),
              child: Text(
                '${index + 1} page',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                highlightColor: Colors.transparent,
                onTap: () {
                  onPageTapped(index);
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}

// https://stackoverflow.com/questions/54522980/flutter-adjust-height-of-pageview-horizontal-listview-based-on-current-child
class ExpandablePageView extends StatefulWidget {
  final List<Widget> children;

  const ExpandablePageView({
    super.key,
    required this.children,
  });

  @override
  State<ExpandablePageView> createState() => _ExpandablePageViewState();
}

class _ExpandablePageViewState extends State<ExpandablePageView>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late List<double> _heights;
  int _currentPage = 0;

  static const _kDuration = Duration(milliseconds: 300);
  static const _kCurve = Curves.ease;

  double get _currentHeight => _heights[_currentPage];

  @override
  void initState() {
    _heights = widget.children.map((e) => 0.0).toList();
    super.initState();
    _pageController = PageController()
      ..addListener(() {
        final newPage = _pageController.page?.round() ?? 0;
        if (_currentPage != newPage) {
          setState(() {
            _currentPage = newPage;
          });
          // context.findRenderObject()!.showOnScreen(
          //       duration: const Duration(milliseconds: 300),
          //       // rect: Rect.fromLTRB(0, 0, 0, _heights[0]),
          //     );
        }
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
        curve: Curves.easeOutCirc,
        duration: const Duration(milliseconds: 400),
        tween: Tween<double>(begin: _heights[0], end: _currentHeight),
        builder: (context, value, child) =>
            SizedBox(height: value, child: child),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: PageView(
                controller: _pageController,
                children: _sizeReportingChildren
                    .asMap() //
                    .map((index, child) => MapEntry(index, child))
                    .values
                    .toList(),
              ),
            ),
            FutureBuilder(
              future: Future.value(1),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Container();

                return Positioned(
                  top: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: Container(
                    color: null,
                    child: Center(
                      child: DotsIndicator(
                        controller: _pageController,
                        itemCount: _sizeReportingChildren.length,
                        onPageSelected: (int page) {
                          _pageController.animateToPage(
                            page,
                            duration: _kDuration,
                            curve: _kCurve,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ));
  }

  List<Widget> get _sizeReportingChildren => widget.children
      .asMap() //
      .map(
        (index, child) => MapEntry(
          index,
          OverflowBox(
            //needed, so that parent won't impose its constraints on the children, thus skewing the measurement results.
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.topCenter,
            child: SizeReportingWidget(
              onSizeChange: (size) =>
                  setState(() => _heights[index] = size.height + 20.0),
              child: Align(child: child),
            ),
          ),
        ),
      )
      .values
      .toList();
}

class SizeReportingWidget extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSizeChange;

  const SizeReportingWidget({
    super.key,
    required this.child,
    required this.onSizeChange,
  });

  @override
  State<SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<SizeReportingWidget> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
    return widget.child;
  }

  void _notifySize() {
    if (!mounted) {
      return;
    }
    final size = context.size;
    if (_oldSize != size && size != null) {
      _oldSize = size;
      widget.onSizeChange(size);
    }
  }
}
