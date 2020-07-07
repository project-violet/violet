// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:math';
import 'dart:ui';

import 'package:auto_animated/auto_animated.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flare_flutter/flare.dart';
import 'package:flare_dart/math/mat2d.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:infinite_listview/infinite_listview.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database.dart';
import 'package:violet/locale.dart';
import 'package:violet/other/flare_artboard.dart';
import 'package:violet/settings.dart';
import 'package:violet/syncfusion/slider.dart';
import 'package:violet/widgets/article_list_item_widget.dart';

bool blurred = false;

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin<SearchPage> {
  @override
  bool get wantKeepAlive => true;

  Color color = Colors.green;
  bool into = false;

  final FlareControls heroFlareControls = FlareControls();
  FlutterActorArtboard artboard;
  ScrollController _scrollController = ScrollController();

  bool searchbarVisible = true;
  double upperPixel = 0;
  double latestOffset = 0.0;
  int eventCalled = 0;
  bool whenTopScroll = false;

  @override
  void initState() {
    super.initState();

    (() async {
      var asset =
          await cachedActor(rootBundle, 'assets/flare/search_close.flr');
      asset.ref();
      artboard = asset.actor.artboard.makeInstance() as FlutterActorArtboard;
      artboard.initializeGraphics();
      artboard.advance(0);
    })();
    Future.delayed(Duration(milliseconds: 500),
        () => heroFlareControls.play('close2search'));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => heroFlareControls.play('close2search'));
    Future.delayed(Duration(milliseconds: 500), () async {
      final query = HitomiManager.translate2query(Settings.includeTags +
          ' ' +
          Settings.excludeTags
              .where((e) => e.trim() != '')
              .map((e) => '-$e')
              .join(' '));
      final result = QueryManager.queryPagination(query);

      latestQuery = Tuple2<QueryManager, String>(result, '');
      queryResult = List<QueryResult>();
      await loadNextQuery();
    });
  }

  Tuple2<QueryManager, String> latestQuery;

  // https://stackoverflow.com/questions/60643355/is-it-possible-to-have-both-expand-and-contract-effects-with-the-slivers-in
  @override
  Widget build(BuildContext context) {
    final InfiniteScrollController _infiniteController =
        InfiniteScrollController(
      initialScrollOffset: 0.0,
    );
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    double width = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.only(top: statusBarHeight),
      child: GestureDetector(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPersistentHeader(
              // pinned: true,
              floating: true,
              delegate: SearchBar(
                minExtent: 64 + 12.0,
                maxExtent: 64.0 + 12,
                searchBar: Stack(
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.fromLTRB(8, 8, 72, 0),
                      child: SizedBox(
                          height: 64,
                          child: Hero(
                            tag: "searchbar",
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8.0),
                                ),
                              ),
                              elevation: 100,
                              clipBehavior: Clip.antiAliasWithSaveLayer,
                              child: Stack(
                                children: <Widget>[
                                  Column(
                                    children: <Widget>[
                                      Material(
                                        color: Settings.themeWhat
                                            ? Colors.grey.shade900
                                                .withOpacity(0.4)
                                            : Colors.grey.shade200
                                                .withOpacity(0.4),
                                        child: ListTile(
                                          title: TextFormField(
                                            cursorColor: Colors.black,
                                            decoration: new InputDecoration(
                                                border: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                errorBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                contentPadding: EdgeInsets.only(
                                                    left: 15,
                                                    bottom: 11,
                                                    top: 11,
                                                    right: 15),
                                                hintText: latestQuery != null &&
                                                        latestQuery.item2
                                                                .trim() !=
                                                            ''
                                                    ? latestQuery.item2
                                                    : Translations.of(context)
                                                        .trans('search')),
                                          ),
                                          leading: SizedBox(
                                            width: 25,
                                            height: 25,
                                            child: FlareArtboard(artboard,
                                                controller: heroFlareControls),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  Positioned(
                                    left: 0.0,
                                    top: 0.0,
                                    bottom: 0.0,
                                    right: 0.0,
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: InkWell(
                                        onTap: () async {
                                          await Future.delayed(
                                              Duration(milliseconds: 200));
                                          heroFlareControls
                                              .play('search2close');
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) {
                                                return new SearchBarPage(
                                                  artboard: artboard,
                                                  heroController:
                                                      heroFlareControls,
                                                );
                                              },
                                              fullscreenDialog: true,
                                            ),
                                          ).then((value) async {
                                            setState(() {
                                              heroFlareControls
                                                  .play('close2search');
                                            });
                                            if (value == null) return;
                                            latestQuery = value;
                                            queryResult = List<QueryResult>();
                                            isFilterUsed = false;
                                            isOr = false;
                                            tagStates = Map<String, bool>();
                                            groupStates = Map<String, bool>();
                                            await loadNextQuery();
                                          });
                                          // print(latestQuery);
                                        },
                                        onLongPress: () async {
                                          Navigator.of(context)
                                              .push(PageRouteBuilder(
                                            opaque: false,
                                            transitionDuration:
                                                Duration(milliseconds: 500),
                                            transitionsBuilder:
                                                (BuildContext context,
                                                    Animation<double> animation,
                                                    Animation<double>
                                                        secondaryAnimation,
                                                    Widget wi) {
                                              return new FadeTransition(
                                                  opacity: animation,
                                                  child: wi);
                                            },
                                            pageBuilder: (_, __, ___) =>
                                                SearchResultSelector(),
                                          ))
                                              .then((value) async {
                                            await Future.delayed(
                                                Duration(milliseconds: 50), () {
                                              setState(() {});
                                            });
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(width - 8 - 64, 8, 8, 0),
                      child: SizedBox(
                        height: 64,
                        child: Hero(
                          tag: "searchtype",
                          child: Card(
                            color: Settings.themeWhat
                                ? Color(0xFF353535)
                                : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.0),
                              ),
                            ),
                            elevation: 100,
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            child: InkWell(
                              child: SizedBox(
                                height: 64,
                                width: 64,
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
                                  transitionDuration:
                                      Duration(milliseconds: 500),
                                  transitionsBuilder: (BuildContext context,
                                      Animation<double> animation,
                                      Animation<double> secondaryAnimation,
                                      Widget wi) {
                                    return new FadeTransition(
                                        opacity: animation, child: wi);
                                  },
                                  pageBuilder: (_, __, ___) => SearchType(),
                                ))
                                    .then((value) async {
                                  await Future.delayed(
                                      Duration(milliseconds: 50), () {
                                    setState(() {});
                                  });
                                });
                              },
                              onLongPress: () async {
                                Navigator.of(context)
                                    .push(PageRouteBuilder(
                                  // opaque: false,
                                  transitionDuration:
                                      Duration(milliseconds: 500),
                                  transitionsBuilder: (BuildContext context,
                                      Animation<double> animation,
                                      Animation<double> secondaryAnimation,
                                      Widget wi) {
                                    return new FadeTransition(
                                        opacity: animation, child: wi);
                                  },
                                  pageBuilder: (_, __, ___) => SearchSort(
                                    ignoreBookmark: ignoreBookmark,
                                    blurred: blurred,
                                    queryResult: queryResult,
                                    tagStates: tagStates,
                                    groupStates: groupStates,
                                    isOr: isOr,
                                  ),
                                ))
                                    .then((value) async {
                                  isFilterUsed = true;
                                  ignoreBookmark = value[0];
                                  blurred = value[1];
                                  tagStates = value[2];
                                  groupStates = value[3];
                                  isOr = value[4];
                                  var result = List<QueryResult>();
                                  queryResult.forEach((element) {
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
                                        if (split[0] == 'female' ||
                                            split[0] == 'male')
                                          tt = split[0] + ':' + split[1];
                                        if ((element.result[kk] as String)
                                                .contains('|' + tt + '|') ==
                                            isOr) succ = isOr;
                                      } else if ((element.result[kk]
                                                  as String ==
                                              split[1]) ==
                                          isOr) succ = isOr;
                                    });
                                    if (succ) result.add(element);
                                  });
                                  filterResult = result;
                                  setState(() {
                                    key = ObjectKey(Uuid().v4());
                                  });
                                  // await Future.delayed(
                                  //     Duration(milliseconds: 50), () {
                                  //   setState(() {});
                                  // });
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            makeResult(),
          ],
        ),
      ),
    );
  }

  bool isFilterUsed = false;
  bool ignoreBookmark = false;
  bool isOr = false;
  Map<String, bool> tagStates = Map<String, bool>();
  Map<String, bool> groupStates = Map<String, bool>();

  bool scaleOnce = false;
  List<QueryResult> queryResult = List<QueryResult>();
  List<QueryResult> filterResult = List<QueryResult>();

  ObjectKey key = ObjectKey(Uuid().v4());

  Future<void> loadNextQuery() async {
    var nn = await latestQuery.item1.next();
    if (nn.length == 0) return;
    setState(() {
      queryResult.addAll(nn);
    });
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
    if (!isFilterUsed) return queryResult;
    return filterResult;
  }

  Widget makeResult() {
    var mm = Settings.searchResultType == 0 ? 3 : 2;
    var windowWidth = MediaQuery.of(context).size.width;
    var filtered = filter();
    switch (Settings.searchResultType) {
      case 0:
      case 1:
        return SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: LiveSliverGrid(
              key: key,
              controller: _scrollController,
              showItemInterval: Duration(milliseconds: 50),
              showItemDuration: Duration(milliseconds: 150),
              visibleFraction: 0.001,
              itemCount: filtered.length,
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
                          child: ArticleListItemVerySimpleWidget(
                            queryResult: filtered[index],
                            showDetail: false,
                            addBottomPadding: false,
                            width: (windowWidth - 4.0) / mm,
                            thumbnailTag:
                                'thumbnail' + filtered[index].id().toString(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ));

      // return SliverPadding(
      //     padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      //     sliver: SliverGrid(
      //       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      //         crossAxisCount: mm,
      //         crossAxisSpacing: 8,
      //         mainAxisSpacing: 8,
      //         childAspectRatio: 3 / 4,
      //       ),
      //       delegate: SliverChildBuilderDelegate(
      //         (BuildContext context, int index) {
      //           return Padding(
      //             padding: EdgeInsets.zero,
      //             child: Align(
      //               alignment: Alignment.bottomCenter,
      //               child: SizedBox(
      //                 child: ArticleListItemVerySimpleWidget(
      //                   queryResult: queryResult[index],
      //                   showDetail: false,
      //                   addBottomPadding: false,
      //                   width: (windowWidth - 4.0) / mm,
      //                   thumbnailTag:
      //                       'thumbnail' + queryResult[index].id().toString(),
      //                 ),
      //               ),
      //             ),
      //           );
      //         },
      //         childCount: queryResult.length,
      //       ),
      //     ));

      case 2:
      case 3:
        return SliverList(
          key: key,
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return Align(
                alignment: Alignment.center,
                child: ArticleListItemVerySimpleWidget(
                  addBottomPadding: true,
                  showDetail: Settings.searchResultType == 3,
                  queryResult: filtered[index],
                  width: windowWidth - 4.0,
                  thumbnailTag: 'thumbnail' + filtered[index].id().toString(),
                ),
              );
            },
            childCount: filtered.length,
          ),
          // itemCount: queryResult.length,
          // itemBuilder: (context, index, animation) {
          //   return Align(
          //     alignment: Alignment.center,
          //     child: ArticleListItemVerySimpleWidget(
          //       addBottomPadding: true,
          //       showDetail: Settings.searchResultType == 3,
          //       queryResult: queryResult[index],
          //       width: windowWidth - 4.0,
          //       thumbnailTag: 'thumbnail' + queryResult[index].id().toString(),
          //     ),
          //   );
          // },
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

class SearchBar implements SliverPersistentHeaderDelegate {
  SearchBar({this.minExtent, @required this.maxExtent, this.searchBar});
  final double minExtent;
  final double maxExtent;

  Widget searchBar;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          child: searchBar,
          opacity: 1.0 - max(0.0, shrinkOffset - 20) / (maxExtent - 20),
          duration: Duration(milliseconds: 100),
        )
      ],
    );
  }

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }

  @override
  FloatingHeaderSnapConfiguration get snapConfiguration => null;

  @override
  OverScrollHeaderStretchConfiguration get stretchConfiguration => null;
}

class SearchBarPage extends StatefulWidget {
  final FlareControls heroController;
  final FlutterActorArtboard artboard;
  const SearchBarPage({Key key, this.artboard, this.heroController})
      : super(key: key);

  @override
  _SearchBarPageState createState() => _SearchBarPageState();
}

class _SearchBarPageState extends State<SearchBarPage>
    with SingleTickerProviderStateMixin {
  AnimationController controller;
  List<Tuple3<String, String, int>> _searchLists =
      List<Tuple3<String, String, int>>();

  TextEditingController _searchController = TextEditingController();
  int _insertPos, _insertLength;
  String _searchText;
  bool _nothing = false;
  bool _onChip = false;
  bool _tagTranslation = false;
  bool _showCount = true;
  int _searchResultMaximum = 60;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
      reverseDuration: Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    controller.forward();

    if (_searchLists.length == 0 && !_nothing) {
      _searchLists.add(Tuple3<String, String, int>('prefix', 'female', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'male', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'tag', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'lang', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'series', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'artist', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'group', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'uploader', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'character', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'type', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'class', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'recent', 0));
    }

    return Container(
        color: Settings.themeWhat ? Colors.grey.shade900 : Colors.white,
        padding: EdgeInsets.fromLTRB(2, statusBarHeight + 2, 0, 0),
        child: Stack(children: <Widget>[
          Hero(
            tag: "searchbar",
            child: Card(
              elevation: 100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              child: Material(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Material(
                        child: ListTile(
                          title: TextFormField(
                            cursorColor: Colors.black,
                            onChanged: (String str) async {
                              await searchProcess(
                                  str, _searchController.selection);
                            },
                            controller: _searchController,
                            decoration: new InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              suffixIcon: IconButton(
                                onPressed: () async {
                                  _searchController.clear();
                                  _searchController.selection = TextSelection(
                                      baseOffset: 0, extentOffset: 0);
                                  await searchProcess(
                                      '', _searchController.selection);
                                },
                                icon: Icon(Icons.clear),
                              ),
                              contentPadding: EdgeInsets.only(
                                  left: 15, bottom: 11, top: 11, right: 15),
                              hintText:
                                  Translations.of(context).trans('search'),
                            ),
                          ),
                          // leading: SizedBox(
                          //   width: 25,
                          //   height: 25,
                          //   child: RawMaterialButton(
                          //       onPressed: () {
                          //         Navigator.pop(context);
                          //       },
                          //       shape: CircleBorder(),
                          //         child: FlareArtboard(widget.artboard,
                          //             controller: widget.heroController),
                          // ),
                          leading: Container(
                            transform: Matrix4.translationValues(-4, 0, 0),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: RawMaterialButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  shape: CircleBorder(),
                                  child: Transform.scale(
                                    scale: 0.65,
                                    child: FlareArtboard(widget.artboard,
                                        controller: widget.heroController),
                                  )),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          color: Colors.black12,
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(8, 2, 8, 2),
                          child: ButtonTheme(
                            minWidth: double.infinity,
                            height: 30,
                            child: RaisedButton(
                              color: Settings.majorColor,
                              textColor: Colors.white,
                              child: Text(
                                  Translations.of(context).trans('search')),
                              onPressed: () async {
                                final query = HitomiManager.translate2query(
                                    _searchController.text +
                                        ' ' +
                                        Settings.includeTags +
                                        ' ' +
                                        Settings.excludeTags
                                            .where((e) => e.trim() != '')
                                            .map((e) => '-$e')
                                            .join(' ')
                                            .trim());
                                final result =
                                    QueryManager.queryPagination(query);
                                Navigator.pop(
                                    context,
                                    Tuple2<QueryManager, String>(
                                        result, _searchController.text));
                              },
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          color: Colors.black12,
                        ),
                      ),
                      Expanded(
                        child: _searchLists.length == 0 || _nothing
                            ? Center(
                                child: Text(_nothing
                                    ? Translations.of(context)
                                        .trans('nosearchresult')
                                    : Translations.of(context)
                                        .trans('inputsearchtoken')))
                            : Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: FadingEdgeScrollView
                                    .fromSingleChildScrollView(
                                  child: SingleChildScrollView(
                                    controller: ScrollController(),
                                    child: Wrap(
                                      spacing: 4.0,
                                      runSpacing: -10.0,
                                      children: _searchLists
                                          .map((item) => chip(item))
                                          .toList(),
                                    ),
                                  ),
                                  gradientFractionOnEnd: 0.1,
                                  gradientFractionOnStart: 0.1,
                                ),
                              ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          color: Colors.black12,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
                          child: LayoutBuilder(builder: (BuildContext context,
                              BoxConstraints constraints) {
                            return SingleChildScrollView(
                              controller: ScrollController(),
                              child: ConstrainedBox(
                                constraints: constraints.copyWith(
                                  minHeight: constraints.maxHeight,
                                  maxHeight: double.infinity,
                                ),
                                child: IntrinsicHeight(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      ListTile(
                                        leading: Icon(Icons.translate,
                                            color: Settings.majorColor),
                                        title: Text(Translations.of(context)
                                            .trans('tagtranslation')),
                                        trailing: Switch(
                                          value: _tagTranslation,
                                          onChanged: (value) {
                                            setState(() {
                                              _tagTranslation = value;
                                            });
                                          },
                                          activeTrackColor: Settings.majorColor,
                                          activeColor:
                                              Settings.majorAccentColor,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        height: 1.0,
                                        color: Colors.grey.shade400,
                                      ),
                                      ListTile(
                                        leading: Icon(MdiIcons.counter,
                                            color: Settings.majorColor),
                                        title: Text(Translations.of(context)
                                            .trans('showcount')),
                                        trailing: Switch(
                                          value: _showCount,
                                          onChanged: (value) {
                                            setState(() {
                                              _showCount = value;
                                            });
                                          },
                                          activeTrackColor: Settings.majorColor,
                                          activeColor:
                                              Settings.majorAccentColor,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        height: 1.0,
                                        color: Colors.grey.shade400,
                                      ),
                                      ListTile(
                                        leading: Icon(MdiIcons.chartBubble,
                                            color: Settings.majorColor),
                                        title: Text(Translations.of(context)
                                            .trans('fuzzysearch')),
                                        trailing: Switch(
                                          value: useFuzzy,
                                          onChanged: (value) {
                                            setState(() {
                                              useFuzzy = value;
                                            });
                                          },
                                          activeTrackColor: Settings.majorColor,
                                          activeColor:
                                              Settings.majorAccentColor,
                                        ),
                                      ),
                                      // Container(
                                      //   margin: const EdgeInsets.symmetric(
                                      //     horizontal: 8.0,
                                      //   ),
                                      //   width: double.infinity,
                                      //   height: 1.0,
                                      //   color: Colors.grey.shade400,
                                      // ),
                                      // ListTile(
                                      //   leading: Icon(
                                      //       MdiIcons.viewGridPlusOutline,
                                      //       color: Settings.majorColor),
                                      //   title: Slider(
                                      //     activeColor: Settings.majorColor,
                                      //     inactiveColor: Settings.majorColor
                                      //         .withOpacity(0.2),
                                      //     min: 60.0,
                                      //     max: 2000.0,
                                      //     divisions: (2000 - 60) ~/ 30,
                                      //     label:
                                      //         '$_searchResultMaximum${Translations.of(context).trans('tagdisplay')}',
                                      //     onChanged: (double value) {
                                      //       setState(() {
                                      //         _searchResultMaximum =
                                      //             value.toInt();
                                      //       });
                                      //     },
                                      //     value:
                                      //         _searchResultMaximum.toDouble(),
                                      //   ),
                                      // ),

                                      // GradientRangeSlider(),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                              vertical: 8,
                                            ),
                                            width: double.infinity,
                                            height: 60,
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: <Widget>[
                                                Expanded(
                                                  child: RaisedButton(
                                                    color: Settings.themeWhat
                                                        ? Colors.grey.shade800
                                                        : Colors.grey,
                                                    child: Icon(MdiIcons
                                                        .keyboardBackspace),
                                                    onPressed: () {
                                                      deleteProcess();
                                                    },
                                                  ),
                                                ),
                                                Container(
                                                  width: 8,
                                                ),
                                                Expanded(
                                                  child: RaisedButton(
                                                    color: Settings.themeWhat
                                                        ? Colors.grey.shade800
                                                        : Colors.grey,
                                                    child: Icon(
                                                        MdiIcons.keyboardSpace),
                                                    onPressed: () {
                                                      spaceProcess();
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]));
  }

  Future<void> searchProcess(String target, TextSelection selection) async {
    _nothing = false;
    _onChip = false;
    if (target.trim() == '') {
      latestToken = '';
      setState(() {
        _searchLists.clear();
      });
      return;
    }

    int pos = selection.base.offset - 1;
    for (; pos > 0; pos--)
      if (target[pos] == ' ') {
        pos++;
        break;
      }

    var last = target.indexOf(' ', pos);
    var token =
        target.substring(pos, last == -1 ? target.length : last + 1).trim();

    if (pos != target.length && (target[pos] == '-' || target[pos] == '(')) {
      token = token.substring(1);
      pos++;
    }
    if (token == '') {
      setState(() {
        _searchLists.clear();
      });
      return;
    }

    _insertPos = pos;
    _insertLength = token.length;
    _searchText = target;
    latestToken = token;
    if (!useFuzzy) {
      final result = (await HitomiManager.queryAutoComplete(token))
          .take(_searchResultMaximum)
          .toList();
      if (result.length == 0) _nothing = true;
      setState(() {
        _searchLists = result;
      });
    } else {
      final result = (await HitomiManager.queryAutoCompleteFuzzy(token))
          .take(_searchResultMaximum)
          .toList();
      if (result.length == 0) _nothing = true;
      setState(() {
        _searchLists = result;
      });
    }
  }

  String latestToken = '';
  bool useFuzzy = false;

  Future<void> deleteProcess() async {
    var text = _searchController.text;
    var selection = _searchController.selection;

    if (text == null || text.trim() == '') return;

    // Delete one token
    int fpos = selection.base.offset - 1;
    for (; fpos < text.length; fpos++)
      if (text[fpos] == ' ') {
        break;
      }

    int pos = fpos - 1;
    for (; pos > 0; pos--)
      if (text[pos] == ' ') {
        pos++;
        break;
      }

    text = text.substring(0, pos) + text.substring(fpos);
    _searchController.text = text;
    _searchController.selection = TextSelection(
      baseOffset: pos,
      extentOffset: pos,
    );
    await searchProcess(_searchController.text, _searchController.selection);
  }

  Future<void> spaceProcess() async {
    var text = _searchController.text;
    var selection = _searchController.selection;

    _searchController.text = text.substring(0, selection.base.offset) +
        ' ' +
        text.substring(selection.base.offset + 1);
    _searchController.selection = TextSelection(
      baseOffset: selection.baseOffset + 1,
      extentOffset: selection.baseOffset + 1,
    );
    await searchProcess(_searchController.text, _searchController.selection);
  }

  // Create tag-chip
  // group, name, counts
  Widget chip(Tuple3<String, String, int> info) {
    var tagRaw = info.item2;
    var count = '';
    var color = Colors.grey;

    if (_tagTranslation) // Korean
      tagRaw =
          HitomiManager.mapSeries2Kor(HitomiManager.mapTag2Kor(info.item2));

    if (info.item3 > 0 && _showCount) count = ' (${info.item3})';

    if (info.item1 == 'female')
      color = Colors.pink;
    else if (info.item1 == 'male')
      color = Colors.blue;
    else if (info.item1 == 'prefix') color = Colors.orange;

    var ts = List<TextSpan>();
    var accColor = Colors.pink;

    if (color == Colors.pink) accColor = Colors.orange;

    if (!useFuzzy && latestToken != '' && tagRaw.contains(latestToken)) {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken)[0]));
      ts.add(TextSpan(
          style: new TextStyle(
            color: accColor,
            fontWeight: FontWeight.bold,
          ),
          text: latestToken));
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken)[1]));
    } else if (!useFuzzy &&
        latestToken.contains(':') &&
        latestToken.split(':')[1] != '' &&
        tagRaw.contains(latestToken.split(':')[1])) {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken.split(':')[1])[0]));
      ts.add(TextSpan(
          style: new TextStyle(
            color: accColor,
            fontWeight: FontWeight.bold,
          ),
          text: latestToken.split(':')[1]));
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken.split(':')[1])[1]));
    } else if (!useFuzzy) {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw));
    } else if (latestToken != '') {
      var route = Distance.levenshteinDistanceRoute(
          tagRaw.runes.toList(), latestToken.runes.toList());
      for (int i = 0; i < tagRaw.length; i++) {
        ts.add(TextSpan(
            style: new TextStyle(
              color: route[i + 1] == 1 ? accColor : Colors.white,
              fontWeight:
                  route[i + 1] == 1 ? FontWeight.bold : FontWeight.normal,
            ),
            text: tagRaw[i]));
      }
    } else {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw));
    }

    var fc = RawChip(
      labelPadding: EdgeInsets.all(0.0),
      avatar: CircleAvatar(
        backgroundColor: Colors.grey.shade600,
        child: Text(info.item1[0].toUpperCase()),
      ),
      label: RichText(
          text: new TextSpan(
              style: new TextStyle(
                color: Colors.white,
              ),
              children: [
            new TextSpan(text: ' '),
            new TextSpan(children: ts),
            new TextSpan(text: count),
          ])),
      backgroundColor: color,
      elevation: 6.0,
      shadowColor: Colors.grey[60],
      padding: EdgeInsets.all(6.0),
      onPressed: () async {
        // Insert text to cursor.
        if (info.item1 != 'prefix') {
          var insert = info.item2.replaceAll(' ', '_');
          if (info.item1 != 'female' && info.item1 != 'male')
            insert = info.item1 + ':' + insert;

          _searchController.text = _searchText.substring(0, _insertPos) +
              insert +
              _searchText.substring(
                  _insertPos + _insertLength, _searchText.length);
          _searchController.selection = TextSelection(
            baseOffset: _insertPos + insert.length,
            extentOffset: _insertPos + insert.length,
          );
        } else {
          var offset = _searchController.selection.baseOffset;
          if (offset != -1) {
            _searchController.text = _searchController.text
                    .substring(0, _searchController.selection.base.offset) +
                info.item2 +
                ': ' +
                _searchController.text
                    .substring(_searchController.selection.base.offset);
            _searchController.selection = TextSelection(
              baseOffset: offset + info.item2.length + 1,
              extentOffset: offset + info.item2.length + 1,
            );
          } else {
            _searchController.text = info.item2 + ': ';
            _searchController.selection = TextSelection(
              baseOffset: info.item2.length + 1,
              extentOffset: info.item2.length + 1,
            );
          }
          _onChip = true;
          await searchProcess(
              _searchController.text, _searchController.selection);
        }
      },
    );
    return fc;
  }
}

class SearchType extends StatelessWidget {
  Color getColor(int i) {
    return Settings.themeWhat
        ? Settings.searchResultType == i
            ? Colors.grey.shade200
            : Colors.grey.shade400
        : Settings.searchResultType == i
            ? Colors.grey.shade900
            : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Hero(
            tag: "searchtype",
            child: Card(
              color:
                  Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: 240,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        ListTile(
                          leading: Icon(Icons.grid_on, color: getColor(0)),
                          title: Text(Translations.of(context).trans('srt0'),
                              style: TextStyle(color: getColor(0))),
                          onTap: () async {
                            Settings.setSearchResultType(0);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.gridLarge, color: getColor(1)),
                          title: Text(Translations.of(context).trans('srt1'),
                              style: TextStyle(color: getColor(1))),
                          onTap: () async {
                            Settings.setSearchResultType(1);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.viewAgendaOutline,
                              color: getColor(2)),
                          title: Text(
                            Translations.of(context).trans('srt2'),
                            style: TextStyle(color: getColor(2)),
                          ),
                          onTap: () async {
                            Settings.setSearchResultType(2);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading:
                              Icon(MdiIcons.formatListText, color: getColor(3)),
                          title: Text(
                            Translations.of(context).trans('srt3'),
                            style: TextStyle(color: getColor(3)),
                          ),
                          onTap: () async {
                            Settings.setSearchResultType(3);
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                          child: Container(),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(1)),
        boxShadow: [
          BoxShadow(
            color: Settings.themeWhat
                ? Colors.black.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
    );
  }
}

class SearchResultSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return Container(
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Hero(
              tag: "searchbar",
              child: Card(
                color: Settings.themeWhat
                    ? Color(0xFF353535)
                    : Colors.grey.shade100,
                child: SizedBox(
                  child: SizedBox(
                    width: width - 32,
                    height: height - 32,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Container(),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(1)),
        boxShadow: [
          BoxShadow(
            color: Settings.themeWhat
                ? Colors.black.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
    );
  }
}

class SearchSort extends StatefulWidget {
  bool ignoreBookmark;
  bool blurred;
  bool isOr;
  List<Tuple3<String, String, int>> tags = List<Tuple3<String, String, int>>();
  Map<String, bool> tagStates = Map<String, bool>();
  Map<String, bool> groupStates = Map<String, bool>();
  Map<String, int> groupCount = Map<String, int>();
  List<Tuple2<String, int>> groups = List<Tuple2<String, int>>();
  final List<QueryResult> queryResult;

  SearchSort({
    this.ignoreBookmark,
    this.blurred,
    this.queryResult,
    this.tagStates,
    this.groupStates,
    this.isOr,
  });

  @override
  _SearchSortState createState() => _SearchSortState();
}

class _SearchSortState extends State<SearchSort> {
  bool test = false;

  @override
  void initState() {
    super.initState();
    // Future.delayed(Duration(milliseconds: 50)).then((value) {
    Map<String, int> tags = Map<String, int>();
    widget.queryResult.forEach((element) {
      if (element.tags() != null) {
        element.tags().split('|').forEach((element) {
          if (element == '') return;
          if (!tags.containsKey(element)) tags[element] = 0;
          tags[element] += 1;
        });
      }
    });
    widget.groupCount['tag'] = 0;
    widget.groupCount['female'] = 0;
    widget.groupCount['male'] = 0;
    tags.forEach((key, value) {
      var group = 'tag';
      var name = key;
      if (key.startsWith('female:')) {
        group = 'female';
        widget.groupCount['female'] += 1;
        name = key.split(':')[1];
      } else if (key.startsWith('male:')) {
        group = 'male';
        widget.groupCount['male'] += 1;
        name = key.split(':')[1];
      } else
        widget.groupCount['tag'] += 1;
      widget.tags.add(Tuple3<String, String, int>(group, name, value));
      if (!widget.tagStates.containsKey(group + '|' + name))
        widget.tagStates[group + '|' + name] = false;
    });
    if (!widget.groupStates.containsKey('tag'))
      widget.groupStates['tag'] = false;
    if (!widget.groupStates.containsKey('female'))
      widget.groupStates['female'] = false;
    if (!widget.groupStates.containsKey('male'))
      widget.groupStates['male'] = false;
    append('language', 'Language');
    append('character', 'Characters');
    append('series', 'Series');
    append('artist', 'Artists');
    append('group', 'Groups');
    append('class', 'Class');
    append('type', 'Type');
    append('uploader', 'Uploader');
    widget.groupCount.forEach((key, value) {
      widget.groups.add(Tuple2<String, int>(key, value));
    });
    widget.groups.sort((a, b) => b.item2.compareTo(a.item2));
    widget.tags.sort((a, b) => b.item3.compareTo(a.item3));
    // setState(() {});
    // });
  }

  void append(String group, String vv) {
    if (!widget.groupStates.containsKey(group))
      widget.groupStates[group] = false;
    widget.groupCount[group] = 0;
    Map<String, int> tags = Map<String, int>();
    widget.queryResult.forEach((element) {
      if (element.result[vv] != null) {
        element.result[vv].split('|').forEach((element) {
          if (element == '') return;
          if (!tags.containsKey(element)) tags[element] = 0;
          tags[element] += 1;
        });
      }
    });
    widget.groupCount[group] += tags.length;
    tags.forEach((key, value) {
      widget.tags.add(Tuple3<String, String, int>(group, key, value));
      if (!widget.tagStates.containsKey(group + '|' + key))
        widget.tagStates[group + '|' + key] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, [
          widget.ignoreBookmark,
          widget.blurred,
          widget.tagStates,
          widget.groupStates,
          widget.isOr,
        ]);
        return new Future(() => false);
      },
      child: Container(
        color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Hero(
              tag: "searchtype",
              child: Card(
                color: Settings.themeWhat
                    ? Color(0xFF353535)
                    : Colors.grey.shade100,
                child: SizedBox(
                  child: SizedBox(
                    width: width - 16,
                    height: height - 16,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Column(
                        // mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: SingleChildScrollView(
                              child: Wrap(
                                  // alignment: WrapAlignment.center,
                                  spacing: -7.0,
                                  runSpacing: -13.0,
                                  children: widget.tags
                                      .where((element) =>
                                          widget.groupStates[element.item1])
                                      .take(100)
                                      .map((element) {
                                    return _Chip(
                                      selected: widget.tagStates[
                                          element.item1 + '|' + element.item2],
                                      group: element.item1,
                                      name: element.item2,
                                      count: element.item3,
                                      callback: (selected) {
                                        widget.tagStates[element.item1 +
                                            '|' +
                                            element.item2] = selected;
                                      },
                                    );
                                  }).toList()
                                  // <Widget>[
                                  //   RawChip(
                                  //     selected: test,
                                  //     labelPadding: EdgeInsets.all(0.0),
                                  //     avatar: CircleAvatar(
                                  //       backgroundColor: Colors.grey.shade600,
                                  //       child: Text('A'),
                                  //     ),
                                  //     label: Text(' ASDF'),
                                  //     backgroundColor: Colors.orange,
                                  //     elevation: 6.0,
                                  //     shadowColor: Colors.grey[60],
                                  //     padding: EdgeInsets.all(6.0),
                                  //     onSelected: (value) {
                                  //       setState(() {
                                  //         test = value;
                                  //       });
                                  //     },
                                  //   )
                                  // ],
                                  ),
                            ),
                          ),
                          Wrap(
                              alignment: WrapAlignment.center,
                              spacing: -7.0,
                              runSpacing: -13.0,
                              children: widget.groups
                                  .map((element) => _Chip(
                                        count: element.item2,
                                        group: element.item1,
                                        name: element.item1,
                                        selected:
                                            widget.groupStates[element.item1],
                                        callback: (value) {
                                          widget.groupStates[element.item1] =
                                              value;
                                          setState(() {});
                                        },
                                      ))
                                  .toList()),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4.0,
                            runSpacing: -10.0,
                            children: <Widget>[
                              FilterChip(
                                label: Text(Translations.of(context)
                                    .trans('selectall')),
                                // selected: widget.ignoreBookmark,
                                onSelected: (bool value) {
                                  widget.tags
                                      .where((element) =>
                                          widget.groupStates[element.item1])
                                      .forEach((element) {
                                    widget.tagStates[element.item1 +
                                        '|' +
                                        element.item2] = true;
                                  });
                                  setState(() {});
                                },
                              ),
                              FilterChip(
                                label: Text(Translations.of(context)
                                    .trans('deselectall')),
                                // selected: widget.blurred,
                                onSelected: (bool value) {
                                  widget.tags
                                      .where((element) =>
                                          widget.groupStates[element.item1])
                                      .forEach((element) {
                                    widget.tagStates[element.item1 +
                                        '|' +
                                        element.item2] = false;
                                  });
                                  setState(() {});
                                },
                              ),
                              FilterChip(
                                label: Text(
                                    Translations.of(context).trans('inverse')),
                                // selected: widget.blurred,
                                onSelected: (bool value) {
                                  widget.tags
                                      .where((element) =>
                                          widget.groupStates[element.item1])
                                      .forEach((element) {
                                    widget.tagStates[
                                        element.item1 +
                                            '|' +
                                            element.item2] = !widget.tagStates[
                                        element.item1 + '|' + element.item2];
                                  });
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4.0,
                            runSpacing: -10.0,
                            children: <Widget>[
                              FilterChip(
                                label: Text("OR"),
                                selected: widget.isOr,
                                onSelected: (bool value) {
                                  setState(() {
                                    widget.isOr = value;
                                  });
                                },
                              ),
                              // TODO: 북마크 블러 체크 필터
                              // FilterChip(
                              //   label: Text("북마크 제외"),
                              //   selected: widget.ignoreBookmark,
                              //   onSelected: (bool value) {
                              //     setState(() {
                              //       widget.ignoreBookmark =
                              //           !widget.ignoreBookmark;
                              //     });
                              //   },
                              // ),
                              // FilterChip(
                              //   label: Text("블러 처리"),
                              //   selected: widget.blurred,
                              //   onSelected: (bool value) {
                              //     setState(() {
                              //       widget.blurred = !widget.blurred;
                              //     });
                              //   },
                              // ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // decoration: BoxDecoration(
        //   borderRadius: BorderRadius.all(Radius.circular(1)),
        //   boxShadow: [
        //     BoxShadow(
        //       color: Settings.themeWhat
        //           ? Colors.black.withOpacity(0.4)
        //           : Colors.grey.withOpacity(0.2),
        //       spreadRadius: 1,
        //       blurRadius: 1,
        //       offset: Offset(0, 3), // changes position of shadow
        //     ),
        //   ],
        // ),
      ),
    );
  }
}

typedef ChipCallback = void Function(bool);

class _Chip extends StatefulWidget {
  bool selected;
  final String group;
  final String name;
  final int count;
  final ChipCallback callback;

  _Chip({this.selected, this.group, this.name, this.count, this.callback});

  @override
  __ChipState createState() => __ChipState();
}

class __ChipState extends State<_Chip> {
  @override
  Widget build(BuildContext context) {
    var tagRaw = widget.name;
    var group = widget.group;
    Color color = Colors.grey;

    if (group == 'female')
      color = Colors.pink;
    else if (group == 'male')
      color = Colors.blue;
    else if (group == 'language')
      color = Colors.teal;
    else if (group == 'series')
      color = Colors.cyan;
    else if (group == 'artist' || group == 'group')
      color = Colors.green.withOpacity(0.6);
    else if (group == 'type') color = Colors.orange;

    Widget avatar = Text(group[0].toUpperCase());

    if (group == 'female')
      avatar = Icon(MdiIcons.genderFemale, size: 18.0);
    else if (group == 'male')
      avatar = Icon(MdiIcons.genderMale, size: 18.0);
    else if (group == 'language')
      avatar = Icon(Icons.language, size: 18.0);
    else if (group == 'artist')
      avatar = Icon(MdiIcons.account, size: 18.0);
    else if (group == 'group')
      avatar = Icon(MdiIcons.accountGroup, size: 15.0);
    else if (group == 'type')
      avatar = Icon(MdiIcons.bookOpenPageVariant, size: 15.0);
    else if (group == 'series') avatar = Icon(MdiIcons.notebook, size: 15.0);

    var fc = Transform.scale(
        scale: 0.90,
        child: RawChip(
          selected: widget.selected,
          labelPadding: EdgeInsets.all(0.0),
          avatar: CircleAvatar(
            backgroundColor: Colors.grey.shade600,
            child: avatar,
          ),
          label: Text(
            ' ' +
                HtmlUnescape().convert(tagRaw) +
                ' (' +
                widget.count.toString() +
                ')',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          elevation: 6.0,
          padding: EdgeInsets.all(6.0),
          onSelected: (value) async {
            widget.callback(value);
            setState(() {
              widget.selected = value;
            });
          },
        ));
    return fc;
  }
}
