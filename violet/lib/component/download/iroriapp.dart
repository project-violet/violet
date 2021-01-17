// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:violet/component/downloadable.dart';
import 'package:violet/network/wrapper.dart' as http;

class IroriAppManager extends Downloadable {
  RegExp urlMatcher;

  IroriAppManager() {
    urlMatcher = RegExp(r'^https://irori.app/(?<id>.*?)#?$');
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    return "%(extractor)s/%(artist)s (%(account)s)/%(file)s.%(ext)s";
  }

  @override
  String saveOneFormat() {}

  @override
  String fav() {
    return 'https://irori.app/favicon.ico';
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
    return 'iroriapp';
  }

  @override
  Future<void> setSession(String id, String pwd) async {}

  @override
  Future<bool> tryLogin() async {
    return true;
  }

  @override
  bool supportCommunity() {
    return false;
  }

  @override
  bool acceptCommunity(String url) {
    return false;
  }

  @override
  Future<List<DownloadTask>> createTask(
      String url, GeneralDownloadProgress gdp) async {
    var match = urlMatcher.allMatches(url);

    var result = List<DownloadTask>();

    // https://irori.app/api/post/list/@shira_tama_2gou?size=100
    // X-Requested-With: XMLHttpRequest

    var id = match.first.namedGroup('id');
    var firstloop = true;

    var i = 0;
    var cursor = '';
    do {
      var json = jsonDecode((await http.get(
              'https://irori.app/api/post/list/$id?size=100' + cursor,
              headers: {'X-Requested-With': 'XMLHttpRequest'}))
          .body);

      if (firstloop) {
        gdp.simpleInfoCallback(
            '${json['user']['name']} (${json['user']['username']})');
        gdp.thumbnailCallback(
            json['user']['icon'], jsonEncode({'Referer': url}));
        firstloop = true;
      }

      for (var post in json['posts']) {
        result.add(
          DownloadTask(
            url: post['media_url'] + '/' + post['ex_data']['filename'],
            // filename: fn,
            referer: url,
            format: FileNameFormat(
              artist: json['user']['name'],
              account: json['user']['username'],
              filenameWithoutExtension: intToString(i, pad: 3),
              extension: post['ex_data']['filename'].split('.').last,
              extractor: 'iroriapp',
            ),
          ),
        );
        i++;
        cursor = '&cursor=' + post['id'].toString();
      }

      gdp.progressCallback(result.length, 0);

      if (!json['has_next']) break;
    } while (true);

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

  @override
  String communityName() {
    return null;
  }
}
