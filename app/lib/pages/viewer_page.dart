// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'package:flutter/material.dart';
import 'package:violet/widgets/viewer_widget.dart';

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
    return Container(
        child: ViewerWidget(id: widget.id, headers: widget.headers, urls: widget.images));
  }
}
