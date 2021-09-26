// This source code is a part of Project Violet.
// Copyright (C) 2020-2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/cert/cert_data.dart';
import 'package:violet/cert/cert_util.dart';
import 'package:violet/cert/root.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/script/script_runner.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test("EHentai Gallery Parse", () async {
    var result =
        await HentaiManager.searchEHentai('"female:big breasts"', "0", false);

    expect(result.length >= 25, true);
  });

  test("Hitomi Article Info from Gallery Id", () async {
    const targetId = 1916981;

    var result = await HitomiManager.getImageList('$targetId');

    expect(result.item1.length, 42);
  });
}
