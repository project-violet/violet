// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/search_bar.dart';

class ViewerGallery extends StatefulWidget {
  final int viewedPage;

  ViewerGallery({this.viewedPage});

  @override
  _ViewerGalleryState createState() => _ViewerGalleryState();
}

class _ViewerGalleryState extends State<ViewerGallery> {
  ViewerPageProvider _pageInfo;
  ScrollController _scrollController = ScrollController();
  List<GlobalKey> itemKeys = <GlobalKey>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageInfo = Provider.of<ViewerPageProvider>(context);
    List.generate(_pageInfo.uris.length, (index) => index).forEach((element) {
      itemKeys.add(GlobalKey());
    });

    Future.value(1).then((value) {
      var row = widget.viewedPage ~/ 4;
      if (row == 0) return;
      _scrollController.jumpTo(
        row *
                ((itemKeys[0].currentContext.findRenderObject() as RenderBox)
                        .size
                        .height +
                    2) -
            100,
        // duration: _kDuration,
        // curve: _kCurve
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Container(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              floating: true,
              delegate: AnimatedOpacitySliver(
                minExtent: 64 + 12.0,
                maxExtent: 64.0 + 12,
                searchBar: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(10.0),
                        bottomRight: Radius.circular(10.0)),
                    color: Settings.themeWhat
                        ? Settings.themeBlack
                            ? const Color(0xFF0F0F0F)
                            : Color(0xFF353535)
                        : Colors.grey.shade100,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
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
              padding: EdgeInsets.all(4),
              sliver: _delegate(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title() {
    return Padding(
      padding: EdgeInsets.only(top: 24, left: 12),
      child: Text(
        _pageInfo.title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        constraints: BoxConstraints(),
        child: Center(
          child: Icon(
            icons[viewStyle],
            size: 28,
          ),
        ),
        padding: EdgeInsets.all(12),
        shape: CircleBorder(),
        onPressed: () async {
          setState(() {
            viewStyle = (viewStyle + 1) % icons.length;
          });
        },
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
          return Container(
            key: itemKeys[index],
            width: double.infinity,
            height: double.infinity,
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
          return Container(
            key: itemKeys[index],
            width: double.infinity,
            height: double.infinity,
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
        return Tuple2<dynamic, dynamic>(
          await _pageInfo.provider.getSmallImagesUrl(),
          await _pageInfo.provider.getHeader(0),
        );
      }),
      builder: (context, snapshot) {
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
              return Container(
                key: itemKeys[index],
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: <Widget>[
                    CachedNetworkImage(
                      imageUrl: snapshot.data.item1[index],
                      httpHeaders: snapshot.data.item2,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: width.toInt() ~/ properties[viewStyle][1],
                      filterQuality: FilterQuality.high,
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        padding: EdgeInsets.only(bottom: 1),
                        width: double.infinity,
                        color: Colors.black.withOpacity(0.7),
                        child: Text(
                          '${index + 1} page',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, color: Colors.white),
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
            childCount: _pageInfo.provider.length(),
          ),
        );
      },
    );
  }
}
