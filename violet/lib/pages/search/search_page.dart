// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:math';

import 'package:auto_animated/auto_animated.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/context/modal_bottom_sheet_context.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/search.dart';
import 'package:violet/locale/locale.dart' as trans;
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/search_message.dart';
import 'package:violet/pages/search/search_bar_page.dart';
import 'package:violet/pages/search/search_page_controller.dart';
import 'package:violet/pages/search/search_page_modify.dart';
import 'package:violet/pages/search/search_type.dart';
import 'package:violet/pages/segment/double_tap_to_top.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/search_bar.dart';
import 'package:violet/widgets/theme_switchable_state.dart';

bool blurred = false;

class SearchPage extends StatefulWidget {
  final String? searchKeyWord;

  const SearchPage({super.key, this.searchKeyWord});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ThemeSwitchableState<SearchPage>
    with AutomaticKeepAliveClientMixin<SearchPage>, DoubleTapToTopMixin {
  @override
  bool get wantKeepAlive => widget.searchKeyWord == null;

  @override
  VoidCallback? get shouldReloadCallback => () => _shouldReload = true;

  late final String getxId;
  late final SearchPageController c;

  final DateTime datetime = DateTime.now();

  @override
  void initState() {
    super.initState();

    getxId = const Uuid().v4();
    c = Get.put(
      SearchPageController(reloadForce: reloadForce),
      tag: getxId,
    );

    c.init(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doInitialSearch();
    });
  }

  doInitialSearch() async {
    try {
      final result = await HentaiManager.search(widget.searchKeyWord ?? '')
          .timeout(const Duration(seconds: 5));

      c.latestQuery = Tuple2(result, widget.searchKeyWord ?? '');
      c.queryResult = c.latestQuery!.item1!.results;
      if (c.filterController.isPopulationSort) {
        Population.sortByPopulation(c.queryResult);
      }
      reloadForce();

      if (c.searchTotalResultCount.value == 0) {
        Future.delayed(const Duration(milliseconds: 100)).then((value) async {
          c.searchTotalResultCount.value =
              await HentaiManager.countSearch(widget.searchKeyWord ?? '');
        });
      }
    } catch (e, st) {
      Logger.error('[Initial-Search] E: $e\n'
          '$st');
      c.showErrorToast('Failed to search all: $e');
    }
  }

