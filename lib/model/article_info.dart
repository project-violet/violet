// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';

class ArticleInfo {
  final QueryResult queryResult;
  final String? thumbnail;
  final String heroKey;
  final Map<String, String>? headers;
  final ScrollController controller;
  final String title;
  final String artist;
  final List<QueryResult>? usableTabList;
  bool isBookmarked;
  bool lockRead;

  ArticleInfo({
    required this.queryResult,
    required this.thumbnail,
    required this.heroKey,
    required this.headers,
    required this.isBookmarked,
    required this.controller,
    required this.title,
    required this.artist,
    this.usableTabList,
    required this.lockRead,
  });

  factory ArticleInfo.fromArticleInfo({
    required QueryResult queryResult,
    required String? thumbnail,
    required String heroKey,
    required Map<String, String>? headers,
    required bool isBookmarked,
    required ScrollController controller,
    List<QueryResult>? usableTabList,
    bool lockRead = false,
  }) {
    var artist;
    try {
      artist = (queryResult.artists() as String)
          .split('|')
          .where((x) => x.isNotEmpty)
          .elementAt(0);
    } catch (e, st) {
      artist = 'N/A';
    }

    if (artist == 'N/A') {
      var group = queryResult.groups() != null
          ? queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    var title = HtmlUnescape().convert(queryResult.title());

    return ArticleInfo(
      artist: artist,
      title: title,
      thumbnail: thumbnail,
      queryResult: queryResult,
      heroKey: heroKey,
      headers: headers,
      isBookmarked: isBookmarked,
      controller: controller,
      usableTabList: usableTabList,
      lockRead: lockRead,
    );
  }

  Future<void> setIsBookmarked(bool isBookmarked) async {
    this.isBookmarked = isBookmarked;
    if (isBookmarked) {
      await (await Bookmark.getInstance()).bookmark(queryResult.id());
    } else {
      await (await Bookmark.getInstance()).unbookmark(queryResult.id());
    }
  }
}
