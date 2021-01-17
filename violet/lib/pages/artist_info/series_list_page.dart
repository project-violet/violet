// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class SeriesListPage extends StatelessWidget {
  final String prefix;
  final List<List<int>> series;
  final List<QueryResult> cc;

  SeriesListPage({this.prefix, this.series, this.cc}) {}

  @override
  Widget build(BuildContext context) {
    var windowWidth = MediaQuery.of(context).size.width;
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    var unescape = new HtmlUnescape();
    // // if (similarsAll == null) return Text('asdf');
    // return Padding(
    //   // padding: EdgeInsets.all(0),
    //   padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
    //   child: Column(
    //       mainAxisAlignment: MainAxisAlignment.center,
    //       crossAxisAlignment: CrossAxisAlignment.center,
    //       children: <Widget>[
    //         Card(
    //           elevation: 5,
    //           color:
    //               Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
    //           child: SizedBox(
    //             width: width - 16,
    //             height: height - 16,

    final mediaQuery = MediaQuery.of(context);
    // if (similarsAll == null) return Text('asdf');
    return Padding(
      // padding: EdgeInsets.all(0),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
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
                height: height -
                    16 -
                    (mediaQuery.padding + mediaQuery.viewInsets).bottom,
                child: Container(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
                    physics: ClampingScrollPhysics(),
                    itemCount: series.length,
                    itemBuilder: (BuildContext ctxt, int index) {
                      var e = series[index];
                      return InkWell(
                        onTap: () async {
                          // Navigator.of(context).push(PageRouteBuilder(
                          //   // opaque: false,
                          //   transitionDuration: Duration(milliseconds: 500),
                          //   transitionsBuilder: (context, animation,
                          //       secondaryAnimation, child) {
                          //     var begin = Offset(0.0, 1.0);
                          //     var end = Offset.zero;
                          //     var curve = Curves.ease;

                          //     var tween = Tween(begin: begin, end: end)
                          //         .chain(CurveTween(curve: curve));

                          //     return SlideTransition(
                          //       position: animation.drive(tween),
                          //       child: child,
                          //     );
                          //   },
                          //   pageBuilder: (_, __, ___) => ArtistInfoPage(
                          //     isGroup: isGroup,
                          //     isUploader: isUploader,
                          //     artist: e.item1,
                          //   ),
                          // ));
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
                                  // crossAxisAlignment: CrossAxisAlignment,
                                  children: <Widget>[
                                    Flexible(
                                        child: Text(
                                            // (index + 1).toString() +
                                            //     '. ' +
                                            ' ' +
                                                unescape
                                                    .convert(cc[e[0]].title()),
                                            style: TextStyle(fontSize: 17),
                                            overflow: TextOverflow.ellipsis)),
                                    Text(e.length.toString() + ' ',
                                        style: TextStyle(
                                          color: Settings.themeWhat
                                              ? Colors.grey.shade300
                                              : Colors.grey.shade700,
                                        )),
                                  ],
                                ),
                                // Text(' ' + unescape.convert(cc[e[0]].title()),
                                //         style: TextStyle(fontSize: 17), overflow: TextOverflow.ellipsis,),
                                SizedBox(
                                  height: 162,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Expanded(
                                          flex: 1,
                                          child: e.length > 0
                                              ? Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Provider<
                                                      ArticleListItem>.value(
                                                    value: ArticleListItem
                                                        .fromArticleListItem(
                                                      queryResult: cc[e[0]],
                                                      showDetail: false,
                                                      addBottomPadding: false,
                                                      width: (windowWidth -
                                                              16 -
                                                              4.0 -
                                                              1.0) /
                                                          3,
                                                      thumbnailTag: Uuid().v4(),
                                                    ),
                                                    child:
                                                        ArticleListItemVerySimpleWidget(),
                                                  ),
                                                )
                                              : Container()),
                                      Expanded(
                                          flex: 1,
                                          child: e.length > 1
                                              ? Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Provider<
                                                      ArticleListItem>.value(
                                                    value: ArticleListItem
                                                        .fromArticleListItem(
                                                      queryResult: cc[e[1]],
                                                      showDetail: false,
                                                      addBottomPadding: false,
                                                      width: (windowWidth -
                                                              16 -
                                                              4.0 -
                                                              1.0) /
                                                          3,
                                                      thumbnailTag: Uuid().v4(),
                                                    ),
                                                    child:
                                                        ArticleListItemVerySimpleWidget(),
                                                  ),
                                                )
                                              : Container()),
                                      Expanded(
                                          flex: 1,
                                          child: e.length > 2
                                              ? Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Provider<
                                                      ArticleListItem>.value(
                                                    value: ArticleListItem
                                                        .fromArticleListItem(
                                                      queryResult: cc[e[1]],
                                                      showDetail: false,
                                                      addBottomPadding: false,
                                                      width: (windowWidth -
                                                              16 -
                                                              4.0 -
                                                              1.0) /
                                                          3,
                                                      thumbnailTag: Uuid().v4(),
                                                    ),
                                                    child:
                                                        ArticleListItemVerySimpleWidget(),
                                                  ),
                                                )
                                              : Container()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ]),
    );
  }
}
