// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';

typedef void SelectCallback();
typedef void BookmarkCallback(int article);
typedef void BookmarkCheckCallback(int article, bool check);

class ArticleListItem {
  final bool addBottomPadding;
  final bool showDetail;
  final QueryResult queryResult;
  final double width;
  final String thumbnailTag;
  final bool bookmarkMode;
  final BookmarkCallback bookmarkCallback;
  final BookmarkCheckCallback bookmarkCheckCallback;
  final int viewed;
  final bool disableFilter;
  final List<QueryResult> usableTabList;
  final bool selectMode;
  final SelectCallback selectCallback;
  // final bool isCheckMode;
  // bool isChecked;

  ArticleListItem({
    @required this.queryResult,
    @required this.addBottomPadding,
    @required this.showDetail,
    @required this.width,
    @required this.thumbnailTag,
    @required this.bookmarkMode,
    @required this.bookmarkCallback,
    @required this.bookmarkCheckCallback,
    @required this.viewed,
    @required this.disableFilter,
    this.usableTabList,
    this.selectMode = false,
    this.selectCallback,
    // @required this.isChecked,
    // @required this.isCheckMode,
  });

  factory ArticleListItem.fromArticleListItem({
    bool addBottomPadding,
    bool showDetail,
    QueryResult queryResult,
    double width,
    String thumbnailTag,
    bool bookmarkMode = false,
    BookmarkCallback bookmarkCallback,
    BookmarkCheckCallback bookmarkCheckCallback,
    int viewed,
    bool disableFilter,
    List<QueryResult> usableTabList,
    bool selectMode = false,
    SelectCallback selectCallback,
    // bool isCheckMode = false,
    // bool isChecked = false,
  }) {
    return ArticleListItem(
      addBottomPadding: addBottomPadding,
      showDetail: showDetail,
      queryResult: queryResult,
      width: width,
      thumbnailTag: thumbnailTag,
      bookmarkMode: bookmarkMode,
      bookmarkCallback: bookmarkCallback,
      bookmarkCheckCallback: bookmarkCheckCallback,
      viewed: viewed,
      disableFilter: disableFilter,
      usableTabList: usableTabList,
      selectMode: selectMode,
      selectCallback: selectCallback,
      // isCheckMode: isCheckMode,
      // isChecked: isChecked,
    );
  }
}
