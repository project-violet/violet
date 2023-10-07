// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi_parser.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/artist_info/search_type2.dart';
import 'package:violet/pages/bookmark/group/group_artist_article_list.dart';
import 'package:violet/pages/bookmark/group/group_artist_list.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/filter_page.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/debounce_widget.dart';
import 'package:violet/widgets/dots_indicator.dart';
import 'package:violet/widgets/floating_button.dart';
import 'package:violet/widgets/search_bar.dart';

class GroupArticleListPage extends StatefulWidget {
  final String name;
  final int groupId;

  const GroupArticleListPage({
    Key? key,
    required this.name,
    required this.groupId,
  }) : super(key: key);

  @override
  State<GroupArticleListPage> createState() => _GroupArticleListPageState();
}

class _GroupArticleListPageState extends State<GroupArticleListPage> {
  final PageController _controller = PageController(
    initialPage: 0,
  );

  static const _kDuration = Duration(milliseconds: 300);
  static const _kCurve = Curves.ease;

  final ScrollController _scroll = ScrollController();

  Map<String, GlobalKey> itemKeys = <String, GlobalKey>{};

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

  void _rebuild() {
    _shouldRebuild = true;
    itemKeys.clear();
    setState(() {
      _shouldRebuild = true;
      key = ObjectKey(const Uuid().v4());
    });
  }

  Future<QueryResult> _tryGetArticleFromHitomi(String id) async {
    var headers = await ScriptManager.runHitomiGetHeaderContent(id);
    var hh = await http.get(
      'https://ltn.hitomi.la/galleryblock/$id.html',
      headers: headers,
    );
    var article = await HitomiParser.parseGalleryBlock(hh.body);
    var meta = {
      'Id': int.parse(id),
      'Title': article['Title'],
      'Artists': article['Artists'].join('|'),
    };
    return QueryResult(result: meta);
  }

  Future<void> _loadBookmarkAlignType() async {
    final prefs = await SharedPreferences.getInstance();
    nowType = prefs.getInt('bookmark_${widget.groupId}') ?? 3;
  }

  void refresh() {
    _loadBookmarkAlignType();
    Bookmark.getInstance().then((value) =>
        value.getArticle().then((value) async {
          var cc = value
              .where((e) => e.group() == widget.groupId)
              .toList()
              .reversed
              .toList();

          if (cc.isEmpty) {
            queryResult = <QueryResult>[];
            filterResult = queryResult;
            _rebuild();
            return;
          }

          QueryManager.queryIds(cc.map((e) => int.parse(e.article())).toList())
              .then((value) async {
            var qr = <String, QueryResult>{};
            value.forEach((element) {
              qr[element.id().toString()] = element;
            });

            var result = <QueryResult>[];
            cc.forEach((element) async {
              var article = qr[element.article()];
              article ??= await _tryGetArticleFromHitomi(element.article());
              result.add(article);
            });

            queryResult = result;
            _applyFilter();
            _rebuild();
          });
        }));
  }

  bool _shouldRebuild = false;
  Widget? _cachedList;

