import 'package:flutter/widgets.dart';

abstract class ScrollableStatefulWidget extends StatefulWidget {
  ScrollController scrollController = ScrollController();

  ScrollableStatefulWidget({Key? key}) : super(key: key);

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
