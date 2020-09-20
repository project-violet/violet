// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/downloadable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/hitomi_parser.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';

class HitomiDonwloadManager extends Downloadable {
  RegExp urlMatcher;

  HitomiDonwloadManager() {
    urlMatcher = RegExp(
        r'^https?://hitomi\.la/(?:galleries|reader|cg|gamecg|doujinshi|manga)/((?<title>.*?)\-)?(?<id>\d+)(?:\.html|js)?$');
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    return "%(extractor)s/[%(id)s] %(title)s/%(file)s.%(ext)s";
  }

  @override
  String fav() {
    return 'https://ltn.hitomi.la/favicon-192x192.png';
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
    return 'hitomi';
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

    var result = List<DownloadTask>();
    if (articles != null && articles.length != 0) {
      var article = articles[0];

      gdp.simpleInfoCallback('[$id] ${article.title()}');

      var images = await HitomiManager.getImageList(id);

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
              extension:
                  path.extension(img.split('/').last).replaceAll(".", ""),
              extractor: 'hitomi',
            ),
          ),
        );
      }
    } else {
      var html = await http.get('https://ltn.hitomi.la/galleryblock/$id.html');
      var article = await HitomiParser.parseGalleryBlock(html.body);

      gdp.simpleInfoCallback('[$id] ${article['Title']}');

      var images = await HitomiManager.getImageList(id);

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
              title: article['Title'],
              id: id,
              filenameWithoutExtension: intToString(i, pad: 3),
              extension:
                  path.extension(img.split('/').last).replaceAll(".", ""),
              extractor: 'hitomi',
            ),
          ),
        );
      }
    }

    return result;
  }

  // https://stackoverflow.com/questions/15193983/is-there-a-built-in-method-to-pad-a-string
  static String intToString(int i, {int pad: 0}) {
    var str = i.toString();
    var paddingToAdd = pad - str.length;
    return (paddingToAdd > 0)
        ? "${new List.filled(paddingToAdd, '0').join('')}$i"
        : str;
  }
}
