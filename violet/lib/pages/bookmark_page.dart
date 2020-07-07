// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:collection';

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
                  name = '열람 기록';
                  desc = '한 번 이상 열람했던 작품/작가들이 기록됩니다.';
                  id = -1;
                } else {
                  name = snapshot.data[index].name();
                  oname = name;
                  desc = snapshot.data[index].description();
                  date = snapshot.data[index].datetime().split(' ')[0];
                  id = snapshot.data[index].id();
                }

                if (name == 'violet_default') {
                  name = '미분류';
                  desc = '분류가 없는 북마크';
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
                              context, '기본 그룹은 수정할 수 없습니다.', '북마크');
                        else {
                          var rr = await showDialog(
                            context: context,
                            child: GroupModifyPage(),
                          );

                          if (rr == 2) {
                            (await Bookmark.getInstance())
                                .deleteGroup(snapshot.data[index]);
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
          SpeedDialChild(
            child: Icon(MdiIcons.filter, color: Settings.majorColor),
            backgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            label: '필터링',
            labelStyle: TextStyle(
              fontSize: 14.0,
              color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
            ),
            labelBackgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            onTap: () => print('SECOND CHILD'),
          ),
          SpeedDialChild(
            child: Icon(MdiIcons.orderNumericAscending,
                color: Settings.majorColor),
            backgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            label: '순서 편집',
            labelStyle: TextStyle(
              fontSize: 14.0,
              color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
            ),
            labelBackgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            onTap: () => print('SECOND CHILD'),
          ),
          SpeedDialChild(
            child: Icon(MdiIcons.group, color: Settings.majorColor),
            backgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            label: '새로운 그룹',
            labelStyle: TextStyle(
              fontSize: 14.0,
              color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
            ),
            labelBackgroundColor:
                Settings.themeWhat ? Colors.grey.shade800 : Colors.white,
            onTap: () async {
              (await Bookmark.getInstance())
                  .createGroup('새로운 그룹', '새로운 그룹', Colors.orange, 1);
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
  @override
  Widget build(BuildContext context) {
    // return Container(
    //     // color: Colors.transparent,
    //     child: Center(child: SizedBox(height: 100, width: 100, child: Card())));
    return AlertDialog(
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
                      child: new Text('삭제'),
                      onPressed: () async {
                        if (await Dialogs.yesnoDialog(
                            context,
                            '삭제된 그룹은 복구할 수 없습니다. 정말로 이 그룹을 삭제하시겠습니까?',
                            '북마크')) Navigator.pop(context, 2);
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
                    Navigator.pop(context, 1);
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
                    Navigator.pop(context, 0);
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
                            Text(xx.lastPage().toString() + ' Page까지 읽음 ',
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
  List<BookmarkArticle> cc;

  @override
  void initState() {
    super.initState();
    Bookmark.getInstance().then((value) => value.getArticle().then((value) {
          var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
          cc = value.where((e) => e.group() == widget.groupId).toList();
          queryRaw += cc.map((e) => 'Id=${e.article()}').join(' OR ');
          QueryManager.query(queryRaw).then((value) {
            queryResult = value.results;
            filterResult = queryResult;
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
              child: Container(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 16),
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
                                                SearchType2(
                                              nowType: nowType,
                                            ),
                                          ))
                                              .then((value) async {
                                            if (value == null) return;
                                            nowType = value;
                                            await Future.delayed(
                                                Duration(milliseconds: 50), () {
                                              setState(() {});
                                            });
                                          });
                                        },
                                        onLongPress: () {
                                          Navigator.of(context)
                                              .push(PageRouteBuilder(
                                            // opaque: false,
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
                                                          .contains(
                                                              '|' + tt + '|') ==
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
                                                Duration(milliseconds: 50), () {
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
                                label: Text("모두 선택"),
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
                                label: Text("모두 선택 해제"),
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
                                label: Text("선택 반전"),
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
