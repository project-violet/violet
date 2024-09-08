// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'script_model.freezed.dart';
part 'script_model.g.dart';

@freezed
class ScriptImageList with _$ScriptImageList {
  const factory ScriptImageList({
    required List<String> result,
    required List<String> btresult,
    required List<String> stresult,
  }) = _ScriptImageList;

  factory ScriptImageList.fromJson(Map<String, Object?> json) =>
      _$ScriptImageListFromJson(json);
}
