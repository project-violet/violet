// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:violet/pages/viewer/viewer_widget.dart';

class ViewerPage extends StatefulWidget {
  final List<String> images;
  final Map<String, String> headers;
  final String id;

  ViewerPage({this.images, this.headers, this.id});

  @override
  _ViewerPageState createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  @override
  Widget build(BuildContext context) {
    var vw = ViewerWidget(
        id: widget.id, headers: widget.headers, urls: widget.images);
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, vw.currentPage);
        return new Future(() => false);
      },
      child: Container(
        child: vw,
      ),
    );
  }
}
