// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/search_type2.dart';
import 'package:violet/pages/bookmark/group/bookmark_search_sort.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/search_bar.dart';

class ArticleListPage extends StatefulWidget {
  final List<QueryResult> cc;
  final String name;

  ArticleListPage({this.name, this.cc});

  @override
  _ArticleListPageState createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);
    // if (similarsAll == null) return Text('asdf');
    return Padding(
      // padding: EdgeInsets.all(0),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Card(
            elevation: 5,
            color:
                Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
            child: SizedBox(
              width: width - 16,
              height: height -
                  16 -
                  (mediaQuery.padding + mediaQuery.viewInsets).bottom,
              child: Container(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: <Widget>[
                      SliverPersistentHeader(
                        floating: true,
                        delegate: AnimatedOpacitySliver(
                          minExtent: 64 + 12.0,
                          maxExtent: 64.0 + 12,
                          searchBar: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Stack(
                              children: <Widget>[
                                _align(),
                                _title(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      buildList()
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _align() {
    return Align(
      alignment: Alignment.centerRight,
      child: Hero(
        tag: "searchtype2",
        child: Card(
          color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8.0),
            ),
          ),
          elevation: 100,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: InkWell(
            child: SizedBox(
              height: 48,
              width: 48,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(
                    MdiIcons.formatListText,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            onTap: () async {
              Navigator.of(context)
                  .push(PageRouteBuilder(
                opaque: false,
                transitionDuration: Duration(milliseconds: 500),
                transitionsBuilder: (BuildContext context,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                    Widget wi) {
                  return FadeTransition(opacity: animation, child: wi);
                },
                pageBuilder: (_, __, ___) => SearchType2(
                  nowType: nowType,
                ),
              ))
                  .then((value) async {
                if (value == null) return;
                nowType = value;
                await Future.delayed(Duration(milliseconds: 50), () {
                  setState(() {});
                });
              });
            },
            onLongPress: () {
              isFilterUsed = true;
              Navigator.of(context)
                  .push(PageRouteBuilder(
                // opaque: false,
                transitionDuration: Duration(milliseconds: 500),
                transitionsBuilder: (BuildContext context,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                    Widget wi) {
                  return FadeTransition(opacity: animation, child: wi);
                },
                pageBuilder: (_, __, ___) => BookmarkSearchSort(
                  queryResult: widget.cc,
                  tagStates: tagStates,
                  groupStates: groupStates,
                  isOr: isOr,
                  isSearch: isSearch,
                ),
              ))
                  .then((value) async {
                tagStates = value[0];
                groupStates = value[1];
                isOr = value[2];
                var result = <QueryResult>[];
                widget.cc.forEach((element) {
                  var succ = !isOr;
                  tagStates.forEach((key, value) {
                    if (!value) return;
                    if (succ == isOr) return;
                    var split = key.split('|');
                    var kk = prefix2Tag(split[0]);
                    if (element.result[kk] == null && !isOr) {
                      succ = false;
                      return;
                    }
                    if (!isSingleTag(split[0])) {
                      var tt = split[1];
                      if (split[0] == 'female' || split[0] == 'male')
                        tt = split[0] + ':' + split[1];
                      if ((element.result[kk] as String)
                              .contains('|' + tt + '|') ==
                          isOr) succ = isOr;
                    } else if ((element.result[kk] as String == split[1]) ==
                        isOr) succ = isOr;
                  });
                  if (succ) result.add(element);
                });
                filterResult = result;
                await Future.delayed(Duration(milliseconds: 50), () {
                  setState(() {});
                });
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _title() {
    return Padding(
      padding: EdgeInsets.only(top: 24, left: 12),
      child: Text(widget.name,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  bool isFilterUsed = false;
  bool isOr = false;
  bool isSearch = false;
  Map<String, bool> tagStates = Map<String, bool>();
  Map<String, bool> groupStates = Map<String, bool>();

  bool scaleOnce = false;
  List<QueryResult> filterResult = List<QueryResult>();

  static String prefix2Tag(String prefix) {
    switch (prefix) {
      case 'artist':
        return 'Artists';
      case 'group':
        return 'Groups';
      case 'language':
        return 'Language';
      case 'character':
        return 'Characters';
      case 'series':
        return 'Series';
      case 'class':
        return 'Class';
      case 'type':
        return 'Type';
      case 'uploader':
        return 'Uploader';
      case 'tag':
      case 'female':
      case 'male':
        return 'Tags';
    }
    return '';
  }

  static bool isSingleTag(String prefix) {
    switch (prefix) {
      case 'language':
      case 'series':
      case 'class':
      case 'type':
      case 'uploader':
        return true;
      case 'artist':
      case 'group':
      case 'character':
      case 'tag':
      case 'female':
      case 'male':
        return false;
    }
    return null;
  }

  List<QueryResult> filter() {
    if (!isFilterUsed) return widget.cc;
    return filterResult;
  }

  int nowType = 0;

  Widget buildList() {
    var mm = nowType == 0 ? 3 : 2;
    var windowWidth = MediaQuery.of(context).size.width;
    switch (nowType) {
      case 0:
      case 1:
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: LiveSliverGrid(
            showItemInterval: Duration(milliseconds: 50),
            showItemDuration: Duration(milliseconds: 150),
            visibleFraction: 0.001,
            itemCount: filter().length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mm,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            itemBuilder: (context, index, animation) {
              return FadeTransition(
                opacity: Tween<double>(
                  begin: 0,
                  end: 1,
                ).animate(animation),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0, -0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        child: Provider<ArticleListItem>.value(
                          value: ArticleListItem.fromArticleListItem(
                            queryResult: filter()[index],
                            showDetail: false,
                            addBottomPadding: false,
                            width: (windowWidth - 4.0) / mm,
                            thumbnailTag: Uuid().v4(),
                            usableTabList: filter(),
                          ),
                          child: ArticleListItemVerySimpleWidget(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );

      case 2:
      case 3:
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: LiveSliverList(
            itemCount: filter().length,
            itemBuilder: (context, index, animation) {
              return Align(
                alignment: Alignment.center,
                child: Provider<ArticleListItem>.value(
                  value: ArticleListItem.fromArticleListItem(
                    addBottomPadding: true,
                    showDetail: nowType == 3,
                    queryResult: filter()[index],
                    width: windowWidth - 4.0,
                    thumbnailTag: Uuid().v4(),
                    usableTabList: filter(),
                  ),
                  child: ArticleListItemVerySimpleWidget(),
                ),
              );
            },
          ),
        );

      default:
        return Container(
          child: Center(
            child: Text('Error :('),
          ),
        );
    }
  }
}
