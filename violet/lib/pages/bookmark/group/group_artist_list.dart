// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mdi/mdi.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/debounce_widget.dart';
import 'package:violet/widgets/floating_button.dart';
import 'package:violet/widgets/search_bar.dart';

class GroupArtistList extends StatefulWidget {
  final String name;
  final int groupId;

  const GroupArtistList({super.key, required this.name, required this.groupId});

  @override
  State<GroupArtistList> createState() => _GroupArtistListState();
}

class _GroupArtistListState extends State<GroupArtistList>
    with AutomaticKeepAliveClientMixin<GroupArtistList> {
  @override
  bool get wantKeepAlive => true;
  late List<BookmarkArtist> artists;

  Future<List<BookmarkArtist>> _bookmark() async {
    if (_filterLevel == 0) await refresh();
    return artists;
  }

  Future<void> _sortByLatest() async {
    var ids = <Tuple2<int, int>>[];
    for (int i = 0; i < artists.length; i++) {
      var postfix = artists[i].artist().toLowerCase().replaceAll(' ', '_');
      var queryString = HitomiManager.translate2query(
          '${artists[i].type().name}:$postfix ${Settings.includeTags}');
      final qm = QueryManager.queryPagination(queryString);
      qm.itemsPerPage = 1;
      var query = (await qm.next())[0].id();
      ids.add(Tuple2<int, int>(query, i));
    }
    ids.sort((e1, e2) => e2.item1.compareTo(e1.item1));

    var newedList = <BookmarkArtist>[];
    for (int i = 0; i < artists.length; i++) {
      newedList.add(artists[ids[i].item2]);
    }

    artists = newedList;
  }

  Future<List<QueryResult>> _future(String e, ArtistType type) async {
    var postfix = e.toLowerCase().replaceAll(' ', '_');
    var queryString = HitomiManager.translate2query(
        '${type.name}:$postfix ${Settings.includeTags}');
    final qm = QueryManager.queryPagination(queryString);
    qm.itemsPerPage = 4;
    return await qm.next();
  }

  Future<void> refresh() async {
    artists = (await (await Bookmark.getInstance()).getArtist())
        .where((element) => element.group() == widget.groupId)
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
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
      body: FutureBuilder<List<BookmarkArtist>>(
        future: _bookmark(),
        builder: (BuildContext context,
            AsyncSnapshot<List<BookmarkArtist>> snapshot) {
          if (!snapshot.hasData) return Container();
          return PrimaryScrollController(
            controller: ScrollController(),
            child: CupertinoScrollbar(
              scrollbarOrientation: Settings.bookmarkScrollbarPositionToLeft
                  ? ScrollbarOrientation.left
                  : ScrollbarOrientation.right,
              child: CustomScrollView(
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
                  SliverList(
                    // padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        var e = artists[index];
                        return FutureBuilder<List<QueryResult>>(
                          future: _future(e.artist(), e.type()),
                          builder: (BuildContext context,
                              AsyncSnapshot<List<QueryResult>> snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                height: 195,
                              );
                            }
                            return _listItem(context, e, snapshot.data!);
                          },
                        );
                      },
                      childCount: _progressingFilter ? 0 : artists.length,
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _filterLevel = 0;
  bool _progressingFilter = false;
  Widget _filter() {
    return Align(
      alignment: Alignment.centerRight,
      child: Hero(
        tag: 'searchtype3',
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
            onTap: _progressingFilter
                ? null
                : () async {
                    setState(() {
                      _progressingFilter = true;
                    });
                    await _sortByLatest();
                    setState(() {
                      _progressingFilter = false;
                      _filterLevel = (_filterLevel + 1) % 2;
                    });
                  },
            child: SizedBox(
              height: 48,
              width: 48,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  _progressingFilter
                      ? const SizedBox(
                          height: 30,
                          width: 30,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.grey),
                          ))
                      : Icon(
                          [
                            MdiIcons.formatListText,
                            Mdi.sortClockDescendingOutline
                          ][_filterLevel],
                          color: Colors.grey,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title() {
    return const Padding(
      padding: EdgeInsets.only(top: 24, left: 12),
      child: Text('Artists Collection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _listItem(
      BuildContext context, BookmarkArtist e, List<QueryResult> qq) {
    final windowWidth = MediaQuery.of(context).size.width;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final columnCount = isLandscape ? 4 : 3;
    final subItemWidth = (windowWidth - 16 - 4.0 - 1.0) / columnCount;

    const kHeaderHeight = 33;
    const childAspectRatio = 3 / 4;
    final height = windowWidth / columnCount / childAspectRatio;

    return Container(
      color: checkMode &&
              checked
                  .where((element) =>
                      element.$1 == e.type() && element.$2 == e.artist())
                  .isNotEmpty
          ? Colors.amber
          : Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (checkMode) {
            check(
                e.type(),
                e.artist(),
                checked
                    .where((element) =>
                        element.$1 == e.type() && element.$2 == e.artist())
                    .isEmpty);
            setState(() {});
            return;
          }

          PlatformNavigator.navigateSlide(
            context,
            ArtistInfoPage(
              name: e.artist(),
              type: e.type(),
            ),
          );
        },
        onLongPress: checkMode
            ? null
            : () {
                longpress(e.type(), e.artist());
              },
        child: SizedBox(
          height: height + kHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                        ' ${e.type().name}:${e.artist()} (${HitomiManager.getArticleCount(e.type().name, e.artist())})',
                        style: const TextStyle(fontSize: 17)),
                  ],
                ),
                SizedBox(
                  height: height,
                  child: DebounceWidget(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _image(qq, 0, subItemWidth),
                        _image(qq, 1, subItemWidth),
                        _image(qq, 2, subItemWidth),
                        if (isLandscape) _image(qq, 3, subItemWidth),
                      ],
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

  Widget _image(List<QueryResult> qq, int index, double subItemWidth) {
    return Expanded(
        flex: 1,
        child: qq.length > index
            ? Padding(
                key: Key('${qq[index].id()}/${index}_thumbnail_bookmark'),
                padding: const EdgeInsets.all(4),
                child: Provider<ArticleListItem>.value(
                  value: ArticleListItem.fromArticleListItem(
                    queryResult: qq[index],
                    showDetail: false,
                    addBottomPadding: false,
                    width: subItemWidth,
                    thumbnailTag: const Uuid().v4(),
                    disableFilter: true,
                    usableTabList: qq,
                  ),
                  child: const ArticleListItemWidget(),
                ),
              )
            : Container());
  }

  Widget _floatingButton() {
    return AnimatedFloatingActionButton(
      fabButtons: <Widget>[
        FloatingActionButton(
          onPressed: () {
            for (var element in artists) {
              checked.add((element.type(), element.artist()));
            }
            setState(() {});
          },
          elevation: 4,
          heroTag: 'a',
          child: const Icon(MdiIcons.checkAll),
        ),
        FloatingActionButton(
          onPressed: () async {
            if (await showYesNoDialog(
                context,
                Translations.instance!
                    .trans('deletebookmarkmsg')
                    .replaceAll('%s', checked.length.toString()),
                Translations.instance!.trans('bookmark'))) {
              var bookmark = await Bookmark.getInstance();
              for (var element in checked) {
                await bookmark.unbookmarkArtist(element.$2, element.$1);
              }
              checked.clear();
              refresh();
              setState(() {
                checkModePre = false;
                checked.clear();
              });
              Future.delayed(const Duration(milliseconds: 500)).then((value) {
                setState(() {
                  checkMode = false;
                });
              });
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
        setState(() {
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          setState(() {
            checkMode = false;
          });
        });
      },
    );
  }

  bool checkMode = false;
  bool checkModePre = false;
  List<(ArtistType, String)> checked = [];

  void longpress(ArtistType type, String artist) {
    if (!checkMode) {
      checkMode = true;
      checkModePre = true;
      checked.add((type, artist));
      setState(() {});
    }
  }

  void check(ArtistType type, String artist, bool check) {
    if (check) {
      checked.add((type, artist));
    } else {
      checked
          .removeWhere((element) => element.$1 == type && element.$2 == artist);
      if (checked.isEmpty) {
        setState(() {
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          setState(() {
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
    if (!mounted) return;
    if (await showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
                  title: Text(Translations.instance!.trans('wheretomove')),
                  actions: <Widget>[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Settings.majorColor,
                      ),
                      child: Text(Translations.instance!.trans('cancel')),
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
      if (!mounted) return;
      if (await showYesNoDialog(
          context,
          Translations.instance!
              .trans('movetoto')
              .replaceAll('%1', groups[choose].name())
              .replaceAll('%2', checked.length.toString()),
          Translations.instance!.trans('movebookmark'))) {
        // There is a way to change only the group, but there is also re-register a new bookmark.
        // I chose the latter to suit the user's intentions.

        // Atomic!!
        // 0. Sort Checked
        var invIdIndex = <String, int>{};
        for (int i = 0; i < artists.length; i++) {
          invIdIndex['${artists[i].artist()}|${artists[i].type()}'] = i;
        }
        checked.sort((x, y) => invIdIndex['${x.$2}|${x.$1}']!
            .compareTo(invIdIndex['${y.$2}|${y.$1}']!));

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
          await bm.unbookmarkArtist(e.$2, e.$1);
          // 4. Add src bookmarks with new groupid
          await bm.insertArtist(
              e.$2, e.$1, DateTime.now(), groups[choose].id());
        }

        // 5. Update UI
        setState(() {
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          setState(() {
            checkMode = false;
          });
        });
        await refresh();
        setState(() {});
      }
    } else {}
  }
}
