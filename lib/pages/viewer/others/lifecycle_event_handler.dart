// https://stackoverflow.com/questions/49869873/flutter-update-widgets-on-resume/54198839

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback resumeCallBack;
  final AsyncCallback suspendingCallBack;
  final AsyncCallback inactiveCallBack;
  final AsyncCallback pausedCallBack;

  LifecycleEventHandler({
    required this.resumeCallBack,
    required this.suspendingCallBack,
    required this.inactiveCallBack,
    required this.pausedCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await resumeCallBack();
        break;
      case AppLifecycleState.inactive:
        await inactiveCallBack();
        break;
      case AppLifecycleState.paused:
        await pausedCallBack();
        break;
      case AppLifecycleState.detached:
        await suspendingCallBack();
        break;
    }
  }
}
