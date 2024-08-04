// https://stackoverflow.com/questions/49869873/flutter-update-widgets-on-resume/54198839

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback? resumeCallBack;
  final AsyncCallback? suspendingCallBack;
  final AsyncCallback? inactiveCallBack;
  final AsyncCallback? pausedCallBack;

  LifecycleEventHandler({
    this.resumeCallBack,
    this.suspendingCallBack,
    this.inactiveCallBack,
    this.pausedCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if (resumeCallBack != null) await resumeCallBack!();
        break;
      case AppLifecycleState.inactive:
        if (inactiveCallBack != null) await inactiveCallBack!();
        break;
      case AppLifecycleState.paused:
        if (pausedCallBack != null) await pausedCallBack!();
        break;
      case AppLifecycleState.detached:
        if (suspendingCallBack != null) await suspendingCallBack!();
        break;
      default:
        // TODO: Implement properly
        break;
    }
  }
}
