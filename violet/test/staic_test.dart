// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/component/hitomi/related.dart';
import 'package:violet/component/hitomi/tag_translate.dart';

void main() {
  setUp(() async {
    await TagTranslate.init();

    WidgetsFlutterBinding.ensureInitialized();
  });

  test('Test Translated', () async {
    final tag = TagTranslate.containsFuzzingTotal('그날그쪽에핀꽃은아무도모른다')
        .reversed
        .toList()
        .first
        .$1;

    const answer =
        'series:danshi koukousei de urekko light novel sakka o shiteiru keredo';

    expect(tag.getTag(), answer);
  });

  test('Test Autocomplete', () async {
    final query = (await HitomiManager.queryAutoComplete('청춘', true)).toList();

    final t1 = query.any((e) =>
        e.$1.getTag() ==
        'series:yahari ore no seishun love come wa machigatteiru');

    final t2 = query.any((e) =>
        e.$1.getTag() ==
        'series:seishun buta yarou wa bunny girl senpai no yume o minai');

    expect(t1 && t2, true);
  });

  test('Test Population', () async {
    await Population.init();

    expect(Population.population.isNotEmpty, true);
  });

  test('Test Related', () async {
    await Related.init();

    expect(Related.related.isNotEmpty, true);
  });
}
