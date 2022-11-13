import 'package:flutter/widgets.dart';

mixin Scrollable {
  ScrollController scrollController = ScrollController();

  void animateScrollOnTop() {
    scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void discreteScrollOnTop() {
    scrollController.jumpTo(0.0);
  }
}
