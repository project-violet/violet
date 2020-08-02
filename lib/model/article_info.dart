// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:violet/database/query.dart';

class ArticleInfo {
  final QueryResult queryResult;
  final String thumbnail;
  final String heroKey;
  final Map<String, String> headers;
  final bool isBookmarked;
  final ScrollController controller;
  final String title;
  final String artist;

  ArticleInfo({
    @required this.queryResult,
    @required this.thumbnail,
    @required this.heroKey,
    @required this.headers,
    @required this.isBookmarked,
    @required this.controller,
    @required this.title,
    @required this.artist,
  });

  factory ArticleInfo.fromArticleInfo({
    QueryResult queryResult,
    String thumbnail,
    String heroKey,
    Map<String, String> headers,
    bool isBookmarked,
    ScrollController controller,
  }) {
    var artist = (queryResult.artists() as String)
        .split('|')
        .where((x) => x.length != 0)
        .elementAt(0);

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
    );
  }
}
