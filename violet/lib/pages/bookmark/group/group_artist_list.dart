// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/floating_button.dart';

class GroupArtistList extends StatefulWidget {
  final String name;
  final int groupId;

  GroupArtistList({this.name, this.groupId});

  @override
  _GroupArtistListState createState() => _GroupArtistListState();
}

class _GroupArtistListState extends State<GroupArtistList>
    with AutomaticKeepAliveClientMixin<GroupArtistList> {
  @override
  bool get wantKeepAlive => true;
  List<BookmarkArtist> artists;

  Future<List<BookmarkArtist>> _bookmark() async {
    await refresh();
    return artists;
  }

  Future<List<QueryResult>> _future(String e, int type) async {
    var postfix = e.toLowerCase().replaceAll(' ', '_');
    var queryString = HitomiManager.translate2query(
        '${['artist', 'group', 'uploader', 'series', 'character'][type]}:' +
            postfix);
    final qm = QueryManager.queryPagination(queryString);
    qm.itemsPerPage = 3;
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
    var windowWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      resizeToAvoidBottomPadding: false,
      floatingActionButton: Visibility(
        visible: checkMode,
        child: AnimatedOpacity(
          opacity: checkModePre ? 1.0 : 0.0,
          duration: Duration(milliseconds: 500),
          child: _floatingButton(),
        ),
      ),
      body: FutureBuilder<List<BookmarkArtist>>(
        future: _bookmark(),
        builder: (BuildContext context,
            AsyncSnapshot<List<BookmarkArtist>> snapshot) {
          if (!snapshot.hasData) return Container();
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
            physics: ClampingScrollPhysics(),
            itemCount: artists.length,
            itemBuilder: (BuildContext ctxt, int index) {
              var e = artists[index];
              return FutureBuilder<List<QueryResult>>(
                future: _future(e.artist(), e.type()),
                builder: (BuildContext context,
                    AsyncSnapshot<List<QueryResult>> snapshot) {
                  var qq = snapshot.data;
                  if (!snapshot.hasData)
                    return Container(
                      height: 195,
                    );
                  return Container(
                    color: checkMode &&
                            checked
                                    .where((element) =>
                                        element.item1 == e.type() &&
                                        element.item2 == e.artist())
                                    .length !=
                                0
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
                                          element.item1 == e.type() &&
                                          element.item2 == e.artist())
                                      .length ==
                                  0);
                          setState(() {});
                          return;
                        }

                        if (!Platform.isIOS) {
                          Navigator.of(context).push(PageRouteBuilder(
                            // opaque: false,
                            transitionDuration: Duration(milliseconds: 500),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              var begin = Offset(0.0, 1.0);
                              var end = Offset.zero;
                              var curve = Curves.ease;

                              var tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));

                              return SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              );
                            },
                            pageBuilder: (_, __, ___) => ArtistInfoPage(
                              isGroup: e.type() == 1,
                              isUploader: e.type() == 2,
                              isSeries: e.type() == 3,
                              isCharacter: e.type() == 4,
                              artist: e.artist(),
                            ),
                          ));
                        } else {
                          Navigator.of(context).push(CupertinoPageRoute(
                            builder: (_) => ArtistInfoPage(
                              isGroup: e.type() == 1,
                              isUploader: e.type() == 2,
                              isSeries: e.type() == 3,
                              isCharacter: e.type() == 4,
                              artist: e.artist(),
                            ),
                          ));
                        }
                      },
                      onLongPress: checkMode
                          ? null
                          : () {
                              longpress(e.type(), e.artist());
                            },
                      child: SizedBox(
                        height: 195,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                      ' ${[
                                            'artist',
                                            'group',
                                            'uploader',
                                            'series',
                                            'character'
                                          ][e.type()]}:' +
                                          e.artist() +
                                          ' (' +
                                          HitomiManager.getArticleCount(
                                                  [
                                                    'artist',
                                                    'group',
                                                    'uploader',
                                                    'series',
                                                    'character'
                                                  ][e.type()],
                                                  e.artist())
                                              .toString() +
                                          ')',
                                      style: TextStyle(fontSize: 17)),
                                ],
                              ),
                              SizedBox(
                                height: 162,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    _image(qq, 0, windowWidth),
                                    _image(qq, 1, windowWidth),
                                    _image(qq, 2, windowWidth),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _image(List<QueryResult> qq, int index, double windowWidth) {
    return Expanded(
        flex: 1,
        child: qq.length > index
            ? Padding(
                padding: EdgeInsets.all(4),
                child: Provider<ArticleListItem>.value(
                  value: ArticleListItem.fromArticleListItem(
                    queryResult: qq[index],
                    showDetail: false,
                    addBottomPadding: false,
                    width: (windowWidth - 16 - 4.0 - 16.0) / 3,
                    thumbnailTag: Uuid().v4(),
                  ),
                  child: ArticleListItemVerySimpleWidget(),
                ),
              )
            : Container());
  }

  Widget _floatingButton() {
    return AnimatedFloatingActionButton(
      fabButtons: <Widget>[
        Container(
          child: FloatingActionButton(
            onPressed: () {
              artists.forEach((element) {
                checked
                    .add(Tuple2<int, String>(element.type(), element.artist()));
              });
              setState(() {});
            },
            elevation: 4,
            heroTag: 'a',
            child: Icon(MdiIcons.checkAll),
          ),
        ),
        Container(
          child: FloatingActionButton(
            onPressed: () async {
              if (await Dialogs.yesnoDialog(
                  context,
                  Translations.of(context)
                      .trans('deletebookmarkmsg')
                      .replaceAll('%s', checked.length.toString()),
                  Translations.of(context).trans('bookmark'))) {
                var bookmark = await Bookmark.getInstance();
                checked.forEach((element) async {
                  bookmark.unbookmarkArtist(element.item2, element.item1);
                });
                checked.clear();
                refresh();
                setState(() {
                  checkModePre = false;
                  checked.clear();
                });
                Future.delayed(Duration(milliseconds: 500)).then((value) {
                  setState(() {
                    checkMode = false;
                  });
                });
              }
            },
            elevation: 4,
            heroTag: 'b',
            child: Icon(MdiIcons.delete),
          ),
        ),
        Container(
          child: FloatingActionButton(
            onPressed: moveChecked,
            elevation: 4,
            heroTag: 'c',
            child: Icon(MdiIcons.folderMove),
          ),
        ),
      ],
      animatedIconData: AnimatedIcons.menu_close,
      exitCallback: () {
        setState(() {
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(Duration(milliseconds: 500)).then((value) {
          setState(() {
            checkMode = false;
          });
        });
      },
    );
  }

  bool checkMode = false;
  bool checkModePre = false;
  List<Tuple2<int, String>> checked = List<Tuple2<int, String>>();

  void longpress(int type, String artist) {
    if (!checkMode) {
      checkMode = true;
      checkModePre = true;
      checked.add(Tuple2<int, String>(type, artist));
      setState(() {});
    }
  }

  void check(int type, String artist, bool check) {
    if (check)
      checked.add(Tuple2<int, String>(type, artist));
    else {
      checked.removeWhere(
          (element) => element.item1 == type && element.item2 == artist);
      if (checked.length == 0) {
        setState(() {
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(Duration(milliseconds: 500)).then((value) {
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
    if (await showDialog(
            context: context,
            child: AlertDialog(
              title: Text(Translations.of(context).trans('wheretomove')),
              actions: <Widget>[
                RaisedButton(
                  color: Settings.majorColor,
                  child: new Text(Translations.of(context).trans('cancel')),
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
      if (await Dialogs.yesnoDialog(
          context,
          Translations.of(context)
              .trans('movetoto')
              .replaceAll('%1', groups[choose].name())
              .replaceAll('%2', checked.length.toString()),
          Translations.of(context).trans('movebookmark'))) {
        // There is a way to change only the group, but there is also re-register a new bookmark.
        // I chose the latter to suit the user's intentions.

        // Atomic!!

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

        for (var e in checked) {
          // 3. Delete source bookmarks
          await bm.unbookmarkArtist(e.item2, e.item1);
          // 4. Add src bookmarks with new groupid
          await bm.insertArtist(
              e.item2, e.item1, DateTime.now(), groups[choose].id());
        }

        // 5. Update UI
        setState(() {
          checkModePre = false;
          checked.clear();
        });
        Future.delayed(Duration(milliseconds: 500)).then((value) {
          setState(() {
            checkMode = false;
          });
        });
        refresh();
      }
    } else {}
  }
}
