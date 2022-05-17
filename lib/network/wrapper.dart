// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:violet/log/log.dart';
import 'package:violet/thread/semaphore.dart';

class HttpWrapper {
  static String accept =
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8';
  static String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36';
  static String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 6.0.1; Moto G (4)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Mobile Safari/537.36';
  static Semaphore throttlerExHentai = Semaphore(maxCount: 1);
  static Semaphore throttlerEHentai = Semaphore(maxCount: 4);
  static Map<String, http.Response> cacheResponse = <String, http.Response>{};
}

Future<http.Response> get(String url, {Map<String, String> headers}) async {
  if (url.contains('exhentai.org')) {
    if (HttpWrapper.cacheResponse.containsKey(url)) {
      return HttpWrapper.cacheResponse[url];
    }
    await HttpWrapper.throttlerExHentai.acquire();
    if (HttpWrapper.cacheResponse.containsKey(url)) {
      HttpWrapper.throttlerExHentai.release();
      return HttpWrapper.cacheResponse[url];
    }
    Logger.info('[Http Request] GET: $url');
    var retry = 0;
    while (true) {
      var res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: retry > 3 ? 1000000 : 3), onTimeout: () {
        return null;
      });
      retry++;
      if (res == null) {
        Logger.info('[Http Request] GETS: $url, $retry');
        continue;
      }
      if (res.statusCode != 200) {
        Logger.warning('[Http Response] CODE: ${res.statusCode}, GET: $url');
      }
      Logger.info('[Http Request] GETS: $url');
      if (!HttpWrapper.cacheResponse.containsKey(url) &&
          res.statusCode == 200) {
        HttpWrapper.cacheResponse[url] = res;
      }
      HttpWrapper.throttlerExHentai.release();
      return res;
    }
  } else if (url.contains('e-hentai.org')) {
    if (HttpWrapper.cacheResponse.containsKey(url)) {
      return HttpWrapper.cacheResponse[url];
    }
    await HttpWrapper.throttlerEHentai.acquire();
    if (HttpWrapper.cacheResponse.containsKey(url)) {
      HttpWrapper.throttlerEHentai.release();
      return HttpWrapper.cacheResponse[url];
    }
    Logger.info('[Http Request] GET: $url');
    var retry = 0;
    while (true) {
      var res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: retry > 3 ? 1000000 : 3), onTimeout: () {
        return null;
      }).catchError((e, st) {
        Logger.error('[Http Request] GET: $url\n'
            'E:$e\n'
            '$st');
      });
      retry++;
      if (res == null) {
        Logger.info('[Http Request] GETS: $url, $retry');
        continue;
      }
      if (res.statusCode != 200) {
        Logger.warning('[Http Response] CODE: ${res.statusCode}, GET: $url');
      }
      Logger.info('[Http Request] GETS: $url');
      if (!HttpWrapper.cacheResponse.containsKey(url) &&
          res.statusCode == 200) {
        HttpWrapper.cacheResponse[url] = res;
      }
      HttpWrapper.throttlerEHentai.release();
      return res;
    }
  } else if (url.contains('ltn.hitomi.la') ||
      url.contains(
          'raw.githubusercontent.com/project-violet/violet-message-search')) {
    Logger.info('[Http Cache] GET: $url');
    if (HttpWrapper.cacheResponse.containsKey(url)) {
      return HttpWrapper.cacheResponse[url];
    }
    var res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) {
      Logger.warning('[Http Response] CODE: ${res.statusCode}, GET: $url');
    }
    if (!HttpWrapper.cacheResponse.containsKey(url) && res.statusCode == 200) {
      HttpWrapper.cacheResponse[url] = res;
    }
    return res;
  } else {
    Logger.info('[Http Request] GET: $url');
    var res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) {
      Logger.warning('[Http Response] CODE: ${res.statusCode}, GET: $url');
    }
    return res;
  }
}

Future<http.Response> post(String url,
    {Map<String, String> headers, dynamic body, Encoding encoding}) async {
  Logger.info('[Http Request] POST: $url\n'
      'HEADERS: ${jsonEncode(headers)}\n'
      'BODY: $body');
  var res = await http.post(Uri.parse(url),
      headers: headers, body: body, encoding: encoding);
  if (res.statusCode != 200) {
    Logger.warning('[Http Response] CODE: ${res.statusCode}, POST: $url');
  }
  return res;
}
