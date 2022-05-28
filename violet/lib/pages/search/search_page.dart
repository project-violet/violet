// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:math';

import 'package:auto_animated/auto_animated.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flare_flutter/provider/asset_flare.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/search.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/search/search_bar_page.dart';
import 'package:violet/pages/search/search_page_modify.dart';
import 'package:violet/pages/search/search_type.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/thread/semaphore.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/search_bar.dart';

bool blurred = false;

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin<SearchPage> {
  @override
  bool get wantKeepAlive => true;

  Color color = Colors.green;
  bool into = false;

  final FlareControls heroFlareControls = FlareControls();
  // FlutterActorArtboard? artboard;
  late AssetFlare asset;

  bool isFilterUsed = false;
  bool searchbarVisible = true;
  double upperPixel = 0;
  double latestOffset = 0.0;
  int eventCalled = 0;
  bool whenTopScroll = false;
  bool isExtended = false;

  DateTime datetime = DateTime.now();

  List<GlobalKey> itemKeys = <GlobalKey>[];
  double itemHeight = 0.0;
  ValueNotifier<int> searchPageNum = ValueNotifier<int>(0);
  int searchTotalResultCount = 0;
  int baseCount = 0; // using for user custom page index
  List<int> scrollQueue = <int>[];

  late final FToast fToast;

  void _showErrorToast(String message) {
    fToast.showToast(
      toastDuration: const Duration(seconds: 10),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(),
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        child: Text(message),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);

    asset =
        AssetFlare(bundle: rootBundle, name: 'assets/flare/search_close.flr');
    (() async {
      await cachedActor(asset);
    })();

    Future.delayed(Duration(milliseconds: 500), () async {
      try {
        final result =
            await HentaiManager.search('').timeout(const Duration(seconds: 5));

        latestQuery =
            Tuple2<Tuple2<List<QueryResult>, int>, String>(result, '');
        queryResult = latestQuery!.item1!.item1;
        if (_filterController.isPopulationSort)
          Population.sortByPopulation(queryResult);
        _shouldReload = true;
        setState(() {});

        if (searchTotalResultCount == 0) {
          Future.delayed(Duration(milliseconds: 100)).then((value) async {
            searchTotalResultCount = await HentaiManager.countSearch('');
            setState(() {});
          });
        }
      } catch (e, st) {
        Logger.error('[Initial-Search] E: $e\n'
            '$st');
        print('Initial search failed: $e');
        _showErrorToast('Failed to search all: $e');
      }
    }).catchError((e, st) {
      // It happened!
      Logger.error('[Initial-SearchI] E: $e'
          '\n$st');
      print('Initial search interrupted: $e');
      _showErrorToast('Initial search interrupted: $e');
    });

    _scroll.addListener(() {
      //
      // scroll position
      //
      if (itemKeys.isNotEmpty && itemHeight <= 0.1) {
        if (itemKeys[0].currentContext != null) {
          const bottomPadding = 8;
          itemHeight = itemKeys[0].currentContext!.size!.height + bottomPadding;
        }
      }

      final itemPerRow = [3, 2, 1, 1][Settings.searchResultType];
      const searchBarHeight = 64 + 16;
      final curI =
          ((_scroll.offset - searchBarHeight) / itemHeight + 1).toInt() *
              itemPerRow;

      if (curI != searchPageNum.value && isExtended) {
        searchPageNum.value = curI;
      }

      //
      // scroll direction
      //
      var upScrolling =
          _scroll.position.userScrollDirection == ScrollDirection.forward;

      if (upScrolling)
        scrollQueue.add(-1);
      else
        scrollQueue.add(1);

      if (scrollQueue.length > 64) {
        scrollQueue.removeRange(0, scrollQueue.length - 65);
      }

      var p = scrollQueue.reduce((value, element) => value + element);

      if (p <= -32 && !isExtended) {
        isExtended = true;
        setState(() {});
      } else if (p >= 32 && isExtended) {
        isExtended = false;
        setState(() {});
      }

      //
      //  scroll lazy next query loading
      //
      if (scrollInProgress || queryEnd) return;
      if (_scroll.offset > _scroll.position.maxScrollExtent * 3 / 4) {
        scrollInProgress = true;
        Future.delayed(Duration(milliseconds: 100), () async {
          try {
            await loadNextQuery();
          } catch (e) {
            print('loadNextQuery failed: $e');
          } finally {
            scrollInProgress = false;
          }
        }).catchError((e) {
          // It happened!
          print('Scrolling interrupted: $e');
          _showErrorToast('Scrolling interrupted: $e');
          scrollInProgress = false;
        });
      }
    });
  }

  bool scrollInProgress = false;

  Tuple2<Tuple2<List<QueryResult>, int>?, String>? latestQuery;

  final ScrollController _scroll = ScrollController();

  bool _shouldReload = false;
  ResultPanelWidget? _cachedPannel;

  // https://stackoverflow.com/questions/60643355/is-it-possible-to-have-both-expand-and-contract-effects-with-the-slivers-in
  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_cachedPannel == null || _shouldReload) {
      _shouldReload = false;

      itemKeys.clear();
      itemKeys.add(GlobalKey());

      final panel = ResultPanelWidget(
        dateTime: datetime,
        resultList: filter(),
        itemKeys: itemKeys,
        sliverKey: key,
      );

      _cachedPannel = panel;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPersistentHeader(
              floating: true,
              delegate: AnimatedOpacitySliver(
                searchBar: Stack(
                  children: <Widget>[
                    _searchBar(),
                    _align(),
                  ],
                ),
              ),
            ),
            _cachedPannel!,
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Settings.majorColor,
        label: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              child: child,
            ),
          ),
          child: !isExtended
              ? Icon(MdiIcons.bookOpenPageVariantOutline)
              : Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(MdiIcons.bookOpenPageVariantOutline),
                    ),
                    ValueListenableBuilder(
                      valueListenable: searchPageNum,
                      builder:
                          (BuildContext context, int value, Widget? child) {
                        return Text(
                            '${value + baseCount}/${queryResult.length}/$searchTotalResultCount');
                      },
                    ),
                  ],
                ),
        ),
        onPressed: () async {
          var rr = await showDialog(
            context: context,
            builder: (BuildContext context) => SearchPageModifyPage(
              curPage: searchPageNum.value + baseCount,
              maxPage: searchTotalResultCount,
            ),
          );
          if (rr == null) return;

          if (rr[0] == 1) {
            var setPage = rr[1] as int;

            baseCount = setPage;

            latestQuery = Tuple2<Tuple2<List<QueryResult>, int>, String>(
                Tuple2<List<QueryResult>, int>(<QueryResult>[], baseCount),
                latestQuery!.item2);
            queryEnd = false;
            queryResult = [];
            _filterController = FilterController();
            isFilterUsed = false;
            _shouldReload = true;
            searchTotalResultCount = 0;
            searchPageNum.value = 0;
            await loadNextQuery();
            setState(() {
              _cachedPannel = null;
              _shouldReload = true;
              key = ObjectKey(Uuid().v4());
            });
          }
        },
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 72, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'searchbar',
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(4.0),
              ),
            ),
            elevation: !Settings.themeFlat ? 100 : 0,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Material(
                      color: Settings.themeWhat
                          ? Settings.themeBlack
                              ? const Color(0xFF141414)
                              : Colors.grey.shade900.withOpacity(0.4)
                          : Colors.grey.shade200.withOpacity(0.4),
                      child: ListTile(
                        title: TextFormField(
                          cursorColor: Colors.black,
                          decoration: InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.only(
                                  left: 15, bottom: 11, top: 11, right: 15),
                              hintText: latestQuery != null &&
                                      latestQuery!.item2.trim() != ''
                                  ? latestQuery!.item2
                                  : Translations.of(context).trans('search')),
                        ),
                        leading: SizedBox(
                          width: 25,
                          height: 25,
                          child: FlareActor.asset(asset,
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
                      onTap: _showSearchBar,
                      onDoubleTap: () async {
                        // latestQuery = value;
                        latestQuery =
                            Tuple2<Tuple2<List<QueryResult>, int>?, String>(
                                null, 'random:${Random().nextDouble() + 1}');
                        queryResult = [];
                        _filterController = FilterController();
                        queryEnd = false;
                        isFilterUsed = false;
                        _shouldReload = true;
                        searchTotalResultCount = 0;
                        searchPageNum.value = 0;
                        baseCount = 0;
                        await loadNextQuery();
                        setState(() {
                          _cachedPannel = null;
                          _shouldReload = true;
                          key = ObjectKey(Uuid().v4());
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSearchBar() async {
    await Future.delayed(Duration(milliseconds: 200));
    heroFlareControls.play('search2close');
    final query = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return SearchBarPage(
            assetProvider: asset,
            initText: latestQuery != null ? latestQuery!.item2 : '',
            heroController: heroFlareControls,
          );
        },
        fullscreenDialog: true,
      ),
    );
    try {
      final db = await SearchLogDatabase.getInstance();
      await db.insertSearchLog(query);
      setState(() {
        heroFlareControls.play('close2search');
      });
      if (query == null) return;

      latestQuery =
          Tuple2<Tuple2<List<QueryResult>, int>?, String>(null, query);
      queryResult = [];
      _filterController = FilterController();
      queryEnd = false;
      isFilterUsed = false;
      searchPageNum.value = 0;
      searchTotalResultCount = 0;
      baseCount = 0;
      await loadNextQuery().then((value) {
        setState(() {
          _cachedPannel = null;
          _shouldReload = true;
          key = ObjectKey(Uuid().v4());
        });
      });
    } catch (e, st) {
      await Logger.error(
          '[showSearchBar] E: ${e.toString()}\n${st.toString()}');
    }
  }

  Widget _align() {
    double width = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.fromLTRB(width - 8 - 64, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'searchtype',
          child: Card(
            color: Settings.themeWhat
                ? Settings.themeBlack
                    ? const Color(0xFF141414)
                    : Color(0xFF353535)
                : Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(4.0),
              ),
            ),
            elevation: !Settings.themeFlat ? 100 : 0,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: InkWell(
              onTap: _alignOnTap,
              onLongPress: _alignLongPress,
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
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _alignOnTap() async {
    Navigator.of(context)
        .push(PageRouteBuilder(
      opaque: false,
      transitionDuration: Duration(milliseconds: 500),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget wi) {
        return FadeTransition(opacity: animation, child: wi);
      },
      pageBuilder: (_, __, ___) => SearchType(),
      barrierColor: Colors.black12,
      barrierDismissible: true,
    ))
        .then((value) async {
      await Future.delayed(Duration(milliseconds: 50), () {
        _shouldReload = true;
        itemHeight = 0.0;
        setState(() {});
      });
    });
  }

  Future<void> _alignLongPress() async {
    PlatformNavigator.navigateFade(
      context,
      Provider<FilterController>.value(
        value: _filterController,
        child: FilterPage(
          queryResult: queryResult,
        ),
      ),
    ).then((value) {
      _applyFilter();
      _shouldReload = true;
      searchPageNum.value = 0;
      setState(() {
        _cachedPannel = null;
        _shouldReload = true;
        key = ObjectKey(Uuid().v4());
      });
    });
  }

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

  FilterController _filterController = FilterController();

  List<QueryResult> queryResult = [];
  List<QueryResult> filterResult = [];

  ObjectKey key = ObjectKey(Uuid().v4());

  bool queryEnd = false;
  final Semaphore _querySem = Semaphore(maxCount: 1);

  Future<void> loadNextQuery() async {
    await _querySem.acquire().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _showErrorToast('Semaphore acquisition failed');

        throw TimeoutException('Failed to acquire the query semaphore');
      },
    );

    try {
      if (queryEnd ||
          (latestQuery!.item1 != null && latestQuery!.item1!.item2 == -1))
        return;

      var next = await HentaiManager.search(latestQuery!.item2,
              latestQuery!.item1 == null ? 0 : latestQuery!.item1!.item2)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        Logger.error('[Search_loadNextQuery] Search Timeout');

        throw TimeoutException('Failed to search the query');
      });

      latestQuery = Tuple2<Tuple2<List<QueryResult>, int>, String>(
          next, latestQuery!.item2);

      if (next.item1.isEmpty) {
        setState(() {
          _cachedPannel = null;
          queryEnd = true;
          _shouldReload = true;
          key = ObjectKey(Uuid().v4());
        });
        return;
      }

      queryResult.addAll(next.item1);

      if (_filterController.isPopulationSort)
        Population.sortByPopulation(queryResult);

      if (searchTotalResultCount == 0 &&
          !latestQuery!.item2.contains('random:')) {
        Future.delayed(Duration(milliseconds: 100)).then((value) async {
          searchTotalResultCount =
              await HentaiManager.countSearch(latestQuery!.item2);
          setState(() {});
        });
      }

      setState(() {
        _cachedPannel = null;
        _shouldReload = true;
        key = ObjectKey(Uuid().v4());
      });

      ScriptManager.refresh();
    } catch (e, st) {
      Logger.error('[search-error] E: $e\n'
          '$st');
      rethrow;
    } finally {
      _querySem.release();
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
    if (!isFilterUsed) return queryResult;
    return filterResult;
  }
}

