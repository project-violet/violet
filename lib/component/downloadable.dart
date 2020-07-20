// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:http/http.dart' as http;

enum DownloaderType {
  // Gelbooru, Danbooru, ...
  booru,

  // Hitomi.la, ...
  manga,

  // Tachiyomi Mangas
  // I have no plans to apply.
  mangaWithSeries,

  // Pixiv, ...
  album,
}

abstract class Session {
  String cookie;

  Future<String> requestString(String url) async {
    return (await http.get(url, headers: {"Cookie": cookie})).body;
  }
}

abstract class DownloadTask {
  int taskId;
  String accept =
      "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8";
  String userAgent =
      "Mozilla/5.0 (Android 7.0; Mobile; rv:54.0) Gecko/54.0 Firefox/54.0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.125 Mobile Safari/603.2.4";
  String referer;
  bool autoRedirection;
  bool retryWhenFail;
  int maxRetryCount;
  String cookie;
  String url;
  List<String> failUrls;
  Map<String, String> headers;
  Map<String, String> query;
  String filename;
}

abstract class Downloadable {
  bool loginRequire();
  Session getSession(String id, String pwd);
  bool acceptURL(String url);
  Future<List<DownloadTask>> createTask(String url);
}
