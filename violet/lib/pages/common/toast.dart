// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:violet/widgets/toast.dart';

enum ToastLevel {
  check,
  warning,
  error,
}

void showToast({
  required ToastLevel level,
  required String message,
  IconData? icon,
}) {
  FToast().showToast(
    child: ToastWrapper(
      isCheck: false,
      isWarning: true,
      icon: icon,
      msg: message,
    ),
    ignorePointer: true,
    gravity: ToastGravity.BOTTOM,
    toastDuration: const Duration(seconds: 4),
  );
}
