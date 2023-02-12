// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/component/hitomi/related.dart';
import 'package:violet/component/hitomi/tag_translate.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test('Test Translated', () async {
    await TagTranslate.init();

    var tag = TagTranslate.containsFuzzingTotal('그날그쪽에핀꽃은아무도모른다')
        .reversed
        .toList()
        .first
        .item1;

    const answer =
        'series:danshi koukousei de urekko light novel sakka o shiteiru keredo';
    expect(tag.getTag(), answer);
  });

  test('Test Population', () async {
    await Population.init();

    expect(Population.population.isNotEmpty, true);
  });

  test('Test Related', () async {
    await Related.init();

    print(Related.related);

    expect(Related.related.isNotEmpty, true);
  });
}
