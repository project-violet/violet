// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi_parser.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/artist_info/search_type2.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks_artist_list.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/floating_button.dart';
import 'package:violet/widgets/search_bar.dart';

// https://gist.github.com/collinjackson/4fddbfa2830ea3ac033e34622f278824#file-main-dart-L24
class DotsIndicator extends AnimatedWidget {
  DotsIndicator({
    this.controller,
    this.itemCount,
    this.onPageSelected,
    this.color: Colors.white,
  }) : super(listenable: controller);

  /// The PageController that this DotsIndicator is representing.
  final PageController controller;

  /// The number of items managed by the PageController
  final int itemCount;

  /// Called when a dot is tapped
  final ValueChanged<int> onPageSelected;

  /// The color of the dots.
  ///
  /// Defaults to `Colors.white`.
  final Color color;

  // The base size of the dots
  static const double _kDotSize = 6.0;

  // The increase in the size of the selected dot
  static const double _kMaxZoom = 2.0;

  // The distance between the center of each dot
  static const double _kDotSpacing = 20.0;

  Widget _buildDot(int index) {
    double selectedness = Curves.easeOut.transform(
      max(
        0.0,
        1.0 - ((controller.page ?? controller.initialPage) - index).abs(),
      ),
    );
    double zoom = 1.0 + (_kMaxZoom - 1.0) * selectedness;
    return Container(
      width: _kDotSpacing,
      child: Center(
        child: Material(
          color: (Settings.themeWhat ? Colors.grey.shade100 : Color(0xFF353535))
              .withAlpha((max(zoom - 1, 0.5) * 255).toInt()),
          type: MaterialType.circle,
          child: Container(
            width: _kDotSize * zoom,
            height: _kDotSize * zoom,
            child: InkWell(
              onTap: () => onPageSelected(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(itemCount, _buildDot),
    );
  }
}

class LabGroupArticleListPage extends StatefulWidget {
  final List<BookmarkArticle> articles;
  final List<BookmarkArtist> artists;
  final String name;
  final int groupId;

  LabGroupArticleListPage(
      {this.articles, this.artists, this.name, this.groupId});

  @override
  _GroupArticleListPageState createState() => _GroupArticleListPageState();
}

class _GroupArticleListPageState extends State<LabGroupArticleListPage> {
  PageController _controller = PageController(
    initialPage: 0,
  );

  static const _kDuration = const Duration(milliseconds: 300);
  static const _kCurve = Curves.ease;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void refresh() {
    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
      var cc = widget.articles
          .where((e) => e.group() == widget.groupId)
          .toList()
          .reversed
          .toList();

      if (cc.length == 0) {
        queryResult = <QueryResult>[];
        filterResult = queryResult;
        _shouldRebuild = true;
        setState(() {
          _shouldRebuild = true;
          key = ObjectKey(Uuid().v4());
        });
        return;
      }

      //queryRaw += cc.map((e) => 'Id=${e.article()}').join(' OR ');
      queryRaw += 'Id IN (' + cc.map((e) => e.article()).join(',') + ')';
      QueryManager.query(queryRaw + ' AND ExistOnHitomi=1').then((value) async {
        var qr = Map<String, QueryResult>();
        value.results.forEach((element) {
          qr[element.id().toString()] = element;
        });

        var result = <QueryResult>[];
        cc.forEach((element) async {
          if (qr[element.article()] == null) {
            // TODO: Handle qurey not found
            var hh = await http.get(
                'https://ltn.hitomi.la/galleryblock/${element.article()}.html');
            var article = await HitomiParser.parseGalleryBlock(hh.body);
            var meta = {
              'Id': int.parse(element.article()),
              'Title': article['Title'],
              'Artists': article['Artists'].join('|'),
            };
            result.add(QueryResult(result: meta));
            _shouldRebuild = true;
            setState(() {
              _shouldRebuild = true;
            });
            return;
          }
          result.add(qr[element.article()]);
        });

        queryResult = result;
        _applyFilter();
        _shouldRebuild = true;
        setState(() {
          _shouldRebuild = true;
          key = ObjectKey(Uuid().v4());
        });
      });
    });
  }

  bool _shouldRebuild = false;
  Widget _cachedList;

  @override
  Widget build(BuildContext context) {
    if (_cachedList == null || _shouldRebuild) {
      final list = buildList();

      _shouldRebuild = false;
      _cachedList = list;
    }

    return CardPanel.build(
      context,
      child: Stack(
        children: [
          PageView(
            controller: _controller,
            children: [
              Scaffold(
                resizeToAvoidBottomInset: false,
                body: Padding(
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
                              child: Stack(children: <Widget>[
                                _filter(),
                                _title(),
                              ])),
                        ),
                      ),
                      _cachedList
                    ],
                  ),
                ),
              ),
              LabGroupArtistList(
                  artists: widget.artists,
                  name: widget.name,
                  groupId: widget.groupId),
            ],
          ),
          Positioned(
            bottom: 0.0,
            left: 0.0,
            right: 0.0,
            child: Container(
              color: null,
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: DotsIndicator(
                  controller: _controller,
                  itemCount: 2,
                  onPageSelected: (int page) {
                    _controller.animateToPage(
                      page,
                      duration: _kDuration,
                      curve: _kCurve,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filter() {
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
          elevation: !Settings.themeFlat ? 100 : 0,
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
                  _shouldRebuild = true;
                  setState(() {
                    _shouldRebuild = true;
                  });
                });
              });
            },
            onLongPress: () {
              isFilterUsed = true;

              PlatformNavigator.navigateSlide(
                context,
                Provider<FilterController>.value(
                  value: _filterController,
                  child: FilterPage(
                    queryResult: queryResult,
                  ),
                ),
              ).then((value) async {
                _applyFilter();
                _shouldRebuild = true;
                setState(() {
                  _shouldRebuild = true;
                  key = ObjectKey(Uuid().v4());
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

  ObjectKey key = ObjectKey(Uuid().v4());

  FilterController _filterController = FilterController(heroKey: "searchtype2");

  bool isFilterUsed = false;

  List<QueryResult> queryResult = <QueryResult>[];
  List<QueryResult> filterResult = <QueryResult>[];

  void _applyFilter() {
    var result = <QueryResult>[];
    var isOr = _filterController.isOr;
    queryResult.forEach((element) {
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
          if (['female', 'male'].contains(split[0]))
            tag = '${split[0]}:${split[1]}';
          if ((element.result[dbColumn] as String).contains('|$tag|') == isOr)
            succ = isOr;
        }

        // If Multitag
        else if ((element.result[dbColumn] as String == split[1]) == isOr)
          succ = isOr;
      });
      if (succ) result.add(element);
    });

    filterResult = result;
    isFilterUsed = true;

    if (_filterController.isPopulationSort)
      Population.sortByPopulation(filterResult);
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
        return false;
    }
    return null;
  }

  List<QueryResult> filter() {
    if (!isFilterUsed) return queryResult;
    return filterResult;
  }

  int nowType = 3;

  Widget buildList() {
    var mm = nowType == 0 ? 3 : 2;
    var windowWidth = MediaQuery.of(context).size.width;
    switch (nowType) {
      case 0:
      case 1:
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: SliverGrid(
            key: key,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mm,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildListDelegate(filterResult.map((e) {
              return Padding(
                key: Key('group' +
                    widget.groupId.toString() +
                    '/' +
                    nowType.toString() +
                    '/' +
                    e.id().toString()),
                padding: EdgeInsets.zero,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    child: Provider<ArticleListItem>.value(
                      value: ArticleListItem.fromArticleListItem(
                        queryResult: e,
                        showDetail: false,
                        addBottomPadding: false,
                        width: (windowWidth - 4.0) / mm,
                        thumbnailTag: Uuid().v4(),
                        usableTabList: filterResult,
                        // isCheckMode: checkMode,
                        // isChecked: checked.contains(e.id()),
                      ),
                      child: ArticleListItemVerySimpleWidget(),
                    ),
                  ),
                ),
              );
            }).toList()),
          ),
        );

      case 2:
      case 3:
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: SliverList(
            key: key,
            delegate: SliverChildListDelegate(filterResult.map((x) {
              return Align(
                key: Key('group' +
                    widget.groupId.toString() +
                    '/' +
                    nowType.toString() +
                    '/' +
                    x.id().toString()),
                alignment: Alignment.center,
                child: Provider<ArticleListItem>.value(
                  value: ArticleListItem.fromArticleListItem(
                    queryResult: x,
                    showDetail: nowType == 3,
                    addBottomPadding: true,
                    width: (windowWidth - 4.0),
                    thumbnailTag: Uuid().v4(),
                    usableTabList: filterResult,
                    // isCheckMode: checkMode,
                    // isChecked: checked.contains(x.id()),
                  ),
                  child: ArticleListItemVerySimpleWidget(),
                ),
              );
            }).toList()),
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
