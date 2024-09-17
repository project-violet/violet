// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/src/rust/api/simple.dart';
import 'package:violet/src/rust/frb_generated.dart';

void main() {
  if (!Platform.isWindows) {
    return;
  }

  setUp(() async {
    await RustLib.init(
      externalLibrary:
          ExternalLibrary.open('rust/target/debug/rust_lib_violet.dll'),
    );
  });

  test('Test unzip', () async {
    await decompress7Z(src: 'test/rawdata-korean.7z', dest: 'test');
  });
}
