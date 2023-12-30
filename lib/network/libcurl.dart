// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_curl/flutter_curl.dart' as flutter_curl;
import 'package:violet/log/log.dart';
import 'package:violet/settings/settings.dart';

class Http3Request {
  Future<flutter_curl.Client> getClient() async {
    late final soPath;
    if (Platform.isAndroid) {
      soPath = (await _checkSharedLibraryAndroid('libcurl'))!;
      (await _checkSharedLibraryAndroid('libquiche'))!;
    } else {
      throw 'NOT_SUPPORTED';
    }
    flutter_curl.Client client = flutter_curl.Client(
        libPath: soPath, httpVersions: [flutter_curl.HTTPVersion.http3]);
    await client.init();
    return client;
  }

  Future<flutter_curl.Response> get(String url,
      {Map<String, String>? headers,
      String? body,
      Duration? timeout,
      bool? followRedirects = true}) async {
    flutter_curl.Client client = await getClient();
    flutter_curl.Response? res;
    do {
      flutter_curl.Request req = flutter_curl.Request(
        method: 'GET',
        url: res?.headers['location'] ?? url,
        headers: headers ?? {},
        body: (body?.isNotEmpty ?? false)
            ? flutter_curl.RequestBody.string(body ?? '')
            : null,
      );
      if (res?.headers['location']?.isNotEmpty ?? false) {
        req.headers.addAll({'Referer': req.url});
      }
      Logger.info('[Http3 Request] GET ${req.url}');
      var _sent = client.send(req);
      if (!Settings.ignoreHTTPTimeout && timeout != null) {
        _sent.timeout(timeout);
      }
      res = await _sent;
      Logger.info('[Http3 Request] GET ${req.url} code: ${res.statusCode}');
      if (((res.statusCode) / 100).floor() != 3) {
        break;
      }
    } while (followRedirects != false);
    return res;
  }

  Future<flutter_curl.Response> post(
    String url, {
    Map<String, String>? headers,
    String? body,
    Duration? timeout,
    bool? followRedirects = true,
  }) async {
    flutter_curl.Client client = await getClient();
    flutter_curl.Response? res;
    do {
      flutter_curl.Request req = flutter_curl.Request(
          method: 'POST',
          url: res?.headers['location'] ?? url,
          headers: headers ?? {},
          body: (body?.isNotEmpty ?? false)
              ? flutter_curl.RequestBody.string(body ?? '')
              : null);
      if (res?.headers['location']?.isNotEmpty ?? false) {
        req.headers.addAll({'Referer': req.url});
      }
      Logger.info('[Http3 Request] POST ${req.url}');
      var _sent = client.send(req);
      if (!Settings.ignoreHTTPTimeout && timeout != null) {
        _sent.timeout(timeout);
      }
      res = await _sent;
      Logger.info('[Http3 Request] POST ${req.url} code: ${res.statusCode}');
      if (((res.statusCode) / 100).floor() != 3) {
        break;
      }
    } while (followRedirects != false);
    return res;
  }

  static const libraryAbis = [
    'arm64-v8a',
    'armeabi-v7a',
    'x86_64',
  ];

  Future<String?> _checkSharedLibraryAndroid(String soName) async {
    if (!Platform.isAndroid) {
      return null;
    }

    final devicePlugin = DeviceInfoPlugin();
    final deviceInfo = await devicePlugin.androidInfo;

    final targetAbi = deviceInfo.supportedAbis.firstWhere(
      (abi) => libraryAbis.contains(abi),
    );
    if (!libraryAbis.contains(targetAbi)) {
      return null;
    }
    final sharedLibraryPath = 'assets/libcurl/android/$targetAbi/${soName}.so';
    final sharedLibraryContent = await rootBundle.load(sharedLibraryPath);

    final tempDir = await getTemporaryDirectory();
    final libraryFile = File('${tempDir.path}/${soName}.so');
    if (await libraryFile.exists()) {
      return libraryFile.path;
    }
    final createdFile = await libraryFile.create();
    final openFile = await createdFile.open(mode: FileMode.write);
    final writtenFile =
        await openFile.writeFrom(Uint8List.view(sharedLibraryContent.buffer));
    await writtenFile.close();

    return libraryFile.path;
  }

  static Future<http.Response> toHttpResponse(flutter_curl.Response res) async {
    return http.Response(
      String.fromCharCodes(res.body),
      res.statusCode,
      request: http.Request(
          res.request?.method ?? '', Uri.parse(res.request?.url ?? '')),
      headers: res.headers,
      isRedirect: (res.statusCode / 100).floor() == 3,
    );
  }

  static Future<http.StreamedResponse> toStreamedHttpResponse(
      flutter_curl.Response res) async {
    return http.StreamedResponse(
      Stream.value(res.body),
      res.statusCode,
      contentLength: res.body.length,
      request: http.Request(
          res.request?.method ?? '', Uri.parse(res.request?.url ?? '')),
      headers: res.headers,
      isRedirect: (res.statusCode / 100).floor() == 3,
    );
  }

  static Future<flutter_curl.Request> fromHttpRequest(http.Request req) async {
    return flutter_curl.Request(
        method: req.method,
        url: req.url.toString(),
        headers: req.headers,
        body: flutter_curl.RequestBody.string(req.body),
        verbose: false,
        verifySSL: true,
        httpVersions: [flutter_curl.HTTPVersion.http3]);
  }
}
