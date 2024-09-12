// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/api/api.swagger.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test('Test Downloader', () async {
    final api = Api.create(baseUrl: Uri.parse('http://localhost:3000'));
    final ss = await api.apiV2Get();
    print(ss);
  });
}
