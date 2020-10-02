// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:html/parser.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:path/path.dart' as path;
import 'package:violet/component/downloadable.dart';

class SankakuManager extends Downloadable {
  RegExp urlMatcher;

  SankakuManager() {
    // currently chan only support
    urlMatcher =
        RegExp(r'^https?://chan.sankakucomplex.com/\?tags\=(?<tag>.*?)$');
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    return "%(extractor)s/%(search)s/%(file)s.%(ext)s";
  }

  @override
  String saveOneFormat() {}

  @override
  String fav() {
    return 'https://chan.sankakucomplex.com/favicon.png';
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
    return 'sankakucomplex';
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
    var match = urlMatcher.firstMatch(url);
    var tag = HtmlUnescape().convert(match.namedGroup('tag'));

    gdp.simpleInfoCallback.call(tag);

    var html = (await http.get(url)).body;
    var result = List<DownloadTask>();

    var rr = RegExp(r'/post/show/\d+');
    var rx = RegExp(r'next\-page\-url\="(.*?)"');
    String next;
    try {
      next = HtmlUnescape().convert(rx.firstMatch(html).group(1));
    } catch (e) {}

    var subLinks = rr.allMatches(html).map((e) => e.group(0)).toList();

    print(next);

    while (next != null) {
      try {
        var shtml =
            (await http.get('https://chan.sankakucomplex.com' + next)).body;

        try {
          next = HtmlUnescape().convert(rx.firstMatch(shtml).group(1));
        } catch (e) {
          next = null;
        }

        subLinks.addAll(rr.allMatches(shtml).map((e) => e.group(0)).toList());

        gdp.progressCallback.call(subLinks.length, 0);
        if (subLinks.length > 100) break;
      } catch (e) {
        await Future.delayed(Duration(seconds: 4));
      }
    }

    var postThumbnail = false;
    for (int i = 0; i < subLinks.length; i++) {
      try {
        var surl = 'https://chan.sankakucomplex.com' + subLinks[i];
        var shtml = (await http.get(surl)).body;

        var doc = parse(shtml).querySelector('div[id=post-content]');

        // break;
        if (doc.querySelector('video') != null) {
          var content = 'https:' +
              HtmlUnescape()
                  .convert(doc.querySelector('video').attributes['src']);

          result.add(DownloadTask(
              url: content,
              filename: '',
              referer: surl,
              format: FileNameFormat(
                search: tag,
                filenameWithoutExtension:
                    intToString(result.length + 1, pad: 3),
                extension: 'mp4',
                extractor: 'sankaku',
              )));
        } else if (doc.querySelector('a') != null &&
            doc.querySelector('a').attributes['class'] == 'sample') {
          var content = 'https:' +
              HtmlUnescape().convert(doc.querySelector('a').attributes['href']);

          if (postThumbnail) {
            gdp.thumbnailCallback.call(content, jsonEncode({'Referer': surl}));
            postThumbnail = true;
          }

          result.add(DownloadTask(
              url: content,
              filename: '',
              accept: 'image/webp,*/*',
              referer: surl,
              format: FileNameFormat(
                search: tag,
                filenameWithoutExtension:
                    intToString(result.length + 1, pad: 3),
                extension: path
                    .extension(content.split('/').last.split('?').first)
                    .replaceAll(".", ""),
                extractor: 'sankaku',
              )));
        } else if (doc.querySelector('img') != null) {
          var content = 'https:' +
              HtmlUnescape()
                  .convert(doc.querySelector('img').attributes['src']);

          if (postThumbnail) {
            gdp.thumbnailCallback.call(content, jsonEncode({'Referer': surl}));
            postThumbnail = true;
          }

          result.add(DownloadTask(
              url: content,
              accept: 'image/webp,*/*',
              filename: '',
              referer: surl,
              format: FileNameFormat(
                search: tag,
                filenameWithoutExtension:
                    intToString(result.length + 1, pad: 3),
                extension: path
                    .extension(content.split('/').last.split('?').first)
                    .replaceAll(".", ""),
                extractor: 'sankaku',
              )));
        }
        gdp.progressCallback.call(subLinks.length, i + 1);
      } catch (e) {
        await Future.delayed(Duration(seconds: 4));
        i--;

        print(e);
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
