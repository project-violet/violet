// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/search_bar.dart';

class ViewerGallery extends StatefulWidget {
  final int viewedPage;

  const ViewerGallery({super.key, required this.viewedPage});

  @override
  State<ViewerGallery> createState() => _ViewerGalleryState();
}

class _ViewerGalleryState extends State<ViewerGallery> {
  late final ViewerPageProvider _pageInfo;
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> itemKeys = <GlobalKey>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _pageInfo = Provider.of<ViewerPageProvider>(context);
    itemKeys.addAll(
      Iterable.generate(_pageInfo.uris.length, (index) => GlobalKey()),
    );

    Future.value(1).then((value) {
      var row = widget.viewedPage ~/ 4;
      if (row == 0) return;
      var firstItemHeight =
          (itemKeys[0].currentContext!.findRenderObject() as RenderBox)
              .size
              .height;
      _scrollController.jumpTo(
        row * (firstItemHeight + 2) - 100,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            floating: true,
            delegate: AnimatedOpacitySliver(
              searchBar: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(10.0),
                      bottomRight: Radius.circular(10.0)),
                  color: Palette.themeColor,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _title()),
                      _view(),
                      // _clustering(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(4),
            sliver: _delegate(),
          ),
        ],
      ),
    );
  }

  Widget _title() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 12),
      child: Text(
        _pageInfo.title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  int viewStyle = 0;
  static const List<IconData> icons = [
    Icons.view_comfy,
    Icons.view_module,
    MdiIcons.viewGrid,
    MdiIcons.cubeUnfolded,
    // MdiIcons.atom,
    // MdiIcons.mine,
  ];
  static const List<dynamic> properties = [
    [4, 2],
    [3, 2],
    [2, 1],
    // [5, 3],
    [6, 4],
  ];
  Widget _view() {
    return Align(
      alignment: Alignment.center,
      child: RawMaterialButton(
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(12),
        shape: const CircleBorder(),
        onPressed: () async {
          setState(() {
            viewStyle = (viewStyle + 1) % icons.length;
          });
        },
        child: Center(
          child: Icon(
            icons[viewStyle],
            size: 28,
          ),
        ),
      ),
    );
  }

  _delegate() {
    if (_pageInfo.useFileSystem) {
      return _filesystemDelegate();
    } else if (_pageInfo.useWeb) {
      return _webDelegate();
    } else if (_pageInfo.useProvider) {
      return _providerDelegate();
    }
  }

  _filesystemDelegate() {
    final width = MediaQuery.of(context).size.width;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: properties[viewStyle][0],
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 3 / 4,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return SizedBox.expand(
            key: itemKeys[index],
            child: Stack(
              children: <Widget>[
                Image.file(
                  File(_pageInfo.uris[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  isAntiAlias: true,
                  cacheWidth: width.toInt() ~/ properties[viewStyle][1],
                  filterQuality: FilterQuality.high,
                ),
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
                      onTap: () {
                        Navigator.pop(context, index);
                      },
                    ),
                  ),
                )
              ],
            ),
          );
        },
        childCount: _pageInfo.uris.length,
      ),
    );
  }

  _webDelegate() {
    final width = MediaQuery.of(context).size.width;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: properties[viewStyle][0],
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 3 / 4,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return SizedBox.expand(
            key: itemKeys[index],
            child: Stack(
              children: <Widget>[
                CachedNetworkImage(
                  imageUrl: _pageInfo.uris[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  httpHeaders: _pageInfo.headers,
                  memCacheWidth: width.toInt() ~/ properties[viewStyle][1],
                  filterQuality: FilterQuality.high,
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                    ),
                  ),
                )
              ],
            ),
          );
        },
        childCount: _pageInfo.uris.length,
      ),
    );
  }

  _providerDelegate() {
    final width = MediaQuery.of(context).size.width;

    return FutureBuilder(
      future: Future.sync(() async {
        return Tuple2<List<String>, Map<String, String>>(
          await _pageInfo.provider!.getSmallImagesUrl(),
          await _pageInfo.provider!.getHeader(0),
        );
      }),
      builder: (context,
          AsyncSnapshot<Tuple2<List<String>, Map<String, String>>> snapshot) {
        if (!snapshot.hasData) {
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: properties[viewStyle][0],
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return Container();
              },
            ),
          );
        }
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: properties[viewStyle][0],
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 3 / 4,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return SizedBox.expand(
                key: itemKeys[index],
                child: Stack(
                  children: <Widget>[
                    CachedNetworkImage(
                      imageUrl: snapshot.data!.item1[index],
                      httpHeaders: snapshot.data!.item2,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: width.toInt() ~/ properties[viewStyle][1],
                      filterQuality: FilterQuality.high,
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 1),
                        width: double.infinity,
                        color: Colors.black.withOpacity(0.7),
                        child: Text(
                          '${index + 1} page',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: Colors.black.withOpacity(0.4),
                          highlightColor: Colors.black.withOpacity(0.1),
                          onTap: () {
                            Navigator.pop(context, index);
                          },
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
            childCount: _pageInfo.provider!.length(),
          ),
        );
      },
    );
  }
}
