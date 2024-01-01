// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/database/query.dart';

typedef SelectCallback = void Function();
typedef BookmarkCallback = void Function(int article);
typedef BookmarkCheckCallback = void Function(int article, bool check);
typedef DoubleTapCallback = void Function();

class ArticleListItem {
  final String? key;

  final bool addBottomPadding;
  final bool showDetail;
  final bool showUltra;
  final QueryResult queryResult;
  final double width;
  final String thumbnailTag;
  final bool bookmarkMode;
  final BookmarkCallback? bookmarkCallback;
  final BookmarkCheckCallback? bookmarkCheckCallback;
  final int? viewed;
  final int? seconds;
  final bool disableFilter;
  final List<QueryResult>? usableTabList;
  final bool selectMode;
  final DoubleTapCallback? doubleTapCallback;
  final SelectCallback? selectCallback;

  ArticleListItem({
    this.key,
    required this.queryResult,
    required this.addBottomPadding,
    required this.showDetail,
    this.showUltra = false,
    required this.width,
    required this.thumbnailTag,
    required this.bookmarkMode,
    this.bookmarkCallback,
    this.bookmarkCheckCallback,
    this.viewed,
    this.seconds,
    required this.disableFilter,
    this.doubleTapCallback,
    this.usableTabList,
    this.selectMode = false,
    this.selectCallback,
  });

  factory ArticleListItem.fromArticleListItem({
    String? key,
    required bool addBottomPadding,
    required bool showDetail,
    bool? showUltra,
    required QueryResult queryResult,
    required double width,
    required String thumbnailTag,
    bool bookmarkMode = false,
    BookmarkCallback? bookmarkCallback,
    BookmarkCheckCallback? bookmarkCheckCallback,
    int? seconds,
    int? viewed,
    bool disableFilter = false,
    List<QueryResult>? usableTabList,
    bool selectMode = false,
    SelectCallback? selectCallback,
    DoubleTapCallback? doubleTapCallback,
  }) {
    return ArticleListItem(
      key: key,
      addBottomPadding: addBottomPadding,
      showDetail: showDetail,
      showUltra: showUltra ?? false,
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
    );
  }
}
