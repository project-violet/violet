// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/search_type2.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/search_bar.dart';

class ArticleListPage extends StatefulWidget {
  final List<QueryResult> cc;
  final String name;

  const ArticleListPage({super.key, required this.name, required this.cc});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  bool _shouldReload = false;
  Widget? _cachedList;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);
    final color = Palette.themeColor;

    if (_cachedList == null || _shouldReload) {
      final list = buildList();

      _shouldReload = false;
      _cachedList = list;
    }

    return Container(
      color: color,
      child: Padding(
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
              color: Palette.themeColor,
              child: SizedBox(
                width: width - 16,
                height: height -
                    16 -
                    (mediaQuery.padding + mediaQuery.viewInsets).bottom,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: <Widget>[
                      SliverPersistentHeader(
                        floating: true,
                        delegate: AnimatedOpacitySliver(
                          searchBar: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Stack(
                              children: <Widget>[
                                _align(),
                                _title(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _cachedList!
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _align() {
    return Align(
      alignment: Alignment.centerRight,
      child: Hero(
        tag: 'searchtype2',
        child: Card(
          color: Palette.themeColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8.0),
            ),
          ),
          elevation: 100,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: InkWell(
            child: const SizedBox(
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
              PlatformNavigator.navigateOption(
                context,
                SearchType2(
                  nowType: nowType,
                ),
              ).then((value) async {
                if (value == null) return;
                nowType = value;
                await Future.delayed(const Duration(milliseconds: 50), () {
                  _shouldReload = true;
                  setState(() {
                    _shouldReload = true;
                  });
                });
              });
            },
            onLongPress: () {
              isFilterUsed = true;
              PlatformNavigator.navigateFade(
                context,
                Provider<FilterController>.value(
                  value: _filterController,
                  child: FilterPage(
                    queryResult: widget.cc,
                  ),
                ),
              ).then((value) async {
                _applyFilter();
                _shouldReload = true;
                setState(() {
                  _shouldReload = true;
                  key = ObjectKey(const Uuid().v4());
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
      padding: const EdgeInsets.only(top: 24, left: 12),
      child: Text(widget.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  ObjectKey key = ObjectKey(const Uuid().v4());

  final FilterController _filterController =
      FilterController(heroKey: 'searchtype2');
  List<QueryResult> filterResult = [];

  bool isFilterUsed = false;

  void _applyFilter() {
    var result = <QueryResult>[];
    var isOr = _filterController.isOr;
    for (var element in widget.cc) {
      // key := <group>:<name>
      var succ = !_filterController.isOr;
      _filterController.tagStates.forEach((key, value) {
        if (!value) return;

        // Check match just only one
        if (succ == isOr) return;

        // Get db column name from group
        var split = key.split('|');
        var dbColumn = prefix2Tag(split[0]);

        // There is no matched db column name
        if (element.result[dbColumn] == null && !isOr) {
          succ = false;
          return;
        }

        // If Single Tag
        if (!isSingleTag(split[0])) {
          var tag = split[1];
          if (['female', 'male'].contains(split[0])) {
            tag = '${split[0]}:${split[1]}';
          }
          if ((element.result[dbColumn] as String).contains('|$tag|') == isOr) {
            succ = isOr;
          }
        }

        // If Multitag
        else if ((element.result[dbColumn] as String == split[1]) == isOr) {
          succ = isOr;
        }
      });
      if (succ) result.add(element);
    }

    filterResult = result;
    isFilterUsed = true;

    if (_filterController.isPopulationSort) {
      Population.sortByPopulation(filterResult);
    }
  }

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
      case 'series':
      default:
        return false;
    }
  }

  List<QueryResult> filter() {
    if (!isFilterUsed) return widget.cc;
    return filterResult;
  }

  int nowType = 0;

  final List<ScrollController> _scrollControllers =
      Iterable.generate(5, (i) => ScrollController()).toList();

  Widget buildList() {
    var mm = nowType == 0 ? 3 : 2;
    var windowWidth = MediaQuery.of(context).size.width;
    switch (nowType) {
      case 0:
      case 1:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: LiveSliverGrid(
            key: key,
            controller: _scrollControllers[nowType],
            showItemInterval: const Duration(milliseconds: 50),
            showItemDuration: const Duration(milliseconds: 150),
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
                    begin: const Offset(0, -0.1),
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
                            thumbnailTag: const Uuid().v4(),
                            usableTabList: filter(),
                          ),
                          child: const ArticleListItemWidget(),
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
      case 4:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: LiveSliverList(
            key: key,
            controller: _scrollControllers[nowType],
            itemCount: filter().length,
            itemBuilder: (context, index, animation) {
              return Align(
                alignment: Alignment.center,
                child: Provider<ArticleListItem>.value(
                  value: ArticleListItem.fromArticleListItem(
                    addBottomPadding: true,
                    showDetail: nowType >= 3,
                    showUltra: nowType == 4,
                    queryResult: filter()[index],
                    width: windowWidth - 4.0,
                    thumbnailTag: const Uuid().v4(),
                    usableTabList: filter(),
                  ),
                  child: const ArticleListItemWidget(),
                ),
              );
            },
          ),
        );

      default:
        return const Center(
          child: Text('Error :('),
        );
    }
  }
}
