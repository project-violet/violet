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

class RecordViewPage extends StatelessWidget {
  const RecordViewPage({super.key});

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
      future: User.getInstance()
          .then((value) => value.getUserLog().then((value) async {
                var overap = HashSet<String>();
                var rr = <ArticleReadLog>[];

                for (var element in value) {
                  if (overap.contains(element.articleId())) continue;
                  rr.add(element);
                  overap.add(element.articleId());
                }

                return await QueryManager.queryIds(
                    rr.map((e) => e.articleId()).toList());
              })),
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
                        key: Key('record/${e.id()}'),
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
        //       ListView.builder(
        // itemCount: .length,
        // itemBuilder: (context, index) {
        //   var xx = snapshot.data[index];
        //   return SizedBox(
        //     height: 159,
        //     child: Padding(
        //       padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
        //       child: FutureBuilder(
        //         // future: QueryManager.query(
        //         //     "SELECT * FROM HitomiColumnModel WHERE Id=${snapshot.data[index].articleId()}"),
        //         future:
        //             HentaiManager.idSearch(snapshot.data[index].articleId()),
        //         builder: (context,
        //             AsyncSnapshot<Tuple2<List<QueryResult>, int>> snapshot) {
        //           return Column(
        //             crossAxisAlignment: CrossAxisAlignment.stretch,
        //             children: <Widget>[
        //               snapshot.hasData
        //                   ? Provider<ArticleListItem>.value(
        //                       value: ArticleListItem.fromArticleListItem(
        //                         queryResult: snapshot.data.item1[0],
        //                         addBottomPadding: false,
        //                         width: (width - 16),
        //                         thumbnailTag: Uuid().v4(),
        //                       ),
        //                       child: ArticleListItemVerySimpleWidget(),
        //                     )
        //                   : Container();
        // return Column(
        //   crossAxisAlignment: CrossAxisAlignment.stretch,
        //   children: <Widget>[
        //     snapshot.hasData
        //         ? Provider<ArticleListItem>.value(
        //             value: ArticleListItem.fromArticleListItem(
        //               queryResult: snapshot.data.item1[0],
        //               showDetail: true,
        //               addBottomPadding: false,
        //               width: (width - 16),
        //               thumbnailTag: Uuid().v4(),
        //             ),
        //             child: ArticleListItemVerySimpleWidget(),
        //           )
        //         : Container(),
        //     Row(
        //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //       // crossAxisAlignment: CrossAxisAlignment,
        //       children: <Widget>[
        //         // Flexible(
        //         //     child: Text(
        //         //         ' ' +
        //         //             unescape.convert(snapshot.hasData
        //         //                 ? snapshot.data.results[0].title()
        //         //                 : ''),
        //         //         style: TextStyle(fontSize: 17),
        //         //         overflow: TextOverflow.ellipsis)),
        //         Flexible(
        //           // child: Text(xx.datetimeStart().split(' ')[0]),
        //           child: Text(''),
        //         ),
        //         Text(
        //             xx.lastPage().toString() +
        //                 ' ${Translations.of(context).trans('readpage')} ',
        //             style: TextStyle(
        //               color: Settings.themeWhat
        //                   ? Colors.grey.shade300
        //                   : Colors.grey.shade700,
        //             )),
        //       ],
        //     ),
        //   ],
        // );
        //       },
        //     ),
        //   ),
        // );
        // return ListTile() Text(snapshot.data[index].articleId().toString());
      },
      //   );
      // },
    );
  }
}
