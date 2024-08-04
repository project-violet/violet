// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/material.dart';

class ThemeSwitchableStateTargetStore {
  static final List<ThemeSwitchable> targets = <ThemeSwitchable>[];

  static void append(ThemeSwitchable themeSwitchable) {
    targets.add(themeSwitchable);
  }

  static void remove(ThemeSwitchable themeSwitchable) {
    targets.remove(themeSwitchable);
  }

  static void doChange() {
    Timer.run(() {
      for (var element in targets) {
        element.checkDirty();
      }
    });
  }
}

abstract class ThemeSwitchable {
  void checkDirty();
}

abstract class ThemeSwitchableState<T extends StatefulWidget> extends State<T>
    implements ThemeSwitchable {
  bool themeChanged = false;

  @override
  void initState() {
    super.initState();
    ThemeSwitchableStateTargetStore.append(this);
  }

  @override
  void dispose() {
    super.dispose();
    ThemeSwitchableStateTargetStore.remove(this);
  }

  @override
  Widget build(BuildContext context) {
    throw UnsupportedError('theme switchable state');
  }

  @override
  void checkDirty() {
    themeChanged = true;
    if (themeChanged) shouldReloadCallback?.call();
    setState(() {});
  }

  @protected
  VoidCallback? get shouldReloadCallback;
}
