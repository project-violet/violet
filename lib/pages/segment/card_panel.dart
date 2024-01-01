// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:violet/style/palette.dart';

class CardPanel {
  static Widget build(
    BuildContext context, {
    required Widget child,
    bool enableBackgroundColor = false,
    String? heroTag,
  }) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);
    final color = Palette.themeColor;
    final bottomPadding = (mediaQuery.padding + mediaQuery.viewInsets).bottom;

    final card = Card(
      elevation: 5,
      color: color,
      child: SizedBox(
        width: width - 16,
        height: height - 16 - bottomPadding,
        child: child,
      ),
    );

    final hero = heroTag != null ? Hero(tag: heroTag, child: card) : card;

    return Container(
      color: enableBackgroundColor || Platform.isIOS ? color : null,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, bottom: bottomPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[hero],
      ),
    );
  }
}
