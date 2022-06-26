// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../viewer_controller.dart';

class PageLabel extends StatelessWidget {
  late final ViewerController c;

  PageLabel({Key? key, required String getxId}) : super(key: key) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.all(8),
      child: Obx(
        () => Stack(
          children: [
            Text(
              '${c.page.value + 1}/${c.maxPage}',
              style: TextStyle(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2
                  ..color = Colors.black,
              ),
            ),
            Text(
              '${c.page.value + 1}/${c.maxPage}',
              style: TextStyle(
                color: Colors.grey.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
