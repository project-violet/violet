// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/hitomi/tag_translate.dart';

void main() {
  group('Query Test', () {
    setUp(() async {
      await TagTranslate.init();
    });

    test('Translate Korean Simple', () {
      expect(TagTranslate.ofAny('sole female'), '단독여성');
      expect(TagTranslate.ofAny('pokemon'), '포켓몬');
      expect(TagTranslate.ofAny('teitoku'), '제독');
    });
  });
}
