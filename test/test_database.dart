// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:violet/settings/settings.dart';

void main() {
  late final Database db;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    Settings.searchPure = true;
    Settings.includeTags = '';
    Settings.excludeTags = [''];

    db = await databaseFactoryFfi
        .openDatabase(join(Directory.current.path, 'test/db/data.db'));
  });

  test('Test korean db search', () async {
    final queryString =
        HitomiManager.translate2query('artist:michiking (lang:korean)');
    final count = (await db.rawQuery(queryString.replaceAll(
        'SELECT * FROM', 'SELECT COUNT(*) as cnt FROM')));

    expect(count[0]['cnt']! as int, isNot(0));
  });

  test('Test korean db search random', () async {
    final search = await HentaiManager.search('lang:korean random');

    expect(search.results.length, isNot(0));
  });
}
