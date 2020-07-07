// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:auto_animated/auto_animated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/artist_info_page.dart';
import 'package:violet/pages/search_page.dart';
import 'package:violet/settings.dart';
import 'package:violet/user.dart';
import 'package:violet/widgets/article_list_item_widget.dart';
import 'package:violet/widgets/floating_button.dart';
import 'package:path_provider/path_provider.dart';

class BookmarkPage extends StatefulWidget {
  @override
  _BookmarkPageState createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage>
    with AutomaticKeepAliveClientMixin<BookmarkPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: FutureBuilder(
        // key: key,
        future: Bookmark.getInstance().then((value) => value.getGroup()),
        builder: (context, AsyncSnapshot<List<BookmarkGroup>> snapshot) {
          if (!snapshot.hasData) return Container();
          return ListView.builder(
              padding: EdgeInsets.fromLTRB(4, statusBarHeight + 8, 4, 8),
              physics: BouncingScrollPhysics(),
              // controller: _scrollController,
              itemCount: snapshot.data.length + 1,
              itemBuilder: (BuildContext ctxt, int index) {
                index -= 1;

                String name;
                String oname = '';
                String desc;
                String date = '';
                int id;

                if (index == -1) {
                  name = Translations.of(context).trans('readrecord');
                  desc = Translations.of(context).trans('readrecorddesc');
                  id = -1;
                } else {
                  name = snapshot.data[index].name();
                  oname = name;
                  desc = snapshot.data[index].description();
                  date = snapshot.data[index].datetime().split(' ')[0];
                  id = snapshot.data[index].id();
                }

                if (name == 'violet_default') {
                  name = Translations.of(context).trans('unclassified');
                  desc = Translations.of(context).trans('unclassifieddesc');
                }

                return new Card(
                    elevation: 8.0,
                    child: ListTile(
                      onTap: () {
                        Navigator.of(context).push(PageRouteBuilder(
                            opaque: false,
                            transitionDuration: Duration(milliseconds: 500),
                            // transitionsBuilder: (BuildContext context,
                            //     Animation<double> animation,
                            //     Animation<double> secondaryAnimation,
                            //     Widget wi) {
                            //   // return wi;
                            //   return new FadeTransition(opacity: animation, child: wi);
                            // },
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
                            pageBuilder: (_, __, ___) => id == -1
                                ? RecordViewPage()
                                : GroupArticleListPage(
                                    groupId: id, name: name)));
                      },
                      onLongPress: () async {
                        if (index == -1 || oname == 'violet_default')
                          await Dialogs.okDialog(
                              context,
                              Translations.of(context)
                                  .trans('cannotmodifydefaultgroup'),
                              Translations.of(context).trans('bookmark'));
                        else {
                          var rr = await showDialog(
                            context: context,
                            child: GroupModifyPage(
                                name: name,
                                desc: snapshot.data[index].description()),
                          );

                          if (rr[0] == 2) {
                            await (await Bookmark.getInstance())
                                .deleteGroup(snapshot.data[index]);
                            setState(() {});
                          } else if (rr[0] == 1) {
                            var nname = rr[1] as String;
                            var ndesc = rr[2] as String;

                            var rrt = Map<String, dynamic>.from(
                                snapshot.data[index].result);

                            rrt['Name'] = nname;
                            rrt['Description'] = ndesc;

                            await (await Bookmark.getInstance())
                                .modfiyGroup(BookmarkGroup(result: rrt));
                            setState(() {});
                          }
                        }
                        // Navigator.of(context).push(PageRouteBuilder(
                        //     opaque: false,
                        //     transitionDuration: Duration(milliseconds: 500),
                        //     transitionsBuilder: (BuildContext context,
                        //         Animation<double> animation,
                        //         Animation<double> secondaryAnimation,
                        //         Widget wi) {
                        //       // return wi;
                        //       return new FadeTransition(
                        //           opacity: animation, child: wi);
                        //     },
                        //     pageBuilder: (_, __, ___) => GroupModifyPage()));
                      },
                      title: Text(name, style: TextStyle(fontSize: 16.0)),
                      subtitle: Text(desc),
                      trailing: Text(date),
                    ));
              });
        },
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.,
      floatingActionButton: SpeedDial(
        marginRight: 18,
        marginBottom: 20,
        animatedIcon: AnimatedIcons.menu_close,
        animatedIconTheme: IconThemeData(size: 22.0),
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.transparent,
        overlayOpacity: 0.2,
        // tooltip: 'Speed Dial',
        heroTag: 'speed-dial-hero-tag',
        backgroundColor:
            Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
        foregroundColor: Settings.majorColor,
        elevation: 1.0,
        shape: CircleBorder(),
        children: [
          // SpeedDialChild(
          //     child: Icon(MdiIcons.frequentlyAskedQuestions,
          //         color: Settings.majorColor),
          //     backgroundColor:
          //         Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
          //     label: '주의사항',
          //     labelStyle: TextStyle(
          //       fontSize: 14.0,
          //       color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
          //     ),
          //     labelBackgroundColor:
          //         Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
          //     onTap: () async {
          //       Dialogs.okDialog(
          //           context,
          //           '1. 모든 작품/작가는 하나의 그룹만 가질 수 있습니다.\n2. 그룹은 또 다른 그룹을 가질 수 없습니다.',
          //           Translations.of(context).trans('bookmark'));
          //     }),

          // TODO: 북마크 필터링 순서 바꾸기 구현
          // SpeedDialChild(
          //   child: Icon(MdiIcons.filter, color: Settings.majorColor),
          //   backgroundColor:
          //       Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
          //   label: Translations.of(context).trans('filtering'),
          //   labelStyle: TextStyle(
          //     fontSize: 14.0,
          //     color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
          //   ),
          //   labelBackgroundColor:
          //       Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
          //   onTap: () => print('SECOND CHILD'),
          // ),
          // SpeedDialChild(
          //   child: Icon(MdiIcons.orderNumericAscending,
          //       color: Settings.majorColor),
          //   backgroundColor:
          //       Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
          //   label: Translations.of(context).trans('editorder'),
          //   labelStyle: TextStyle(
          //     fontSize: 14.0,
          //     color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
          //   ),
          //   labelBackgroundColor:
          //       Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
          //   onTap: () => print('SECOND CHILD'),
          // ),
          SpeedDialChild(
            child: Icon(MdiIcons.group, color: Settings.majorColor),
            backgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            label: Translations.of(context).trans('newgroup'),
            labelStyle: TextStyle(
              fontSize: 14.0,
              color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
            ),
            labelBackgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            onTap: () async {
              (await Bookmark.getInstance()).createGroup(
                  Translations.of(context).trans('newgroup'),
                  Translations.of(context).trans('newgroup'),
                  Colors.orange,
                  1);
              setState(() {});
            },
          ),
        ],
      ),
    );
    // \Visibility(
    //     visible: true,
    //     child: FloatingActionButton(
    //         backgroundColor:
    //             Settings.themeWhat ? Colors.black : Colors.white,
    //         child: Icon(
    //           MdiIcons.pencil,
    //           color: Settings.majorColor,
    //         ),
    //         onPressed: () {})));
  }
}

