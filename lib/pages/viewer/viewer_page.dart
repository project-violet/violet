// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:violet/pages/viewer/vertical_viewer_widget.dart';

int currentPage = 0;

class ViewerPage extends StatelessWidget {
  final List<String> images;
  final Map<String, String> headers;
  final String id;

  ViewerPage({this.images, this.headers, this.id});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, currentPage);
        return new Future(() => false);
      },
      child: Container(
        child: ViewerWidget(
          id: id,
          headers: headers,
          urls: images,
        ),
      ),
    );
  }
}
