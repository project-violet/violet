// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AnimatedOpacitySliver implements SliverPersistentHeaderDelegate {
  AnimatedOpacitySliver({
    this.searchBar,
  });

  Widget? searchBar;

  @override
  double get minExtent => 64 + 12;

  @override
  double get maxExtent => 64 + 12;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          child: searchBar,
          opacity: 1.0 - max(0.0, shrinkOffset - 20) / (maxExtent - 20),
          duration: Duration(milliseconds: 100),
        )
      ],
    );
  }

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }

  @override
  FloatingHeaderSnapConfiguration? get snapConfiguration => null;

  @override
  OverScrollHeaderStretchConfiguration? get stretchConfiguration => null;

  @override
  PersistentHeaderShowOnScreenConfiguration? get showOnScreenConfiguration =>
      null;

  @override
  TickerProvider? get vsync => null;
}
