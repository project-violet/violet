// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mdi/mdi.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/pages/download/gallery/gallery_item.dart';
import 'package:violet/pages/download/gallery/gallery_simple_item.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/search_bar.dart';

class GalleryPage extends StatefulWidget {
  final List<GalleryItem> item;
  final DownloadItemModel model;

  GalleryPage({this.item, this.model});

  @override
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  //  Current State of InnerDrawerState

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        // padding: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Card(
              elevation: 5,
              color:
                  Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
              child: SizedBox(
                width: width - 16,
                height: height - 16,
                child: Container(
                  child: CustomScrollView(
                    // controller: _scroll,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPersistentHeader(
                        floating: true,
                        delegate: AnimatedOpacitySliver(
                          minExtent: 64 + 12.0,
                          maxExtent: 64.0 + 12,
                          searchBar: Container(
                            decoration: new BoxDecoration(
                              borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(10.0),
                                  bottomRight: Radius.circular(10.0)),
                              color: Settings.themeWhat
                                  ? Color(0xFF353535)
                                  : Colors.grey.shade100,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _title()),
                                  _view(),
                                  _align(),
                                  // _clustering(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.all(4),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: properties[viewStyle][0],
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              return GallerySimpleItem(
                                item: widget.item[index],
                                size: width.toInt() ~/ properties[viewStyle][1],
                              );
                            },
                            childCount: widget.item.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
        widget.model.info(),
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

  int alignStyle = 0;
  static const List<IconData> alignIcons = [
    Mdi.sortClockDescending,
    Mdi.sortClockAscending,
    Mdi.folderUpload,
    Mdi.folderDownload,
  ];
  Widget _align() {
    return Align(
      alignment: Alignment.center,
      child: RawMaterialButton(
        constraints: BoxConstraints(),
        child: Center(
          child: Icon(
            alignIcons[alignStyle],
            size: 28,
          ),
        ),
        padding: EdgeInsets.all(12),
        shape: CircleBorder(),
        onPressed: () async {
          alignStyle = (alignStyle + 1) % icons.length;

          switch (alignStyle) {
            case 0:
              widget.item.sort((x, y) => x.path.compareTo(y.path));
              break;
            case 1:
              widget.item.sort((x, y) => y.path.compareTo(x.path));
              break;
            case 2:
              widget.item.sort((x, y) => File(y.path)
                  .lengthSync()
                  .compareTo(File(x.path).lengthSync()));
              break;
            case 3:
              widget.item.sort((x, y) => File(x.path)
                  .lengthSync()
                  .compareTo(File(y.path).lengthSync()));
              break;
          }

          setState(() {});
        },
      ),
    );
  }
}
