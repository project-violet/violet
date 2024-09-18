// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:violet/api/api.swagger.dart';
import 'package:violet/server/wsalt.dart';

abstract class VioletServerV2 extends Api {
  static const protocol = 'https';
  static const host = 'koromo.xyz/api';
  static const api = '$protocol://$host';

  static late final Api instance;

  static void init() {
    instance = Api.create(
      baseUrl: Uri.parse(api),
      interceptors: [HmacInterceptor()],
    );
  }
}

class HmacInterceptor implements Interceptor {
  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
      Chain<BodyType> chain) async {
    final request = applyHeaders(chain.request, hmacHeader());
    return chain.proceed(request);
  }

  static Map<String, String> hmacHeader() {
    final vToken = DateTime.now().toUtc().millisecondsSinceEpoch;
    final vValid = getValid(vToken.toString());

    return {
      'v-token': vToken.toString(),
      'v-valid': vValid,
      'Content-Type': 'application/json'
    };
  }
}
