import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/v2/viewer_controller.dart';

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
      children: [],
    );
  }
}
