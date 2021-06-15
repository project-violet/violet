// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/downloadable.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/hitomi_parser.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/settings/settings.dart';

class HentaiDonwloadManager extends Downloadable {
  RegExp urlMatcher;

  HentaiDonwloadManager() {
    urlMatcher = RegExp(r'^\d+$');
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    //return "%(extractor)s/[%(id)s] %(title)s/%(file)s.%(ext)s";
    return Settings.downloadRule;
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
    return 'hentai';
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
    var query = (await HentaiManager.idSearch(url, 0)).item1;

    if (query.length == 0) {
      return null;
    }

    var target = query[0];

    gdp.simpleInfoCallback('[${target.id()}] ${target.title()}');

    var provider = await HentaiManager.getImageProvider(target);

    await provider.init();

    gdp.thumbnailCallback(await provider.getThumbnailUrl(),
        jsonEncode(await provider.getHeader(0)));

    var result = List<DownloadTask>();

    for (int i = 0; i < provider.length(); i++) {
      var page = await provider.getImageUrl(i);
      var header = await provider.getHeader(i);

      result.add(
        DownloadTask(
          url: page,
          filename: page.split('/').last,
          headers: header,
          format: FileNameFormat(
            title: target.title(),
            id: target.id().toString(),
            laugage: target.language(),
            uploadDate: target.getDateTime().toString(),
            filenameWithoutExtension: intToString(i, pad: 3),
            extension: path.extension(page.split('/').last).replaceAll(".", ""),
            extractor: 'hentai',
          ),
        ),
      );

      gdp.progressCallback(i + 1, provider.length());
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
