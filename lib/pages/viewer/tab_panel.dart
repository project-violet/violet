// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class TabPanel extends StatefulWidget {
  final int articleId;
  final List<QueryResult> usableTabList;

  TabPanel({
    this.articleId,
    this.usableTabList,
  });

  @override
  _TabPanelState createState() => _TabPanelState();
}

class _TabPanelState extends State<TabPanel> {
  ScrollController _scrollController = ScrollController();
  // static const _kDuration = const Duration(milliseconds: 300);
  // static const _kCurve = Curves.ease;
  Map<int, GlobalKey> itemKeys = Map<int, GlobalKey>();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    if (widget.usableTabList == null) return;

    widget.usableTabList
        .forEach((element) => itemKeys[element.id()] = GlobalKey());

    Future.value(1).then((value) {
      var row = widget.usableTabList
              .indexWhere((element) => element.id() == widget.articleId) ~/
          3;
      if (row == 0) return;
      _scrollController.jumpTo(
        row *
                ((itemKeys[widget.usableTabList.first.id()]
                            .currentContext
                            .findRenderObject() as RenderBox)
                        .size
                        .height +
                    8) -
            100,
        // duration: _kDuration,
        // curve: _kCurve
      );
    });
    // Scrollable.ensureVisible(itemKeys[widget.articleId].currentContext,
    //     duration: _kDuration, curve: _kCurve, alignment: 0.5));
  }

  @override
  Widget build(BuildContext context) {
    var windowWidth = MediaQuery.of(context).size.width;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
          padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            controller: _scrollController,
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3 / 4,
                  ),
                  delegate: SliverChildListDelegate(
                    widget.usableTabList.map(
                      (e) {
                        return Padding(
                          key: itemKeys[e.id()],
                          padding: EdgeInsets.zero,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Provider<ArticleListItem>.value(
                              value: ArticleListItem.fromArticleListItem(
                                queryResult: e,
                                addBottomPadding: false,
                                showDetail: false,
                                width: (windowWidth - 4.0) / 3.0,
                                thumbnailTag: Uuid().v4(),
                                selectMode: true,
                                selectCallback: () {
                                  Navigator.pop(context, e);
                                },
                              ),
                              child: ArticleListItemVerySimpleWidget(),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
