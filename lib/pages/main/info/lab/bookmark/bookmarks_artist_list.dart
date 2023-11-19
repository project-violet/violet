// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mdi/mdi.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/search_bar.dart';

class LabGroupArtistList extends StatefulWidget {
  final List<BookmarkArtist> artists;
  final String name;
  final int groupId;

  const LabGroupArtistList({
    super.key,
    required this.artists,
    required this.name,
    required this.groupId,
  });

  @override
  State<LabGroupArtistList> createState() => _GroupArtistListState();
}

class _GroupArtistListState extends State<LabGroupArtistList>
    with AutomaticKeepAliveClientMixin<LabGroupArtistList> {
  @override
  bool get wantKeepAlive => true;
  late List<BookmarkArtist> artists;

  Future<List<BookmarkArtist>> _bookmark() async {
    if (_filterLevel == 0) await refresh();
    return artists;
  }

  Future<void> _sortByLatest() async {
    var ids = <Tuple2<int, int>>[];
    for (int i = 0; i < artists.length; i++) {
      var postfix = artists[i].artist().toLowerCase().replaceAll(' ', '_');
      var queryString = HitomiManager.translate2query('${[
        'artist',
        'group',
        'uploader',
        'series',
        'character'
      ][artists[i].type()]}:$postfix ${Settings.includeTags}');
      final qm = QueryManager.queryPagination(queryString);
      qm.itemsPerPage = 1;
      var query = (await qm.next())[0].id();
      ids.add(Tuple2<int, int>(query, i));
    }
    ids.sort((e1, e2) => e2.item1.compareTo(e1.item1));

    var newedList = <BookmarkArtist>[];
    for (int i = 0; i < artists.length; i++) {
      newedList.add(artists[ids[i].item2]);
    }

    artists = newedList;
  }

  Future<List<QueryResult>> _future(String e, int type) async {
    var postfix = e.toLowerCase().replaceAll(' ', '_');
    var queryString = HitomiManager.translate2query('${[
      'artist',
      'group',
      'uploader',
      'series',
      'character'
    ][type]}:$postfix ${Settings.includeTags}');
    final qm = QueryManager.queryPagination(queryString);
    qm.itemsPerPage = 3;
    return await qm.next();
  }

  Future<void> refresh() async {
    artists = widget.artists
        .where((element) => element.group() == widget.groupId)
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<List<BookmarkArtist>>(
        future: _bookmark(),
        builder: (BuildContext context,
            AsyncSnapshot<List<BookmarkArtist>> snapshot) {
          if (!snapshot.hasData) return Container();
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverPersistentHeader(
                floating: true,
                delegate: AnimatedOpacitySliver(
                  searchBar: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Stack(children: <Widget>[
                        _filter(),
                        _title(),
                      ])),
                ),
              ),
              SliverList(
                // padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    var e = artists[index];
                    return FutureBuilder<List<QueryResult>>(
                      future: _future(e.artist(), e.type()),
                      builder: (BuildContext context,
                          AsyncSnapshot<List<QueryResult>> snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            height: 195,
                          );
                        }
                        return _listItem(context, e, snapshot.data!);
                      },
                    );
                  },
                  childCount: _progressingFilter ? 0 : artists.length,
                ),
              )
            ],
          );
        },
      ),
    );
  }

  int _filterLevel = 0;
  bool _progressingFilter = false;
  Widget _filter() {
    return Align(
      alignment: Alignment.centerRight,
      child: Hero(
        tag: 'searchtype3',
        child: Card(
          color: Palette.themeColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8.0),
            ),
          ),
          elevation: !Settings.themeFlat ? 100 : 0,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: InkWell(
            onTap: _progressingFilter
                ? null
                : () async {
                    setState(() {
                      _progressingFilter = true;
                    });
                    await _sortByLatest();
                    setState(() {
                      _progressingFilter = false;
                      _filterLevel = (_filterLevel + 1) % 2;
                    });
                  },
            child: SizedBox(
              height: 48,
              width: 48,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  _progressingFilter
                      ? const SizedBox(
                          height: 30,
                          width: 30,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.grey),
                          ))
                      : Icon(
                          [
                            MdiIcons.formatListText,
                            Mdi.sortClockDescendingOutline
                          ][_filterLevel],
                          color: Colors.grey,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title() {
    return const Padding(
      padding: EdgeInsets.only(top: 24, left: 12),
      child: Text('Artists Collection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _listItem(
      BuildContext context, BookmarkArtist e, List<QueryResult> qq) {
    var windowWidth = MediaQuery.of(context).size.width;
    return Container(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          PlatformNavigator.navigateSlide(
            context,
            ArtistInfoPage(
              isGroup: e.type() == 1,
              isUploader: e.type() == 2,
              isSeries: e.type() == 3,
              isCharacter: e.type() == 4,
              artist: e.artist(),
            ),
          );
        },
        child: SizedBox(
          height: 195,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                        ' ${[
                          'artist',
                          'group',
                          'uploader',
                          'series',
                          'character'
                        ][e.type()]}:${e.artist()} (${HitomiManager.getArticleCount([
                              'artist',
                              'group',
                              'uploader',
                              'series',
                              'character'
                            ][e.type()], e.artist())})',
                        style: const TextStyle(fontSize: 17)),
                  ],
                ),
                SizedBox(
                  height: 162,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _image(qq, 0, windowWidth),
                      _image(qq, 1, windowWidth),
                      _image(qq, 2, windowWidth),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(List<QueryResult> qq, int index, double windowWidth) {
    return Expanded(
        flex: 1,
        child: qq.length > index
            ? Padding(
                key: Key('${qq[index].id()}/${index}_thumbnail_bookmark'),
                padding: const EdgeInsets.all(4),
                child: Provider<ArticleListItem>.value(
                  value: ArticleListItem.fromArticleListItem(
                    queryResult: qq[index],
                    showDetail: false,
                    addBottomPadding: false,
                    width: (windowWidth - 16 - 4.0 - 16.0) / 3,
                    thumbnailTag: const Uuid().v4(),
                    disableFilter: true,
                    usableTabList: qq,
                  ),
                  child: const ArticleListItemWidget(),
                ),
              )
            : Container());
  }
}
