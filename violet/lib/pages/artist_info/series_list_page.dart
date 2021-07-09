// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:violet/database/query.dart';
import 'package:violet/pages/artist_info/article_list_page.dart';
import 'package:violet/pages/segment/three_article_panel.dart';
import 'package:violet/settings/settings.dart';

class SeriesListPage extends StatelessWidget {
  final String prefix;
  final List<List<int>> series;
  final List<QueryResult> cc;

  SeriesListPage({this.prefix, this.series, this.cc});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    var unescape = HtmlUnescape();
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

                      return ThreeArticlePanel(
                        tappedRoute: ArticleListPage(
                            cc: e.map((e) => cc[e]).toList(), name: 'Series'),
                        title: ' ${unescape.convert(cc[e[0]].title())}',
                        count: '${e.length} ',
                        articles: e.map((e) => cc[e]).toList(),
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