class GroupModifyPage extends StatelessWidget {
  TextEditingController nameController;
  TextEditingController descController;

  final String name;
  final String desc;

  GroupModifyPage({this.name, this.desc}) {
    nameController = TextEditingController(text: name);
    descController = TextEditingController(text: desc);
  }

  @override
  Widget build(BuildContext context) {
    // return Container(
    //     // color: Colors.transparent,
    //     child: Center(child: SizedBox(height: 100, width: 100, child: Card())));
    return AlertDialog(
      title: Text(Translations.of(context).trans('modifygroupinfo')),
      // insetPadding: EdgeInsets.all(4),
      contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      // contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      // content: Stack(
      //   overflow: Overflow.visible,
      //   alignment: Alignment.center,
      //   children: <Widget>[Text('asdf')],
      // ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(children: [
            Text('${Translations.of(context).trans('name')}: '),
            Expanded(
              child: TextField(
                controller: nameController,
              ),
            ),
          ]),
          Row(children: [
            Text('${Translations.of(context).trans('desc')}: '),
            Expanded(
              child: TextField(
                controller: descController,
              ),
            ),
          ]),
          Container(
            height: 16,
          ),
          // Expanded(
          //   child: Container(),
          // ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ButtonTheme(
                    minWidth: 50,
                    child: RaisedButton(
                      color: Colors.red,
                      child: new Text(Translations.of(context).trans('delete')),
                      onPressed: () async {
                        if (await Dialogs.yesnoDialog(
                            context,
                            Translations.of(context).trans('deletegroupmsg'),
                            Translations.of(context).trans('bookmark')))
                          Navigator.pop(context, [2]);
                      },
                    ),
                  ),
                ),
              ),
              ButtonTheme(
                minWidth: 50,
                child: RaisedButton(
                  color: Settings.majorColor,
                  child: new Text(Translations.of(context).trans('ok')),
                  onPressed: () {
                    Navigator.pop(context, [
                      1,
                      nameController.text,
                      descController.text,
                    ]);
                  },
                ),
              ),
              Container(
                width: 8,
              ),
              ButtonTheme(
                minWidth: 50,
                child: RaisedButton(
                  color: Settings.majorColor,
                  child: new Text(Translations.of(context).trans('cancel')),
                  onPressed: () {
                    Navigator.pop(context, [0]);
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class RecordViewPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
                height: height - 16,
                child: Container(child: future(width)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget future(double width) {
    return FutureBuilder(
      future:
          User.getInstance().then((value) => value.getUserLog().then((value) {
                var overap = HashSet<String>();
                var rr = List<ArticleReadLog>();
                value.forEach((element) {
                  if (overap.contains(element.articleId())) return;
                  rr.add(element);
                  overap.add(element.articleId());
                });
                return rr;
              })),
      builder: (context, AsyncSnapshot<List<ArticleReadLog>> snapshot) {
        if (!snapshot.hasData) return Container();
        return ListView.builder(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.all(0),
          itemCount: snapshot.data.length,
          itemBuilder: (context, index) {
            var xx = snapshot.data[index];
            return SizedBox(
              height: 159,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: FutureBuilder(
                  future: QueryManager.query(
                      "SELECT * FROM HitomiColumnModel WHERE Id=${snapshot.data[index].articleId()}"),
                  builder: (context, AsyncSnapshot<QueryManager> snapshot) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        snapshot.hasData
                            ? ArticleListItemVerySimpleWidget(
                                queryResult: snapshot.data.results[0],
                                showDetail: true,
                                addBottomPadding: false,
                                width: (width - 16),
                                thumbnailTag: Uuid().v4(),
                              )
                            : Container(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          // crossAxisAlignment: CrossAxisAlignment,
                          children: <Widget>[
                            // Flexible(
                            //     child: Text(
                            //         ' ' +
                            //             unescape.convert(snapshot.hasData
                            //                 ? snapshot.data.results[0].title()
                            //                 : ''),
                            //         style: TextStyle(fontSize: 17),
                            //         overflow: TextOverflow.ellipsis)),
                            Flexible(
                              // child: Text(xx.datetimeStart().split(' ')[0]),
                              child: Text(''),
                            ),
                            Text(
                                xx.lastPage().toString() +
                                    ' ${Translations.of(context).trans('readpage')} ',
                                style: TextStyle(
                                  color: Settings.themeWhat
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                )),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
            // return ListTile() Text(snapshot.data[index].articleId().toString());
          },
        );
      },
    );
  }
}

class GroupArticleListPage extends StatefulWidget {
  final String name;
  final int groupId;
  String heroKey;

  GroupArticleListPage({this.name, this.groupId}) {
    heroKey = Uuid().v4.toString();
  }

  @override
  _GroupArticleListPageState createState() => _GroupArticleListPageState();
}

class _GroupArticleListPageState extends State<GroupArticleListPage> {
  // List<BookmarkArticle> cc;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    Bookmark.getInstance().then((value) => value.getArticle().then((value) {
          var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
          var cc = value
              .where((e) => e.group() == widget.groupId)
              .toList()
              .reversed
              .toList();
          if (cc.length == 0) {
            queryResult = List<QueryResult>();
            filterResult = queryResult;
            setState(() {});
            return;
          }
          queryRaw += cc.map((e) => 'Id=${e.article()}').join(' OR ');
          QueryManager.query(queryRaw).then((value) {
            var qr = Map<String, QueryResult>();
            value.results.forEach((element) {
              qr[element.id().toString()] = element;
            });

            var result = List<QueryResult>();
            cc.forEach((element) {
              result.add(qr[element.article()]);
            });
            queryResult = result;
            if (isFilterUsed) {
              result.clear();
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
                    if (split[0] == 'female' || split[0] == 'male')
                      tt = split[0] + ':' + split[1];
                    if ((element.result[kk] as String)
                            .contains('|' + tt + '|') ==
                        isOr) succ = isOr;
                  } else if ((element.result[kk] as String == split[1]) == isOr)
                    succ = isOr;
                });
                if (succ) result.add(element);
              });
            }
            filterResult = result;
            setState(() {});
          });
        }));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    // if (similarsAll == null) return Text('asdf');
    return Padding(
      key: key,
      // padding: EdgeInsets.all(0),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
              height: height - 16,
              child: Scaffold(
                floatingActionButton: Visibility(
                  visible: checkMode,
                  child: AnimatedOpacity(
                    opacity: checkModePre ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 500),
                    child: AnimatedFloatingActionButton(
                      fabButtons: <Widget>[
                        Container(
                          child: FloatingActionButton(
                            onPressed: () {
                              filterResult.forEach((element) {
                                checked.add(element.id());
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
                                      .replaceAll(
                                          '%s', checked.length.toString()),
                                  Translations.of(context).trans('bookmark'))) {
                                var bookmark = await Bookmark.getInstance();
                                checked.forEach((element) async {
                                  bookmark.unbookmark(element);
                                });
                                checked.clear();
                                refresh();
                                Future.delayed(Duration(milliseconds: 300))
                                    .then((value) => setState(() {
                                          key = ObjectKey(Uuid().v4());
                                        }));
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
                        Future.delayed(Duration(milliseconds: 500))
                            .then((value) {
                          setState(() {
                            checkMode = false;
                          });
                        });
                      },
                    ),
                  ),
                ),
                // floatingActionButton: Container(child: Text('asdf')),
                body: Container(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: <Widget>[
                        SliverPersistentHeader(
                          floating: true,
                          delegate: SearchBar(
                            minExtent: 64 + 12.0,
                            maxExtent: 64.0 + 12,
                            searchBar: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Stack(children: <Widget>[
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Hero(
                                      tag: "searchtype2",
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
                                        clipBehavior:
                                            Clip.antiAliasWithSaveLayer,
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
                                            if (checkMode) return;
                                            Navigator.of(context)
                                                .push(PageRouteBuilder(
                                              opaque: false,
                                              transitionDuration:
                                                  Duration(milliseconds: 500),
                                              transitionsBuilder: (BuildContext
                                                      context,
                                                  Animation<double> animation,
                                                  Animation<double>
                                                      secondaryAnimation,
                                                  Widget wi) {
                                                return new FadeTransition(
                                                    opacity: animation,
                                                    child: wi);
                                              },
                                              pageBuilder: (_, __, ___) =>
                                                  SearchType2(
                                                nowType: nowType,
                                              ),
                                            ))
                                                .then((value) async {
                                              if (value == null) return;
                                              nowType = value;
                                              await Future.delayed(
                                                  Duration(milliseconds: 50),
                                                  () {
                                                setState(() {});
                                              });
                                            });
                                          },
                                          onLongPress: () {
                                            if (checkMode) return;
                                            Navigator.of(context)
                                                .push(PageRouteBuilder(
                                              // opaque: false,
                                              transitionDuration:
                                                  Duration(milliseconds: 500),
                                              transitionsBuilder: (BuildContext
                                                      context,
                                                  Animation<double> animation,
                                                  Animation<double>
                                                      secondaryAnimation,
                                                  Widget wi) {
                                                return new FadeTransition(
                                                    opacity: animation,
                                                    child: wi);
                                              },
                                              pageBuilder: (_, __, ___) =>
                                                  BookmarkSearchSort(
                                                queryResult: queryResult,
                                                tagStates: tagStates,
                                                groupStates: groupStates,
                                                isOr: isOr,
                                              ),
                                            ))
                                                .then((value) async {
                                              tagStates = value[0];
                                              groupStates = value[1];
                                              isOr = value[2];
                                              var result = List<QueryResult>();
                                              queryResult.forEach((element) {
                                                var succ = !isOr;
                                                tagStates.forEach((key, value) {
                                                  if (!value) return;
                                                  if (succ == isOr) return;
                                                  var split = key.split('|');
                                                  var kk = prefix2Tag(split[0]);
                                                  if (element.result[kk] ==
                                                          null &&
                                                      !isOr) {
                                                    succ = false;
                                                    return;
                                                  }
                                                  if (!isSingleTag(split[0])) {
                                                    var tt = split[1];
                                                    if (split[0] == 'female' ||
                                                        split[0] == 'male')
                                                      tt = split[0] +
                                                          ':' +
                                                          split[1];
                                                    if ((element.result[kk]
                                                                as String)
                                                            .contains('|' +
                                                                tt +
                                                                '|') ==
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
                                              await Future.delayed(
                                                  Duration(milliseconds: 50),
                                                  () {
                                                setState(() {});
                                              });
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(top: 24, left: 12),
                                    child: Text(widget.name,
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ])),
                          ),
                        ),
                        buildList()
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool isFilterUsed = false;
  bool isOr = false;
  Map<String, bool> tagStates = Map<String, bool>();
  Map<String, bool> groupStates = Map<String, bool>();

  bool scaleOnce = false;
  List<QueryResult> queryResult = List<QueryResult>();
  List<QueryResult> filterResult = List<QueryResult>();

  ObjectKey key = ObjectKey(Uuid().v4());

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

  int nowType = 3;

  Widget buildList() {
    var mm = nowType == 0 ? 3 : 2;
    var windowWidth = MediaQuery.of(context).size.width;
    switch (nowType) {
      case 0:
      case 1:
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: LiveSliverGrid(
            key: key,
            showItemInterval: Duration(milliseconds: 50),
            showItemDuration: Duration(milliseconds: 150),
            visibleFraction: 0.001,
            itemCount: filterResult.length,
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
                          queryResult: filterResult[index],
                          showDetail: false,
                          addBottomPadding: false,
                          width: (windowWidth - 4.0) / mm,
                          thumbnailTag: Uuid().v4(),
                          bookmarkMode: true,
                          bookmarkCallback: longpress,
                          bookmarkCheckCallback: check,
                          isCheckMode: checkMode,
                          isChecked: checked.contains(filterResult[index].id()),
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
            key: key,
            itemCount: filterResult.length,
            itemBuilder: (context, index, animation) {
              return Align(
                alignment: Alignment.center,
                child: ArticleListItemVerySimpleWidget(
                  queryResult: filterResult[index],
                  showDetail: nowType == 3,
                  addBottomPadding: true,
                  width: (windowWidth - 4.0),
                  thumbnailTag: Uuid().v4(),
                  bookmarkMode: true,
                  bookmarkCallback: longpress,
                  bookmarkCheckCallback: check,
                  isCheckMode: checkMode,
                  isChecked: checked.contains(filterResult[index].id()),
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

  bool checkMode = false;
  bool checkModePre = false;
  HashSet<int> checked = HashSet<int>();

  void longpress(int article) {
    if (!checkMode) {
      checkMode = true;
      checkModePre = true;
      checked.add(article);
      setState(() {});
    }
  }

  void check(int article, bool check) {
    if (check)
      checked.add(article);
    else {
      checked.remove(article);
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
          await bm.unbookmark(e);
          // 4. Add src bookmarks with new groupid
          await bm.insertArticle(
              e.toString(), DateTime.now(), groups[choose].id());
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
        Future.delayed(Duration(milliseconds: 300))
            .then((value) => setState(() {
                  key = ObjectKey(Uuid().v4());
                }));
      }
    } else {}
  }
}

class BookmarkSearchSort extends StatefulWidget {
  bool isOr;
  List<Tuple3<String, String, int>> tags = List<Tuple3<String, String, int>>();
  Map<String, bool> tagStates = Map<String, bool>();
  Map<String, bool> groupStates = Map<String, bool>();
  Map<String, int> groupCount = Map<String, int>();
  List<Tuple2<String, int>> groups = List<Tuple2<String, int>>();
  final List<QueryResult> queryResult;

  BookmarkSearchSort({
    this.queryResult,
    this.tagStates,
    this.groupStates,
    this.isOr,
  });

  @override
  _BookmarkSearchSortState createState() => _BookmarkSearchSortState();
}

class _BookmarkSearchSortState extends State<BookmarkSearchSort> {
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
              tag: "searchtype2",
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
