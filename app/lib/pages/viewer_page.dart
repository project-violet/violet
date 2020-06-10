// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'package:flutter/material.dart';
import 'package:violet/widgets/viewer_widget.dart';

class ViewerPage extends StatefulWidget {
  final List<String> images;
  final Map<String, String> headers;

  ViewerPage({this.images, this.headers});

  @override
  _ViewerPageState createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: ViewerWidget(headers: widget.headers, urls: widget.images));
  }
}
