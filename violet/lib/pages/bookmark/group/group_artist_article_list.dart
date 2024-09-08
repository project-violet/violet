// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/debounce_widget.dart';
import 'package:violet/widgets/search_bar.dart';

class GroupArtistArticleList extends StatefulWidget {
  final String name;
  final int groupId;

  const GroupArtistArticleList({
    super.key,
    required this.name,
    required this.groupId,
  });

  @override
  State<GroupArtistArticleList> createState() => _GroupArtistArticleListState();
}

class _GroupArtistArticleListState extends State<GroupArtistArticleList>
    with AutomaticKeepAliveClientMixin<GroupArtistArticleList> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final windowWidth = MediaQuery.of(context).size.width;
    final columnCount =
        MediaQuery.of(context).orientation == Orientation.landscape ? 4 : 3;
    return FutureBuilder(
      future:
          Future.delayed(const Duration(milliseconds: 1)).then((value) async {
        final artists = (await (await Bookmark.getInstance()).getArtist())
            .where((element) => element.group() == widget.groupId)
            .toList()
            .reversed
            .toList();

        if (artists.isEmpty) return <QueryResult>[];

        final queryString = HitomiManager.translate2query(artists
            .map((e) =>
                '${e.type().name}:${e.artist().toLowerCase().replaceAll(' ', '_')} ${Settings.includeTags}')
            .join(' or '));

        final qm = QueryManager.queryPagination(queryString);
        qm.itemsPerPage = 100;
        return await qm.next();
      }),
      builder: (context, AsyncSnapshot<List<QueryResult>> snapshot) {
        if (!snapshot.hasData) {
          return const Align(
              alignment: Alignment.center,
              child: SizedBox(
                  width: 64, height: 64, child: CircularProgressIndicator()));
        }
        return PrimaryScrollController(
          controller: ScrollController(),
          child: CupertinoScrollbar(
            scrollbarOrientation: Settings.bookmarkScrollbarPositionToLeft
                ? ScrollbarOrientation.left
                : ScrollbarOrientation.right,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: <Widget>[
                SliverPersistentHeader(
                  floating: true,
                  delegate: AnimatedOpacitySliver(
                    searchBar: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Stack(children: <Widget>[
                          // _filter(),
                          _title(),
                        ])),
                  ),
                ),
                SliverPadding(
                  // padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3 / 4,
                    ),
                    delegate: SliverChildListDelegate(
                      snapshot.data!.map(
                        (e) {
                          return DebounceWidget(
                            child: Padding(
                              key: Key('gaal/${e.id()}'),
                              padding: EdgeInsets.zero,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    Provider<ArticleListItem>.value(
                                      value:
                                          ArticleListItem.fromArticleListItem(
                                        queryResult: e,
                                        addBottomPadding: false,
                                        showDetail: false,
                                        width: (windowWidth - 4.0 - 52) /
                                            columnCount,
                                        thumbnailTag: const Uuid().v4(),
                                        usableTabList: snapshot.data,
                                      ),
                                      child: const ArticleListItemWidget(),
                                    )
                                  ],
                                ),
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
        );
      },
    );
  }

  Widget _title() {
    return const Padding(
      padding: EdgeInsets.only(top: 24, left: 12),
      child: Text('Artists Article Collection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }
}
