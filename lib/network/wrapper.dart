// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
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

bool _isScriptUrl(String url) {
  const hosts = [
    'ltn.hitomi.la',
    'raw.githubusercontent.com/project-violet/violet-message-search'
  ];

  return hosts.any((element) => url.contains(element));
}

Future<http.Response> get(String url,
    {Map<String, String>? headers, Duration? timeout}) async {
  if (url.contains('exhentai.org') || url.contains('e-hentai.org')) {
    return await _ehentaiGet(
      url,
      headers: headers,
      timeout: timeout,
    );
  } else if (_isScriptUrl(url)) {
    return await _scriptGet(url, headers: headers, timeout: timeout);
  }

  Logger.info('[Http Request] GET: $url');
  final res = await http.get(Uri.parse(url), headers: headers);
  if (res.statusCode != 200) {
    Logger.warning('[Http Response] CODE: ${res.statusCode}, GET: $url');
  }

  return res;
}

Future<http.Response> post(String url,
    {Map<String, String>? headers, dynamic body, Encoding? encoding}) async {
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

Future<http.Response> _ehentaiGet(String url,
    {Map<String, String>? headers, Duration? timeout}) async {
  if (HttpWrapper.cacheResponse.containsKey(url)) {
    return HttpWrapper.cacheResponse[url]!;
  }

  var throttler = url.contains('exhentai.org')
      ? HttpWrapper.throttlerExHentai
      : HttpWrapper.throttlerEHentai;

  await throttler.acquire();

  if (HttpWrapper.cacheResponse.containsKey(url)) {
    throttler.release();
    return HttpWrapper.cacheResponse[url]!;
  }

  Logger.info('[Http Request] GET: $url');
  var retry = 0;

  while (true) {
    var timeout = false;

    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url))..followRedirects = true;

    if (headers != null) request.headers.addAll(headers);

    StreamedResponse response;

    try {
      response = await client.send(request).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          timeout = true;
          throw TimeoutException('Timeout error');
        },
      );
    } catch (e, st) {
      Logger.error('[Http Request] GET: $url\n'
          'E:$e\n'
          '$st');
      throttler.release();
      if (!(timeout || e.toString().contains('Connection reset by peer')) ||
          (timeout && retry > 10)) {
        rethrow;
      }
      response = StreamedResponse(const Stream.empty(), 200);
    }

    final res = await http.Response.fromStream(response);

    retry++;

    if (timeout) {
      if (retry > 3) throttler.release();
      Logger.info('[Http Request] GETS: $url, $retry');
      continue;
    }

    if (res.statusCode != 200) {
      Logger.warning('[Http Response] CODE: ${res.statusCode}, GET: $url');
    }

    Logger.info('[Http Request] GETS: $url');

    if (!HttpWrapper.cacheResponse.containsKey(url) && res.statusCode == 200) {
      HttpWrapper.cacheResponse[url] = res;
    }

    throttler.release();
    return res;
  }
}

Future<http.Response> _scriptGet(String url,
    {Map<String, String>? headers, Duration? timeout}) async {
  Logger.info('[Http Cache] GET: $url');

  if (HttpWrapper.cacheResponse.containsKey(url)) {
    return HttpWrapper.cacheResponse[url]!;
  }

  Response res;
  var _headers = headers ?? {};
  _headers['user-agent'] = HttpWrapper.userAgent;
  if (timeout == null) {
    res = await http.get(Uri.parse(url), headers: _headers);
  } else {
    bool isTimeout = false;
    var retry = 0;
    do {
      isTimeout = false;
      res = await http.get(Uri.parse(url), headers: _headers).timeout(
        timeout,
        onTimeout: () {
          isTimeout = true;
          retry++;
          return http.Response('', 200);
        },
      );
    } while (isTimeout && retry < 10);
  }

  if (res.statusCode != 200) {
    Logger.warning('[Http Response] CODE: ${res.statusCode}, GET: $url');
  }

  if (!HttpWrapper.cacheResponse.containsKey(url) &&
      res.statusCode == 200 &&
      res.body.trim().isNotEmpty) {
    HttpWrapper.cacheResponse[url] = res;
  }

  return res;
}
