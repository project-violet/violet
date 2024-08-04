// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:violet/settings/settings.dart';

class SettingsWrapper {
  static const _imageQuality = [
    FilterQuality.none,
    FilterQuality.high,
    FilterQuality.medium,
    FilterQuality.low,
  ];

  static FilterQuality get imageQuality => _imageQuality[Settings.imageQuality];

  static FilterQuality getImageQuality(int value) => _imageQuality[value];
}