  welcomeMessage() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('litemode_welcome_message') == null) {
      prefs.setBool('litemode_welcome_message', true);
      showOkDialog(context, '라이트 모드가 활성화되었습니다! 설정에서 라이트 모드를 끌 수 있습니다.');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    welcomeMessage();
    c.initScroll(context);
    doubleTapToTopScrollController = c.scrollController;
  }

  bool _shouldReload = false;
  ResultPanelWidget? _cachedPannel;
  ObjectKey key = ObjectKey(const Uuid().v4());

  reloadForce() {
    setState(() {
      _cachedPannel = null;
      _shouldReload = true;
      key = ObjectKey(const Uuid().v4());
    });
  }

  // https://stackoverflow.com/questions/60643355/is-it-possible-to-have-both-expand-and-contract-effects-with-the-slivers-in
  @override
  Widget build(BuildContext context) {
    super.build(context);

    print('build!');

    if (_cachedPannel == null || _shouldReload) {
      _shouldReload = false;

      c.itemKeys.clear();

      final panel = ResultPanelWidget(
        dateTime: datetime,
        resultList: c.getSearchList(),
        itemKeys: c.itemKeys,
        sliverKey: key,
      );

      _cachedPannel = panel;
    }

    final slivers = [
      if (widget.searchKeyWord == null)
        SliverPersistentHeader(
          floating: true,
          delegate: AnimatedOpacitySliver(
            searchBar: Stack(
              children: <Widget>[
                searchBar(),
                msgsearch(),
                align(),
              ],
            ),
          ),
        )
      else
        SliverToBoxAdapter(
          child: Container(
            height: 16,
          ),
        ),
      _cachedPannel!,
    ];

    late Widget scrollView;

    if (widget.searchKeyWord == null) {
      scrollView = CustomScrollView(
        controller: c.scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: slivers,
      );
    } else {
      scrollView = CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          border: const Border(bottom: BorderSide(color: Colors.transparent)),
          leading: CupertinoButton(
            padding: const EdgeInsets.all(10),
            onPressed: alignOnTap,
            child: const Icon(
              MdiIcons.formatListText,
              size: 21.0,
              color: Colors.grey,
            ),
          ),
          middle: Text(widget.searchKeyWord!),
          trailing: CupertinoButton(
            padding: const EdgeInsets.all(10),
            onPressed: alignLongPress,
            child: const Icon(
              MdiIcons.filter,
              size: 21.0,
              color: Colors.grey,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: NestedScrollView(
            controller: c.scrollController,
            physics: const ScrollPhysics(parent: PageScrollPhysics()),
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return [];
            },
            body: CustomScrollView(
              controller: ModalScrollController.of(context),
              physics: const BouncingScrollPhysics(),
              slivers: slivers,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: scrollView,
      ),
      floatingActionButton: _floatingActionButton(),
    );
  }

  Widget _floatingActionButton() {
    return FloatingActionButton.extended(
      backgroundColor: Settings.majorColor,
      label: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
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
          child: !c.isExtended.value
              ? const Icon(MdiIcons.bookOpenPageVariantOutline)
              : Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 4.0),
                      child: Icon(MdiIcons.bookOpenPageVariantOutline),
                    ),
                    Obx(
                      () => Text(
                          '${c.searchPageNum.value + c.baseCount}/${c.queryResult.length}/${c.searchTotalResultCount}'),
                    ),
                  ],
                ),
        ),
      ),
      onPressed: () async {
        var rr = await showDialog(
          context: context,
          builder: (BuildContext context) => SearchPageModifyPage(
            curPage: c.searchPageNum.value + c.baseCount,
            maxPage: c.searchTotalResultCount.value,
          ),
        );
        if (rr == null) return;

        if (rr[0] == 1) {
          final setPage = rr[1] as int;

          c.latestQuery = Tuple2(
            SearchResult(results: [], offset: setPage),
            c.latestQuery!.item2,
          );

          c.doSearch(setPage);
        }
      },
    );
  }

  searchBar() {
    final searchHintText =
        c.latestQuery != null && c.latestQuery!.item2.trim() != ''
            ? c.latestQuery!.item2
            : widget.searchKeyWord ??
                trans.Translations.of(context).trans('search');

    final textFormField = TextFormField(
      cursorColor: Colors.black,
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.only(
          left: 15,
          bottom: 11,
          top: 11,
          right: 15,
        ),
        hintText: searchHintText,
      ),
    );

    final searchBar = Column(
      children: <Widget>[
        Material(
          color: Settings.themeWhat
              ? Settings.themeBlack
                  ? Palette.blackThemeBackground
                  : Colors.grey.shade900.withOpacity(0.4)
              : Colors.grey.shade200.withOpacity(0.4),
          child: ListTile(
            title: textFormField,
            leading: SizedBox(
              width: 25,
              height: 25,
              child: FlareActor.asset(
                c.asset,
                controller: c.heroFlareControls,
              ),
            ),
          ),
        )
      ],
    );

    final searchBarOverlay = Positioned(
      left: 0.0,
      top: 0.0,
      bottom: 0.0,
      right: 0.0,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: showSearchBar,
          onDoubleTap: () async {
            if (widget.searchKeyWord != null) return;
            c.latestQuery = Tuple2(null, 'random:${Random().nextDouble() + 1}');
            c.doSearch();
          },
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 72 * 2, 0),
      child: SizedBox(
        height: 64,
        child: Card(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(4.0),
            ),
          ),
          elevation: !Settings.themeFlat ? 100 : 0,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Stack(
            children: <Widget>[
              searchBar,
              searchBarOverlay,
            ],
          ),
        ),
      ),
    );
  }

  showSearchBar() async {
    if (widget.searchKeyWord != null) return;

    await Future.delayed(const Duration(milliseconds: 200));

    c.heroFlareControls.play('search2close');

    final query = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return SearchBarPage(
            assetProvider: c.asset,
            initText: c.latestQuery != null ? c.latestQuery!.item2 : '',
            heroController: c.heroFlareControls,
          );
        },
        fullscreenDialog: true,
      ),
    );

    try {
      final db = await SearchLogDatabase.getInstance();
      await db.insertSearchLog(query);
      setState(() {
        c.heroFlareControls.play('close2search');
      });
      if (query == null) return;

      c.latestQuery = Tuple2(null, query);
      c.doSearch();
    } catch (e, st) {
      await Logger.error(
          '[showSearchBar] E: ${e.toString()}\n${st.toString()}');
    }
  }

  msgsearch() {
    final width = MediaQuery.of(context).size.width;

    final msgsearchOverlay = InkWell(
      onTap: () {
        PlatformNavigator.navigateSlide(context, const LabSearchMessage());
      },
      child: const SizedBox(
        height: 64,
        width: 64,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              MdiIcons.commentSearch,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );

    final msgsearchBody = Card(
      color: Palette.themeColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0))),
      elevation: !Settings.themeFlat ? 100 : 0,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: msgsearchOverlay,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(width - 8 - 64 - 8 - 64, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'msgsearch${ModalBottomSheetContext.getCount()}',
          child: msgsearchBody,
        ),
      ),
    );
  }

  align() {
    final width = MediaQuery.of(context).size.width;

    final alignOverlay = InkWell(
      onTap: alignOnTap,
      onLongPress: alignLongPress,
      child: const SizedBox(
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
    );

    final alignBody = Card(
      color: Palette.themeColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0))),
      elevation: !Settings.themeFlat ? 100 : 0,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: alignOverlay,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(width - 8 - 64, 8, 8, 0),
      child: SizedBox(
        height: 64,
        child: Hero(
          tag: 'searchtype${ModalBottomSheetContext.getCount()}',
          child: alignBody,
        ),
      ),
    );
  }

  alignOnTap() async {
    final previousAlignType = Settings.searchResultType;

    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget wi) {
        return FadeTransition(opacity: animation, child: wi);
      },
      pageBuilder: (_, __, ___) => const SearchType(),
      barrierColor: Colors.black12,
      barrierDismissible: true,
    ));

    if (previousAlignType == Settings.searchResultType) return;

    await Future.delayed(const Duration(milliseconds: 50), () {
      _shouldReload = true;
      c.resetItemHeight();
      setState(() {});
    });
  }

  alignLongPress() async {
    final navigator = widget.searchKeyWord == null
        ? PlatformNavigator.navigateFade
        : PlatformNavigator.navigateSlide;
    navigator(
      context,
      Provider<FilterController>.value(
        value: c.filterController,
        child: FilterPage(
          queryResult: c.queryResult,
        ),
      ),
    ).then((value) {
      c.applyFilter();
      _shouldReload = true;
      c.searchPageNum.value = 0;
      reloadForce();
    });
  }
}

