// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/database/query.dart';

typedef SelectCallback = void Function();
typedef BookmarkCallback = void Function(int article);
typedef BookmarkCheckCallback = void Function(int article, bool check);
typedef DoubleTapCallback = void Function();

class ArticleListItem {
  final String key;

  final bool addBottomPadding;
  final bool showDetail;
  final QueryResult queryResult;
  final double width;
  final String thumbnailTag;
  final bool bookmarkMode;
  final BookmarkCallback bookmarkCallback;
  final BookmarkCheckCallback bookmarkCheckCallback;
  final int viewed;
  final int seconds;
  final bool disableFilter;
  final List<QueryResult> usableTabList;
  final bool selectMode;
  final DoubleTapCallback doubleTapCallback;
  final SelectCallback selectCallback;
  // final bool isCheckMode;
  // bool isChecked;

  ArticleListItem({
    @required this.key,
    @required this.queryResult,
    @required this.addBottomPadding,
    @required this.showDetail,
    @required this.width,
    @required this.thumbnailTag,
    @required this.bookmarkMode,
    @required this.bookmarkCallback,
    @required this.bookmarkCheckCallback,
    @required this.viewed,
    @required this.seconds,
    @required this.disableFilter,
    @required this.doubleTapCallback,
    this.usableTabList,
    this.selectMode = false,
    this.selectCallback,
    // @required this.isChecked,
    // @required this.isCheckMode,
  });

  factory ArticleListItem.fromArticleListItem({
    String key,
    bool addBottomPadding,
    bool showDetail,
    QueryResult queryResult,
    double width,
    String thumbnailTag,
    bool bookmarkMode = false,
    BookmarkCallback bookmarkCallback,
    BookmarkCheckCallback bookmarkCheckCallback,
    int seconds,
    int viewed,
    bool disableFilter,
    List<QueryResult> usableTabList,
    bool selectMode = false,
    SelectCallback selectCallback,
    DoubleTapCallback doubleTapCallback,
    // bool isCheckMode = false,
    // bool isChecked = false,
  }) {
    return ArticleListItem(
      key: key,
      addBottomPadding: addBottomPadding,
      showDetail: showDetail,
      queryResult: queryResult,
      width: width,
      thumbnailTag: thumbnailTag,
      bookmarkMode: bookmarkMode,
      bookmarkCallback: bookmarkCallback,
      bookmarkCheckCallback: bookmarkCheckCallback,
      seconds: seconds,
      viewed: viewed,
      disableFilter: disableFilter,
      usableTabList: usableTabList,
      selectMode: selectMode,
      selectCallback: selectCallback,
      doubleTapCallback: doubleTapCallback,
      // isCheckMode: isCheckMode,
      // isChecked: isChecked,
    );
  }
}
