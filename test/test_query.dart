// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/settings/settings.dart';

void main() {
  group('Query Test', () {
    setUp(() async {
      await HitomiManager.loadIndexIfRequired();
    });

    test('Hitomi Query Auto Complete', () async {
      final result0 = await HitomiManager.queryAutoComplete('fema');
      final result1 = await HitomiManager.queryAutoComplete('random:');

      expect(result0[0].item1.toString(), 'tag:female:sole female');
      expect(result1.length, 0);
    });

    test('Hitomi Query Auto Complete Fuzzy', () async {
      final result0 = await HitomiManager.queryAutoCompleteFuzzy('michoking');
      final result1 =
          await HitomiManager.queryAutoCompleteFuzzy('artist:michoking');
      final result2 =
          await HitomiManager.queryAutoCompleteFuzzy('female:bigbreakfast');

      expect(result0[0].item1.toString(), 'artist:michiking');
      expect(result1[0].item1.toString(), 'artist:michiking');
      expect(result2[0].item1.toString(), 'tag:female:big breasts');
    });

    test('Hitomi Query To Sql', () {
      Settings.searchPure = false;
      final result0 = HitomiManager.translate2query(
          'female:sole_female (lang:korean or lang:n/a)');
      final result1 = HitomiManager.translate2query(
          'female:sole_female -(female:mother female:milf)');

      expect(result0,
          'SELECT * FROM HitomiColumnModel WHERE Tags LIKE \'%|female:sole female|%\' AND (Language LIKE \'%korean%\' OR Language LIKE \'%n/a%\')  AND ExistOnHitomi=1');
      expect(result1,
          'SELECT * FROM HitomiColumnModel WHERE Tags LIKE \'%|female:sole female|%\' AND NOT (Tags LIKE \'%|female:mother|%\' AND Tags LIKE \'%|female:milf|%\')  AND ExistOnHitomi=1');
    });
  });
}
