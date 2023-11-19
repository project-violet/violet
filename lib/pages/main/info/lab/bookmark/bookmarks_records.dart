// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabRecordViewPage extends StatelessWidget {
  final List<dynamic> records;

  const LabRecordViewPage({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return CardPanel.build(
      context,
      child: future(context, width),
      enableBackgroundColor: true,
    );
  }

  Widget future(context, double width) {
    var windowWidth = MediaQuery.of(context).size.width;
    return FutureBuilder(
      future:
          Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        var overap = HashSet<String>();
        var rr = <ArticleReadLog>[];

        records.map((x) => ArticleReadLog(result: x)).forEach((element) {
          if (overap.contains(element.articleId())) return;
          rr.add(element);
          overap.add(element.articleId());
        });

        return await QueryManager.queryIds(
            rr.map((e) => e.articleId()).toList());
      }),
      builder: (context, AsyncSnapshot<List<QueryResult>> snapshot) {
        if (!snapshot.hasData) return Container();
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3 / 4,
                ),
                delegate: SliverChildListDelegate(
                  snapshot.data!.map(
                    (e) {
                      return Padding(
                        key: Key('lab_record/${e.id()}'),
                        padding: EdgeInsets.zero,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              snapshot.hasData
                                  ? Provider<ArticleListItem>.value(
                                      value:
                                          ArticleListItem.fromArticleListItem(
                                        queryResult: e,
                                        addBottomPadding: false,
                                        showDetail: false,
                                        width: (windowWidth - 4.0 - 48) / 3,
                                        thumbnailTag: const Uuid().v4(),
                                        usableTabList: snapshot.data,
                                      ),
                                      child: const ArticleListItemWidget(),
                                    )
                                  : Container()
                            ],
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
