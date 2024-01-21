// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/network/wrapper.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test('Test Bookmark', () async {
    final _ = await http
        .get(Uri.parse('https://ltn.hitomi.la/galleries/2102839.js'), headers: {
      'referer': 'https://hitomi.la',
      'accept': HttpWrapper.accept,
      'user-agent': HttpWrapper.userAgent,
    });
  });
}
