// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter_test/flutter_test.dart';
import 'package:violet/api/api.swagger.dart';
import 'package:violet/server/violet_v2.dart';

class MockApi {
  static late final Api instance;

  static void init() {
    instance = Api.create(
      baseUrl: Uri.parse('http://localhost:3000'),
      interceptors: [HmacInterceptor()],
    );
  }
}

void main() {
  MockApi.init();

  test('Test Hello', () async {
    final res = await MockApi.instance.apiV2Get();
    expect(res.body as String, 'Hello World!');
  });

  test('Test Hmac', () async {
    final res = await MockApi.instance.apiV2HmacGet();
    expect(res.statusCode, 200);
  });
}
