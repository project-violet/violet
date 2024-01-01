// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:violet/component/downloadable.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/query.dart';
import 'package:violet/settings/settings.dart';

class HentaiDonwloadManager {
  factory HentaiDonwloadManager.instance() => HentaiDonwloadManager();

  late RegExp urlMatcher;

  HentaiDonwloadManager() {
    urlMatcher = RegExp(r'^\d+$');
  }

  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  String defaultFormat() {
    //return "%(extractor)s/[%(id)s] %(title)s/%(file)s.%(ext)s";
    return Settings.downloadRule;
  }

  String fav() {
    return 'https://ltn.hitomi.la/favicon-192x192.png';
  }

  bool loginRequire() {
    return false;
  }

  bool logined() {
    return false;
  }

  String name() {
    return 'hentai';
  }

  Future<void> setSession(String id, String pwd) async {}

  Future<bool> tryLogin() async {
    return true;
  }

  Future<List<DownloadTask>?> createTask(
      String url, GeneralDownloadProgress gdp) async {
    final query = (await HentaiManager.idSearch(url)).results;

    if (query.isEmpty) {
      return null;
    }

    return await createTaskFromQueryResult(query.first, gdp);
  }

  Future<List<DownloadTask>?> createTaskFromQueryResult(
      QueryResult target, GeneralDownloadProgress gdp) async {
    gdp.simpleInfoCallback('[${target.id()}] ${target.title()}');

    var provider = await HentaiManager.getImageProvider(target);

    await provider.init();

    var thumbnailUrl = await provider.getThumbnailUrl();
    var thumbnailHeader = await provider.getHeader(0);
    gdp.thumbnailCallback(thumbnailUrl, jsonEncode(thumbnailHeader));

    var result = <DownloadTask>[];

    //
    //    Add Images
    //
    for (int i = 0; i < provider.length(); i++) {
      var page = await provider.getImageUrl(i);
      var header = await provider.getHeader(i);

      result.add(
        DownloadTask(
          url: page,
          headers: header,
          format: FileNameFormat(
            title: target.title(),
            id: target.id().toString(),
            laugage: target.language(),
            uploadDate: target.getDateTime().toString(),
            filenameWithoutExtension: intToString(i, pad: 3),
            artist: target.artists() != null
                ? target.artists().split('|').firstWhere(
                    (artist) => artist != null && (artist as String).isNotEmpty)
                : target.groups() != null
                    ? target.groups().split('|').firstWhere((group) =>
                        group != null && (group as String).isNotEmpty)
                    : null,
            group: target.groups() != null
                ? target.groups().split('|').firstWhere(
                    (group) => group != null && (group as String).isNotEmpty)
                : null,
            extension: page.contains('fullimg.php')
                ? 'jpg'
                : path.extension(page.split('/').last).replaceAll('.', ''),
            extractor: 'hentai',
            downloadDate: DateTime.now().toString(),
            className: target.classname(),
            length: provider.length().toString(),
          ),
        ),
      );

      gdp.progressCallback(i + 1, provider.length());
    }

    return result;
  }

  // https://stackoverflow.com/questions/15193983/is-there-a-built-in-method-to-pad-a-string
  static String intToString(int i, {int pad = 0}) {
    var str = i.toString();
    var paddingToAdd = pad - str.length;
    return (paddingToAdd > 0)
        ? "${List.filled(paddingToAdd, '0').join('')}$i"
        : str;
  }
}
