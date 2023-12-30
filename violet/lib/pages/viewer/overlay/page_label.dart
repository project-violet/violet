// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';

class PageLabel extends StatelessWidget {
  late final ViewerController c;

  PageLabel({super.key, required String getxId}) {
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
                  ..strokeWidth = 2.0
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
