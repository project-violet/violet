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

abstract class Downloadable {
  bool loginRequire();
  Session getSession(String id, String pwd);
  bool acceptURL(String url);
}
