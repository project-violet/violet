// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class ToastWrapper extends StatefulWidget {
  final bool isCheck;
  final bool isWarning;
  final String msg;
  final IconData? icon;
  final Color? color;
  final bool ignoreDrawer;
  final bool reverse;

  const ToastWrapper({
    super.key,
    this.isCheck = false,
    this.isWarning = false,
    required this.msg,
    this.icon,
    this.color,
    this.ignoreDrawer = false,
    this.reverse = false,
  });

  @override
  State<ToastWrapper> createState() => _ToastWrapperState();
}

class _ToastWrapperState extends State<ToastWrapper>
    with TickerProviderStateMixin {
  double opacity = 0.0;
  late AnimationController controller;
  late Animation<Offset> offset;
  bool opened = false;
  bool reverse = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    offset = Tween<Offset>(
            begin: widget.reverse ? const Offset(0.0, 1.0) : Offset.zero,
            end: widget.reverse ? Offset.zero : const Offset(0.0, 1.0))
        .animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
    Future.delayed(const Duration(milliseconds: 100)).then((value) {
      controller.reverse(from: 0.8);
      setState(() {
        opacity = 1.0;
        opened = true;
      });
    });
    Future.delayed(const Duration(milliseconds: 3000)).then((value) {
      setState(() {
        opacity = 0.0;
        reverse = true;
      });
      controller.forward();
    });
  }

// https://dash-overflow.net/articles/why_vsync/
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var color = widget.color ??
        (widget.isCheck
            ? Colors.greenAccent.withOpacity(0.8)
            : widget.isWarning
                ? Colors.orangeAccent.withOpacity(0.8)
                : Colors.redAccent.withOpacity(0.8));

    return IgnorePointer(
      child: Visibility(
        visible: opened,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: widget.reverse
                ? 0.0
                : (Variables.bottomBarHeight.toDouble() +
                    6 +
                    (Settings.useDrawer && !widget.ignoreDrawer ? 0.0 : 16.0)),
          ),
          child: SlideTransition(
            position: offset,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                    begin: reverse ? 10.0 : 0.1, end: reverse ? 0.001 : 10.0),
                duration: Duration(milliseconds: (reverse ? 500 : 700)),
                builder: (_, value, child) {
                  if (reverse && value < 0.1) return child!;
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
                    child: child,
                  );
                },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: opacity,
                  curve: Curves.easeInOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 12.0),
                    decoration: BoxDecoration(
                        color: Settings.themeWhat
                            ? Colors.black.withOpacity(0.6)
                            : Colors.grey.withOpacity(0.1)),
                    // decoration: BoxDecoration(
                    //   borderRadius: BorderRadius.circular(25.0),
                    //   color: widget.isCheck
                    //       ? Colors.greenAccent.withOpacity(0.8)
                    //       : widget.isWarning != null && widget.isWarning
                    //           ? Colors.orangeAccent.withOpacity(0.8)
                    //           : Colors.redAccent.withOpacity(0.8),
                    // ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.icon ??
                              (widget.isCheck
                                  ? Icons.check
                                  : widget.isWarning
                                      ? Icons.warning
                                      : Icons.cancel),
                          color: color,
                        ),
                        const SizedBox(
                          width: 12.0,
                        ),
                        Text(widget.msg, style: TextStyle(color: color)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
