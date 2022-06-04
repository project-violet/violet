// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';

class DebounceWidget extends StatefulWidget {
  final Widget child;
  final Widget? loadingWidget;

  const DebounceWidget({Key? key, required this.child, this.loadingWidget})
      : super(key: key);

  @override
  State<DebounceWidget> createState() => _DebounceWidgetState();
}

class _DebounceWidgetState extends State<DebounceWidget> {
  bool isLoaded = false;

  @override
  Widget build(BuildContext context) {
    if (isLoaded) return widget.child;

    return FutureBuilder(
      future:
          Future.delayed(const Duration(milliseconds: 300)).then((value) => 1),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          isLoaded = true;
          return widget.child;
        }
        return widget.loadingWidget ?? const SizedBox.shrink();
      },
    );
  }
}
