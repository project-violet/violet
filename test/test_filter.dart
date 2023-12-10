// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter_test/flutter_test.dart';
import 'package:violet/database/query.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';

void main() {
  test('Test Filter Simple', () async {
    var filter = FilterController();
    filter.tagStates = {'male|shota': true};

    final sampleQuery = [
      QueryResult(result: {'Tags': '|male:shota|'}),
      QueryResult(result: {'Tags': '|female:sole female|'}),
    ];

    expect(filter.applyFilter(sampleQuery).first.tags(), '|male:shota|');
  });
}
