// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/search_bar.dart';

class GroupArtistArticleList extends StatefulWidget {
  final String name;
  final int groupId;

  GroupArtistArticleList({
    required this.name,
    required this.groupId,
  });

  @override
  _GroupArtistArticleListState createState() => _GroupArtistArticleListState();
}

class _GroupArtistArticleListState extends State<GroupArtistArticleList>
    with AutomaticKeepAliveClientMixin<GroupArtistArticleList> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var windowWidth = MediaQuery.of(context).size.width;
    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: 1)).then((value) async {
        var artists = (await (await Bookmark.getInstance()).getArtist())
            .where((element) => element.group() == widget.groupId)
            .toList()
            .reversed
            .toList();

        if (artists.length == 0) return <QueryResult>[];

        var queryString = HitomiManager.translate2query(artists
            .map((e) =>
                '${[
                  'artist',
                  'group',
                  'uploader',
                  'series',
                  'character'
                ][e.type()]}:' +
                e.artist().toLowerCase().replaceAll(' ', '_') +
                ' ' +
                Settings.includeTags)
            .join(' or '));
        print(queryString);
        final qm = QueryManager.queryPagination(queryString);
        qm.itemsPerPage = 100;
        return await qm.next();
      }),
      builder: (context, AsyncSnapshot<List<QueryResult>> snapshot) {
        if (!snapshot.hasData)
          return Align(
              alignment: Alignment.center,
              child: SizedBox(
                  width: 64, height: 64, child: CircularProgressIndicator()));
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPersistentHeader(
              floating: true,
              delegate: AnimatedOpacitySliver(
                minExtent: 64 + 12.0,
                maxExtent: 64.0 + 12,
                searchBar: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Stack(children: <Widget>[
                      // _filter(),
                      _title(),
                    ])),
              ),
            ),
            SliverPadding(
              // padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
              padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
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
                        key: Key('gaal/' + e.id().toString()),
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
                                        width: (windowWidth - 4.0 - 52) / 3,
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

  Widget _title() {
    return Padding(
      padding: EdgeInsets.only(top: 24, left: 12),
      child: Text('Artists Article Collection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }
}
