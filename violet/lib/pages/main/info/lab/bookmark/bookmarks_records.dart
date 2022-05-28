// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabRecordViewPage extends StatelessWidget {
  final List<dynamic> records;

  const LabRecordViewPage({Key? key, required this.records}) : super(key: key);

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
      future: Future.delayed(Duration(milliseconds: 100)).then((value) async {
        var overap = HashSet<String>();
        var rr = <ArticleReadLog>[];

        records.map((x) => ArticleReadLog(result: x)).forEach((element) {
          if (overap.contains(element.articleId())) return;
          rr.add(element);
          overap.add(element.articleId());
        });

        var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
        queryRaw += 'Id IN (${rr.map((e) => e.articleId()).join(',')})';
        var qm = await QueryManager.query(
            queryRaw + (!Settings.searchPure ? ' AND ExistOnHitomi=1' : ''));

        var qr = Map<String, QueryResult>();
        qm.results!.forEach((element) {
          qr[element.id().toString()] = element;
        });

        return rr
            .where((e) => qr.containsKey(e.articleId()))
            .map((e) => qr[e.articleId()]!)
            .toList();
      }),
      builder: (context, AsyncSnapshot<List<QueryResult>> snapshot) {
        if (!snapshot.hasData) return Container();
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
                                        thumbnailTag: Uuid().v4(),
                                        usableTabList: snapshot.data,
                                      ),
                                      child: ArticleListItemVerySimpleWidget(),
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
