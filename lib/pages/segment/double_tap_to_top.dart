import 'package:flutter/material.dart';

mixin DoubleTapToTopMixin {
  ScrollController? doubleTapToTopScrollController;

  void animateToTop() {
    doubleTapToTopScrollController?.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }
}
