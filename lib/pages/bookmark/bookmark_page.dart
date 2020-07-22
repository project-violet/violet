// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/bookmark/group/group_article_list_page.dart';
import 'package:violet/pages/bookmark/group_modify.dart';
import 'package:violet/pages/bookmark/record_view_page.dart';
import 'package:violet/settings.dart';

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