  @override
  Widget build(BuildContext context) {
    if (_cachedList == null || _shouldRebuild) {
      final list = buildList();

      _shouldRebuild = false;
      _cachedList = list;
    }

    final scrollView = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: <Widget>[
        SliverPersistentHeader(
          floating: true,
          delegate: AnimatedOpacitySliver(
            searchBar: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Stack(children: <Widget>[
                  _filter(),
                  _title(),
                ])),
          ),
        ),
        _cachedList!
      ],
    );

    // TODO: fix bug that all sub widgets are loaded simultaneously
    // so, this occured memory leak and app crash
    final articleList = nowType >= 2
        ? scrollView
        : PrimaryScrollController(
            controller: _scroll,
            child: CupertinoScrollbar(
              scrollbarOrientation: Settings.bookmarkScrollbarPositionToLeft
                  ? ScrollbarOrientation.left
                  : ScrollbarOrientation.right,
              child: scrollView,
            ),
          );

    return CardPanel.build(
      context,
      child: Stack(
        children: [
          PageView(
            controller: _controller,
            children: [
              Scaffold(
                resizeToAvoidBottomInset: false,
                // resizeToAvoidBottomPadding: false,
                floatingActionButton: Visibility(
                  visible: checkMode,
                  child: AnimatedOpacity(
                    opacity: checkModePre ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: _floatingButton(),
                  ),
                ),
                // floatingActionButton: Container(child: Text('asdf')),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                  child: articleList,
                ),
              ),
              GroupArtistList(name: widget.name, groupId: widget.groupId),
              GroupArtistArticleList(
                  name: widget.name, groupId: widget.groupId),
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
                  itemCount: 3,
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

  Widget _floatingButton() {
    return AnimatedFloatingActionButton(
      fabButtons: <Widget>[
        FloatingActionButton(
          onPressed: () {
            filterResult.forEach((element) {
              checked.add(element.id());
            });
            _shouldRebuild = true;
            setState(() {
              _shouldRebuild = true;
            });
          },
          elevation: 4,
          heroTag: 'a',
          child: const Icon(MdiIcons.checkAll),
        ),
        FloatingActionButton(
          onPressed: () async {
            if (await showYesNoDialog(
                context,
                Translations.of(context)
                    .trans('deletebookmarkmsg')
                    .replaceAll('%s', checked.length.toString()),
                Translations.of(context).trans('bookmark'))) {
              var bookmark = await Bookmark.getInstance();
              checked.forEach((element) async {
                bookmark.unbookmark(element);
              });
              checked.clear();
              refresh();
            }
          },
          elevation: 4,
          heroTag: 'b',
          child: const Icon(MdiIcons.delete),
        ),
        FloatingActionButton(
          onPressed: moveChecked,
          elevation: 4,
          heroTag: 'c',
          child: const Icon(MdiIcons.folderMove),
        ),
      ],
      animatedIconData: AnimatedIcons.menu_close,
      exitCallback: () {
        _shouldRebuild = true;
        setState(() {
          _shouldRebuild = true;
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          _shouldRebuild = true;
          setState(() {
            _shouldRebuild = true;
            checkMode = false;
          });
        });
      },
    );
  }

  Widget _filter() {
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
          elevation: !Settings.themeFlat ? 100 : 0,
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
              if (checkMode) return;
              Navigator.of(context)
                  .push(PageRouteBuilder(
                opaque: false,
                transitionDuration: const Duration(milliseconds: 500),
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
                itemKeys.clear();

                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('bookmark_${widget.groupId}', value);
                await Future.delayed(const Duration(milliseconds: 50), () {
                  _shouldRebuild = true;
                  setState(() {
                    _shouldRebuild = true;
                  });
                });
              });
            },
            onLongPress: () {
              if (checkMode) return;
              isFilterUsed = true;

              PlatformNavigator.navigateFade(
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

  bool isFilterUsed = false;

  List<QueryResult> queryResult = <QueryResult>[];
  List<QueryResult> filterResult = <QueryResult>[];

  void _applyFilter() {
    filterResult = _filterController.applyFilter(queryResult);
    isFilterUsed = true;
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: SliverGrid(
            key: key,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mm,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildListDelegate(filterResult.map((e) {
              var keyStr = 'group/${widget.groupId}/$nowType/${e.id()}';
              if (!itemKeys.containsKey(keyStr)) itemKeys[keyStr] = GlobalKey();
              return DebounceWidget(
                child: Padding(
                  key: itemKeys[keyStr],
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
                          thumbnailTag: const Uuid().v4(),
                          bookmarkMode: true,
                          bookmarkCallback: longpress,
                          bookmarkCheckCallback: check,
                          usableTabList: filterResult,
                          // isCheckMode: checkMode,
                          // isChecked: checked.contains(e.id()),
                        ),
                        child: ArticleListItemWidget(
                          isCheckMode: checkMode,
                          isChecked: checked.contains(e.id()),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList()),
          ),
        );

      case 2:
      case 3:
      case 4:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: SliverList(
            key: key,
            delegate: SliverChildListDelegate(filterResult.map((x) {
              var keyStr = 'group/${widget.groupId}/$nowType/${x.id()}';
              if (!itemKeys.containsKey(keyStr)) itemKeys[keyStr] = GlobalKey();
              return Align(
                key: itemKeys[keyStr],
                alignment: Alignment.center,
                child: Provider<ArticleListItem>.value(
                  value: ArticleListItem.fromArticleListItem(
                    queryResult: x,
                    showDetail: nowType >= 3,
                    showUltra: nowType == 4,
                    addBottomPadding: true,
                    width: (windowWidth - 4.0),
                    thumbnailTag: const Uuid().v4(),
                    bookmarkMode: true,
                    bookmarkCallback: longpress,
                    bookmarkCheckCallback: check,
                    usableTabList: filterResult,
                    // isCheckMode: checkMode,
                    // isChecked: checked.contains(x.id()),
                  ),
                  child: ArticleListItemWidget(
                    isCheckMode: checkMode,
                    isChecked: checked.contains(x.id()),
                  ),
                ),
              );
            }).toList()),
          ),
        );

      default:
        return const Center(
          child: Text('Error :('),
        );
    }
  }

  bool checkMode = false;
  bool checkModePre = false;
  List<int> checked = [];

  void longpress(int article) {
    print(article);
    if (!checkMode) {
      checkMode = true;
      checkModePre = true;
      checked.add(article);
      _shouldRebuild = true;
      setState(() {
        _shouldRebuild = true;
      });
    }
  }

  void check(int article, bool check) {
    if (check) {
      checked.add(article);
    } else {
      checked.removeWhere((element) => element == article);
      if (checked.isEmpty) {
        _shouldRebuild = true;
        setState(() {
          _shouldRebuild = true;
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          _shouldRebuild = true;
          setState(() {
            _shouldRebuild = true;
            checkMode = false;
          });
        });
      }
    }
  }

  Future<void> moveChecked() async {
    var groups = await (await Bookmark.getInstance()).getGroup();
    var currentGroup = widget.groupId;
    groups =
        groups.where((e) => e.id() != currentGroup && e.id() != 1).toList();
    int choose = -9999;
    if (await showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
                  title: Text(Translations.of(context).trans('wheretomove')),
                  actions: <Widget>[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Settings.majorColor,
                      ),
                      child: Text(Translations.of(context).trans('cancel')),
                      onPressed: () {
                        Navigator.pop(context, 0);
                      },
                    ),
                  ],
                  content: SizedBox(
                    width: 200,
                    height: 300,
                    child: ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(groups[index].name()),
                          subtitle: Text(groups[index].description()),
                          onTap: () {
                            choose = index;
                            Navigator.pop(context, 1);
                          },
                        );
                      },
                    ),
                  ),
                )) ==
        1) {
      if (await showYesNoDialog(
          context,
          Translations.of(context)
              .trans('movetoto')
              .replaceAll('%1', groups[choose].name())
              .replaceAll('%2', checked.length.toString()),
          Translations.of(context).trans('movebookmark'))) {
        // There is a way to change only the group, but there is also re-register a new bookmark.
        // I chose the latter to suit the user's intentions.

        // Atomic!!
        // 0. Sort Checked
        var invIdIndex = <int, int>{};
        for (int i = 0; i < queryResult.length; i++) {
          invIdIndex[queryResult[i].id()] = i;
        }
        checked.sort((x, y) => invIdIndex[x]!.compareTo(invIdIndex[y]!));

        // 1. Get bookmark articles on source groupid
        var bm = await Bookmark.getInstance();
        // var article = await bm.getArticle();
        // var src = article
        //     .where((element) => element.group() == currentGroup)
        //     .toList();

        // 2. Save source bookmark for fault torlerance!
        // final cacheDir = await getTemporaryDirectory();
        // final path = File('${cacheDir.path}/bookmark_cache+${Uuid().v4()}');
        // path.writeAsString(jsonEncode(checked));

        for (var e in checked.reversed) {
          // 3. Delete source bookmarks
          await bm.unbookmark(e);
          // 4. Add src bookmarks with new groupid
          await bm.insertArticle(
              e.toString(), DateTime.now(), groups[choose].id());
        }

        // 5. Update UI
        _shouldRebuild = true;
        setState(() {
          _shouldRebuild = true;
          checkModePre = false;
          checked.clear();
        });
        _shouldRebuild = true;
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          setState(() {
            _shouldRebuild = true;
            checkMode = false;
          });
        });
        refresh();
      }
    } else {}
  }
}
