// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

// Reference https://github.com/rollrat/downloader/blob/master/Koromo_Copy.Framework/Extractor/PixivExtractor.cs

import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:violet/component/downloadable.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';

class EHentaiManager extends Downloadable {
  RegExp urlMatcher;

  EHentaiManager() {
    urlMatcher = RegExp(r'^https?://e-hentai.org/g/(?<id>\d+)/(?<hash>\w+)/?$');
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    return "%(extractor)s/%(artist)s/[%(id)s] %(title)s/%(file)s.%(ext)s";
  }

  @override
  String fav() {
    return 'https://e-hentai.org/favicon.ico';
  }

  @override
  bool loginRequire() {
    return false;
  }

  @override
  bool logined() {
    return false;
  }

  @override
  String name() {
    return 'ehentai';
  }

  @override
  Future<void> setSession(String id, String pwd) async {}

  @override
  Future<bool> tryLogin() async {
    return true;
  }

  @override
  Future<List<DownloadTask>> createTask(
      String url, GeneralDownloadProgress gdp) async {
    var match = urlMatcher.allMatches(url);
    var id = match.first.namedGroup('id').trim();

    var articles = (await (await DataBaseManager.getInstance()).query(
            "SELECT * FROM HitomiColumnModel WHERE Id=$id ORDER BY Id DESC LIMIT 1 OFFSET 0"))
        .map((e) => QueryResult(result: e))
        .toList();

    if (articles == null || articles.length == 0) {
      return null;
    }

    var article = articles[0];

    gdp.simpleInfoCallback('[$id] ${article.title()}');

    var images = await HitomiManager.getImageList(id);
    var result = List<DownloadTask>();

    gdp.thumbnailCallback(images.item2[0],
        jsonEncode({'Referer': 'https://hitomi.la/reader/$id.html'}));

    for (int i = 0; i < images.item1.length; i++) {
      var img = images.item1[i];
      result.add(
        DownloadTask(
          url: img,
          filename: img.split('/').last,
          referer: 'https://hitomi.la/reader/$id.html',
          format: FileNameFormat(
            title: article.title(),
            id: id,
            laugage: article.language(),
            uploadDate: article.getDateTime().toString(),
            filenameWithoutExtension: intToString(i, pad: 3),
            extension: path.extension(img.split('/').last).replaceAll(".", ""),
            extractor: 'hitomi',
          ),
        ),
      );
    }

    return result;
  }

  // https://stackoverflow.com/questions/15193983/is-there-a-built-in-method-to-pad-a-string
  static String intToString(int i, {int pad: 0}) {
    var str = i.toString();
    var paddingToAdd = pad - str.length;
    return (paddingToAdd > 0)
        ? "${List.filled(paddingToAdd, '0').join('')}$i"
        : str;
  }
}
