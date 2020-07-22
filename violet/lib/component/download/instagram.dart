// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

// Reference https://github.com/rollrat/downloader/blob/master/Koromo_Copy.Framework/Extractor/PixivExtractor.cs
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/downloadable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class InstaAPI {
  static const String postQueryHash = "58b6785bea111c67129decbe6a448951";
  static const String sidecarQueryHash = "865589822932d1b43dfe312121dd353a";

  static RegExp userMatcher;
  static Future<Map<String, dynamic>> getUser(
      String html, GeneralDownloadProgress gdp) async {
    if (userMatcher == null)
      userMatcher =
          RegExp(r'window\._sharedData = (.*);</script>', multiLine: true);

    var json = userMatcher.allMatches(html).first[1];
    var juser =
        jsonDecode(json)['entry_data']['ProfilePage'][0]['graphql']['user'];

    var result = {
      'userid': juser['id'],
      'username': juser['username'],
      'fullname': juser['full_name'],
      'totalpostscount': juser['edge_owner_to_timeline_media']['count'],
      'firstpost': {
        'hasnext': juser["edge_owner_to_timeline_media"]["page_info"]
            ["has_next_page"],
        'endcursor': juser["edge_owner_to_timeline_media"]["page_info"]
            ["end_cursor"],
        'displayurls': List<String>(),
        'postcount': 0,
      }
    };

    gdp.progressCallback(0, result['totalpostscount'] as int);
    gdp.thumbnailCallback(juser["profile_pic_url_hd"], null);

    for (var post in juser["edge_owner_to_timeline_media"]["edges"]) {
      result['firstpost']['postcount']++;
      if (post["node"]["__typename"] == "GraphImage") {
        result['firstpost']['displayurls'].add(post['node']['display_url']);
      } else {
        var shortCode = post['node']['shortcode'];
        var json2 = jsonDecode(
            await _graphqlQuery(sidecarQueryHash, {'shortcode': shortCode}));

        if (post['node']['__typename'] == 'GraphVideo') {
          var media = jsonDecode(json2['data']['shortcode_media']);
          // extract video
          _extractUrl(media, result['firstpost']['displayurls']);
        } else {
          for (var media in json2["data"]["shortcode_media"]
              ["edge_sidecar_to_children"]["edges"])
            _extractUrl(media['node'], result['firstpost']['displayurls']);
        }
      }
    }

    return result;
  }

  static Future<Map<String, dynamic>> queryNext(
      String queryHash, String id, String first, String after) async {
    while (true) {
      try {
        var json = jsonDecode(await _graphqlQuery(
            queryHash, {'id': id, 'first': first, 'after': after}));
        var jmedia = json['data']['user']['edge_owner_to_timeline_media'];

        var posts = {
          'hasnext': jmedia["page_info"]["has_next_page"],
          'endcursor': jmedia["page_info"]["end_cursor"],
          'displayurls': List<String>(),
          'postcount': 0,
        };

        for (var post in jmedia["edges"]) {
          posts['postcount'] += 1;

          if (post["node"]["__typename"] != "GraphSidecar") {
            _extractUrl(post["node"], posts['displayurls']);
          } else {
            for (var media in post["node"]["edge_sidecar_to_children"]["edges"])
              _extractUrl(media["node"], posts['displayurls']);
          }
        }

        return posts;
      } catch (e) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  static void _extractUrl(dynamic media, List<String> urls) {
    if (media['is_video'] != null && media['is_video']) {
      urls.add(media['video_url']);
      // Thumbnail
      // urls.add(media['display_url']);
    } else {
      urls.add(media['display_url']);
    }
  }

  static Future<String> _graphqlQuery(
      String queryHash, Map<String, String> param) async {
    var url = "https://www.instagram.com/graphql/query/?query_hash=" +
        queryHash +
        "&variables=" +
        Uri.encodeQueryComponent(jsonEncode(param));
    return (await http.get(url)).body;
  }
}

class InstagramManager extends Downloadable {
  RegExp urlMatcher;

  InstagramManager() {
    urlMatcher =
        RegExp(r'^https?://(www\.)?instagram\.com/(?:p\/)?(?<id>.*?)/?.*?$');
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    return "%(extractor)s/%(user)s (%(account)s)/%(file)s.%(ext)s";
  }

  @override
  String fav() {
    return 'https://www.instagram.com/static/images/ico/favicon-192.png/68d99ba29cc8.png';
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
    return 'instagram';
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
    var html = (await http.get(url)).body;
    var user = await InstaAPI.getUser(html, gdp);
    var urls = List<String>();
    urls.addAll(user['firstpost']['displayurls']);

    gdp.progressCallback(user['firstpost']['postcount'] as int, 0);

    gdp.simpleInfoCallback('${user['fullname']} (${user['username']})');

    var count = 0;
    var pp = user['firstpost'];
    while (pp['hasnext']) {
      // TODO: Adjust This Limit
      if (count >= 1000) break;

      var posts = await InstaAPI.queryNext(
          InstaAPI.postQueryHash, user['userid'], "50", pp['endcursor']);
      urls.addAll(posts['displayurls']);
      gdp.progressCallback(urls.length, 0);
      count += 50;
      pp = posts;
    }

    var result = List<DownloadTask>();
    urls.forEach((element) {
      var fn = element.split('?')[0].split('/').last;

      result.add(
        DownloadTask(
          url: element,
          filename: fn,
          format: FileNameFormat(
            user: user['fullname'],
            account: user['username'],
            filenameWithoutExtension: path.basenameWithoutExtension(fn),
            extension: path.extension(fn).replaceAll(".", ""),
            extractor: 'instagram',
          ),
        ),
      );
    });

    return result;
  }
}
