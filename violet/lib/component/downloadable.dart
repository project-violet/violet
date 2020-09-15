// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:violet/component/download/gelbooru.dart';
import 'package:violet/component/download/hitomi.dart';
import 'package:violet/component/download/instagram.dart';
import 'package:violet/component/download/pixiv.dart';
import 'package:violet/component/download/twitter.dart';

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

typedef StringCallback = Future Function(String);
typedef VoidStringCallback = void Function(String);
typedef DoubleIntCallback = Future Function(int, int);
typedef DoubleStringCallback = Future Function(String, String);
typedef DoubleCallback = void Function(double);
typedef DoubleDoubleCallback = Future Function(double, double);

class DownloadTask {
  final int taskId;
  final String accept;
  final String userAgent;
  final String referer;
  final bool autoRedirection;
  final bool retryWhenFail;
  final int maxRetryCount;
  final String cookie;
  final String url;
  final List<String> failUrls;
  final Map<String, String> headers;
  final Map<String, String> query;
  final String filename;
  final FileNameFormat format;

  // This callback used in downloader
  String downloadPath;
  DoubleCallback sizeCallback;
  DoubleCallback downloadCallback;
  VoidStringCallback errorCallback;
  VoidCallback startCallback;
  VoidCallback completeCallback;

  DownloadTask({
    this.taskId,
    this.accept =
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
    this.userAgent =
        "Mozilla/5.0 (Android 7.0; Mobile; rv:54.0) Gecko/54.0 Firefox/54.0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.125 Mobile Safari/603.2.4",
    this.referer,
    this.autoRedirection,
    this.retryWhenFail,
    this.maxRetryCount,
    this.cookie,
    this.url,
    this.failUrls,
    this.headers,
    this.query,
    this.filename,
    this.format,
  });
}

class PostProcessorTask {}

class FileNameFormat {
  final String title;
  final String id;
  final String originalTitle;
  final String extractor;
  final String user;
  final String account;
  final String author;
  final String englishAuthor;
  final String group;
  final String artist;
  final String search;
  final String uploadDate;
  final String uploader;
  final String uploaderId;
  final String character;
  final String gallery;
  final String series;
  final String seasonNumber;
  final String episode;
  final String episodeNumber;
  final String filenameWithoutExtension;
  final String extension;
  final String url;
  final String license;
  final String genre;
  final String laugage;

  FileNameFormat({
    this.title,
    this.id,
    this.originalTitle,
    this.extractor,
    this.user,
    this.account,
    this.author,
    this.englishAuthor,
    this.group,
    this.artist,
    this.search,
    this.uploadDate,
    this.uploader,
    this.uploaderId,
    this.character,
    this.gallery,
    this.series,
    this.seasonNumber,
    this.episode,
    this.episodeNumber,
    this.filenameWithoutExtension,
    this.extension,
    this.url,
    this.license,
    this.genre,
    this.laugage,
  });

  String formatting(String raw) {
    var format = {
      "title": title,
      "id": id,
      "originalTitle": originalTitle,
      "extractor": extractor,
      "user": user,
      "account": account,
      "author": author,
      "englishAuthor": englishAuthor,
      "group": group,
      "artist": artist,
      "search": search,
      "uploadDate": uploadDate,
      "uploader": uploader,
      "uploaderId": uploaderId,
      "character": character,
      "gallery": gallery,
      "series": series,
      "seasonNumber": seasonNumber,
      "episode": episode,
      "episodeNumber": episodeNumber,
      "filenameWithoutExtension": filenameWithoutExtension,
      "extension": extension,
      "file": filenameWithoutExtension,
      "ext": extension,
      "url": url,
      "license": license,
      "genre": genre,
      "laugage": laugage,
    };

    var builder = new StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      if (raw[i] == '%') {
        i++;

        if (raw[i] == '%') {
          builder.write('%');
          continue;
        }

        if (raw[i++] != '(')
          throw new Exception("Filename formatting error! pos=" + i.toString());

        var tokenb = new StringBuffer();

        for (; i < raw.length; i++) {
          if (raw[i] == ')') {
            i++;
            break;
          }

          tokenb.write(raw[i]);
        }

        var token = tokenb.toString().toLowerCase();
        String literal;

        if (format.containsKey(token)) literal = format[token];

        var pp = new StringBuffer();
        var type = 's';

        for (; i < raw.length; i++) {
          if (raw[i] != ' ' &&
              raw[i] != '%' &&
              raw[i] != '(' &&
              raw[i] != ')') {
            type = raw[i];
            break;
          }
          pp.write(raw[i]);
        }

        var pptk = pp.toString();

        if (type == 's') {
          if (pptk != "")
            builder.write(literal.substring(0, int.parse(pptk)));
          else
            builder.write(literal.toString());
        }
        // else if (type == 'd')
        // {
        //     builder.write(literal.ToInt().ToString(pptk));
        // }
        // else if (type == 'x' || type == 'X')
        // {
        //     builder.Append(literal.ToInt().ToString(type + pptk));
        // }
        // else if (type == 'f')
        // {
        //     builder.Append(float.Parse(literal).ToString(pptk));
        // }
      } else
        builder.write(raw[i]);
    }

    var result = builder.toString().replaceAll('|', 'ㅣ');

    // var invalid = new string(Path.GetInvalidFileNameChars()) + new string(Path.GetInvalidPathChars());
    // foreach (char c in invalid) if (c != '/' && c!= '\\') result = result.Replace(c.ToString(), "");

    return result;
  }
}

class GeneralDownloadProgress {
  final StringCallback simpleInfoCallback;
  // (URL, Header)
  final DoubleStringCallback thumbnailCallback;
  final DoubleIntCallback progressCallback;

  GeneralDownloadProgress({
    this.simpleInfoCallback,
    this.thumbnailCallback,
    this.progressCallback,
  });
}

abstract class Downloadable {
  String name();
  bool loginRequire();
  Future<bool> tryLogin();
  bool logined();
  void setSession(String id, String pwd);
  bool acceptURL(String url);
  String fav();
  String defaultFormat();
  Future<List<DownloadTask>> createTask(
      String url, GeneralDownloadProgress gdp);
}

class ExtractorManager {
  static ExtractorManager instance = ExtractorManager();

  List<Downloadable> _dl;

  ExtractorManager() {
    _dl = [
      PixivManager(),
      GelbooruManager(),
      InstagramManager(),
      HitomiDonwloadManager(),
      TwitterManager(),
    ];
  }

  bool existsExtractor(String url) {
    return _dl.any((element) => element.acceptURL(url));
  }

  Downloadable getExtractor(String url) {
    return _dl.firstWhere((element) => element.acceptURL(url));
  }
}
