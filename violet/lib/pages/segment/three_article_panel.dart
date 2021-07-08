// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class ThreeArticlePanel extends StatelessWidget {
  final Widget tappedRoute;
  final String title;
  final String count;
  final List<QueryResult> articles;

  ThreeArticlePanel({this.tappedRoute, this.title, this.count, this.articles});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onTap(context),
      child: SizedBox(
        height: 195,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(title, style: TextStyle(fontSize: 17)),
                  Text(
                    count,
                    style: TextStyle(
                      color: Settings.themeWhat
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 162,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _subItem(context, 0),
                    _subItem(context, 1),
                    _subItem(context, 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _subItem(context, index) {
    var windowWidth = MediaQuery.of(context).size.width;
    return Expanded(
      flex: 1,
      child: articles.length > index
          ? Padding(
              padding: EdgeInsets.all(4),
              child: Provider<ArticleListItem>.value(
                value: ArticleListItem.fromArticleListItem(
                  queryResult: articles[index],
                  showDetail: false,
                  addBottomPadding: false,
                  width: (windowWidth - 16 - 4.0 - 1.0) / 3,
                  thumbnailTag: Uuid().v4(),
                  disableFilter: true,
                  usableTabList: articles,
                ),
                child: ArticleListItemVerySimpleWidget(),
              ),
            )
          : Container(),
    );
  }

  _onTap(context) {
    if (!Platform.isIOS) {
      Navigator.of(context).push(PageRouteBuilder(
        // opaque: false,
        transitionDuration: Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.ease;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        pageBuilder: (_, __, ___) => tappedRoute,
      ));
    } else {
      Navigator.of(context)
          .push(CupertinoPageRoute(builder: (_) => tappedRoute));
    }
  }
}
