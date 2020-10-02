// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:violet/log/log.dart';

class HttpWrapper {
  static String accept =
      "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8";
  static String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.139 Safari/537.36";
  static String mobileUserAgent =
      "Mozilla/5.0 (Android 7.0; Mobile; rv:54.0) Gecko/54.0 Firefox/54.0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.125 Mobile Safari/603.2.4";
}

Future<http.Response> get(String url, {Map<String, String> headers}) async {
  Logger.info('[Http Request] GET: ' + url);
  var res = await http.get(url, headers: headers);
  if (res.statusCode != 200) {
    Logger.warning(
        '[Http Response] CODE: ' + res.statusCode.toString() + ', GET: ' + url);
  }
  return res;
}

Future<http.Response> post(String url,
    {Map<String, String> headers, dynamic body, Encoding encoding}) async {
  Logger.info('[Http Request] POST: ' + url);
  var res =
      await http.post(url, headers: headers, body: body, encoding: encoding);
  if (res.statusCode != 200) {
    Logger.warning('[Http Response] CODE: ' +
        res.statusCode.toString() +
        ', POST: ' +
        url);
  }
  return res;
}
