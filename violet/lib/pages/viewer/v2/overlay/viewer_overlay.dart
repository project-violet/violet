// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/v2/viewer_controller.dart';

import 'page_label.dart';

class ViewerOverlay extends StatefulWidget {
  const ViewerOverlay({Key? key}) : super(key: key);

  @override
  State<ViewerOverlay> createState() => _ViewerOverlayState();
}

class _ViewerOverlayState extends State<ViewerOverlay> {
  final ViewerController c = Get.find();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [PageLabel()],
    );
  }
}