class ResultPanelWidget extends StatelessWidget {
  final List<QueryResult> resultList;
  final DateTime dateTime;
  final ObjectKey sliverKey;
  final List<GlobalKey> itemKeys;

  const ResultPanelWidget({
    Key? key,
    required this.resultList,
    required this.dateTime,
    required this.sliverKey,
    required this.itemKeys,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var mm = Settings.searchResultType == 0 ? 3 : 2;
    var windowWidth = MediaQuery.of(context).size.width;

    switch (Settings.searchResultType) {
      case 0:
      case 1:
        return SliverPadding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: SliverGrid(
              key: key,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Settings.useTabletMode ? mm * 2 : mm,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3 / 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return Padding(
                    key:
                        itemKeys.length > index ? itemKeys[index] : GlobalKey(),
                    padding: EdgeInsets.zero,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        child: Provider<ArticleListItem>.value(
                          value: ArticleListItem.fromArticleListItem(
                            queryResult: resultList[index],
                            showDetail: false,
                            addBottomPadding: false,
                            width: (windowWidth - 4.0) / mm,
                            thumbnailTag:
                                'thumbnail${resultList[index].id()}${dateTime}',
                            usableTabList: resultList,
                          ),
                          child: ArticleListItemVerySimpleWidget(),
                        ),
                      ),
                    ),
                  );
                },
                childCount: resultList.length,
              ),
            ));

      case 2:
      case 3:
        if (Settings.useTabletMode ||
            MediaQuery.of(context).orientation == Orientation.landscape) {
          return SliverPadding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: LiveSliverGrid(
              key: key,
              controller: ScrollController(),
              showItemInterval: Duration(milliseconds: 50),
              showItemDuration: Duration(milliseconds: 150),
              visibleFraction: 0.001,
              itemCount: resultList.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: (windowWidth / 2) / 130,
              ),
              itemBuilder: (context, index, animation) {
                return Align(
                  key: itemKeys.length > index ? itemKeys[index] : GlobalKey(),
                  alignment: Alignment.center,
                  child: Provider<ArticleListItem>.value(
                    value: ArticleListItem.fromArticleListItem(
                      addBottomPadding: true,
                      showDetail: Settings.searchResultType == 3,
                      queryResult: resultList[index],
                      width: windowWidth - 4.0,
                      thumbnailTag:
                          'thumbnail${resultList[index].id()}${dateTime}',
                      usableTabList: resultList,
                    ),
                    child: ArticleListItemVerySimpleWidget(),
                  ),
                );
              },
            ),
          );
        } else {
          return SliverList(
            key: key,
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return Align(
                  key: itemKeys.length > index ? itemKeys[index] : GlobalKey(),
                  alignment: Alignment.center,
                  child: Provider<ArticleListItem>.value(
                    value: ArticleListItem.fromArticleListItem(
                      addBottomPadding: true,
                      showDetail: Settings.searchResultType == 3,
                      queryResult: resultList[index],
                      width: windowWidth - 4.0,
                      thumbnailTag:
                          'thumbnail${resultList[index].id()}${dateTime}',
                      usableTabList: resultList,
                    ),
                    child: ArticleListItemVerySimpleWidget(),
                  ),
                );
              },
              childCount: resultList.length,
            ),
          );
        }
      default:
        return Container(
          child: Center(
            child: Text('Error :('),
          ),
        );
    }
  }
}