class ResultPanelWidget extends StatelessWidget {
  final List<QueryResult> resultList;
  final DateTime dateTime;
  final ObjectKey sliverKey;
  final Map<String, GlobalKey> itemKeys;

  const ResultPanelWidget({
    super.key,
    required this.resultList,
    required this.dateTime,
    required this.sliverKey,
    required this.itemKeys,
  });

  @override
  Widget build(BuildContext context) {
    final mm = Settings.searchResultType == 0 ? 3 : 2;
    final windowWidth = MediaQuery.of(context).size.width;

    switch (Settings.searchResultType) {
      case 0:
      case 1:
        return SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: SliverGrid(
              key: sliverKey,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Settings.useTabletMode ? mm * 2 : mm,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3 / 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return articleItem(
                    index,
                    mm,
                    windowWidth,
                    (windowWidth - 4.0) / mm,
                    alignment: Alignment.bottomCenter,
                  );
                },
                childCount: resultList.length,
              ),
            ));

      case 2:
      case 3:
      case 4:
        if (Settings.useTabletMode ||
            MediaQuery.of(context).orientation == Orientation.landscape) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: LiveSliverGrid(
              key: sliverKey,
              controller: ScrollController(),
              showItemInterval: const Duration(milliseconds: 50),
              showItemDuration: const Duration(milliseconds: 150),
              visibleFraction: 0.001,
              itemCount: resultList.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: (windowWidth / 2) / 130,
              ),
              itemBuilder: (context, index, animation) {
                return articleItem(
                  index,
                  mm,
                  windowWidth,
                  windowWidth - 4.0,
                  showDetail: Settings.searchResultType >= 3,
                  showUltra: Settings.searchResultType == 4,
                  addBottomPadding: true,
                );
              },
            ),
          );
        } else {
          return SliverList(
            key: key,
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return articleItem(
                  index,
                  mm,
                  windowWidth,
                  windowWidth - 4.0,
                  showDetail: Settings.searchResultType >= 3,
                  showUltra: Settings.searchResultType == 4,
                  addBottomPadding: true,
                );
              },
              childCount: resultList.length,
            ),
          );
        }
      default:
        return const Center(
          child: Text('Error :('),
        );
    }
  }

  articleItem(
    int index,
    int mm,
    double windowWidth,
    double width, {
    bool showDetail = false,
    bool showUltra = false,
    bool addBottomPadding = false,
    Alignment alignment = Alignment.center,
  }) {
    final keyStr = 'search/${resultList[index].id()}/$index';

    if (!itemKeys.containsKey(keyStr)) {
      itemKeys[keyStr] = GlobalKey();
    }

    final article = Provider<ArticleListItem>.value(
      value: ArticleListItem.fromArticleListItem(
        queryResult: resultList[index],
        showDetail: showDetail,
        showUltra: showUltra,
        addBottomPadding: addBottomPadding,
        width: width,
        thumbnailTag: 'thumbnail${resultList[index].id()}$dateTime',
        usableTabList: resultList,
      ),
      child: const ArticleListItemWidget(),
    );

    return Padding(
      key: itemKeys[keyStr],
      padding: EdgeInsets.zero,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          child: article,
        ),
      ),
    );
  }
}
