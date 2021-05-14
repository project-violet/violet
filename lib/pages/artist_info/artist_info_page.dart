// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';

import 'package:auto_animated/auto_animated.dart';
import 'package:expandable/expandable.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/component/hitomi/title_cluster.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/article_list_page.dart';
import 'package:violet/pages/artist_info/series_list_page.dart';
import 'package:violet/pages/artist_info/similar_list_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/toast.dart';

class ArtistInfoPage extends StatefulWidget {
  final String artist;
  final bool isGroup;
  final bool isUploader;
  final bool isSeries;
  final bool isCharacter;

  ArtistInfoPage({
    @required this.artist,
    this.isGroup = false,
    this.isUploader = false,
    this.isSeries = false,
    this.isCharacter = false,
  });

  @override
  _ArtistInfoPageState createState() => _ArtistInfoPageState();
}

class _ArtistInfoPageState extends State<ArtistInfoPage> {
  bool qureyLoaded = false;
  // This is used for top color bar
  int femaleTags = 0;
  int maleTags = 0;
  int tags = 0;
  // Artist? Group? Uploader?
  String prefix;
  // Artist Articles
  List<QueryResult> cc;
  // Chart component lists
  List<Tuple2<String, int>> lff = List<Tuple2<String, int>>();
  List<Tuple2<String, int>> lffOrigin;
  // Similar Aritsts Info
  List<Tuple2<String, double>> similars;
  List<Tuple2<String, double>> similarsAll;
  List<Tuple2<String, double>> relatedCOSSingle;
  List<Tuple2<String, double>> relatedCharacterOrSeries;
  List<Tuple2<String, double>> relatedCOSSingleAll;
  List<Tuple2<String, double>> relatedCharacterOrSeriesAll;
  // Similar Item Lists
  List<List<QueryResult>> qrs = List<List<QueryResult>>();
  List<List<QueryResult>> qrsCOSSingle = List<List<QueryResult>>();
  List<List<QueryResult>> qrsCharacterOrSeries = List<List<QueryResult>>();
  // Title clustering
  List<List<int>> series;

  bool isBookmarked = false;
  FlareControls flareController = FlareControls();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      //
      // Check bookmark
      //
      var type = widget.isGroup
          ? 1
          : widget.isUploader
              ? 2
              : widget.isSeries
                  ? 3
                  : widget.isCharacter
                      ? 4
                      : 0;
      isBookmarked = await (await Bookmark.getInstance())
          .isBookmarkArtist(widget.artist, type);

      //
      //  Get query
      //
      cc = await query([
        widget.artist,
        widget.isGroup,
        widget.isUploader,
        widget.isSeries,
        widget.isCharacter
      ]);

      //
      //  Title based article clustering
      //
      series = HitomiTitleCluster.doClustering(
              cc.map((e) => e.title() as String).toList())
          .toList();

      //
      //  Statistics
      //
      var ffstat = Map<String, int>();

      cc.forEach((element) {
        if (element.tags() == null) return;
        (element.tags() as String)
            .split('|')
            .where((element) => element != '')
            .forEach((element) {
          if (element.startsWith('female:'))
            femaleTags += 1;
          else if (element.startsWith('male:'))
            maleTags += 1;
          else
            tags += 1;

          if (!ffstat.containsKey(element)) ffstat[element] = 0;
          ffstat[element] += 1;
        });
      });

      ffstat.forEach((key, value) {
        lff.add(Tuple2<String, int>(key, value));
      });
      lff.sort((x, y) => y.item2.compareTo(x.item2));

      lffOrigin = lff;
      lff = lff.take(5).toList();

      if (femaleTags + maleTags + tags == 0) tags = 0;

      //
      //  Similar Artists (or group, uploader)
      //

      if (widget.isGroup)
        similars = HitomiIndexs.calculateSimilarGroups(widget.artist);
      else if (widget.isUploader)
        similars = HitomiIndexs.calculateSimilarUploaders(widget.artist);
      else if (widget.isSeries)
        similars = HitomiIndexs.calculateSimilarSeries(widget.artist);
      else if (widget.isCharacter)
        similars = HitomiIndexs.calculateSimilarCharacter(widget.artist);
      else
        similars = HitomiIndexs.calculateSimilarArtists(widget.artist);

      similarsAll = similars;
      similars = similars.take(6).toList();

      prefix = 'artist:';
      if (widget.isGroup)
        prefix = 'group:';
      else if (widget.isUploader)
        prefix = 'uploader:';
      else if (widget.isSeries)
        prefix = 'series:';
      else if (widget.isCharacter) prefix = 'character:';

      await querySimilars(similars, prefix, qrs);

      if (widget.isCharacter || widget.isSeries) {
        if (widget.isCharacter) {
          relatedCharacterOrSeriesAll =
              HitomiIndexs.calculateRelatedSeriesCharacter(widget.artist);
          relatedCOSSingleAll = HitomiIndexs.getRelatedSeries(widget.artist);
        } else {
          relatedCharacterOrSeriesAll =
              HitomiIndexs.calculateRelatedCharacterSeries(widget.artist);
          relatedCOSSingleAll =
              HitomiIndexs.getRelatedCharacters(widget.artist);
        }
        relatedCharacterOrSeries = relatedCharacterOrSeriesAll.take(6).toList();
        relatedCOSSingle = relatedCOSSingleAll.take(6).toList();

        await querySimilars(
          relatedCharacterOrSeries,
          widget.isCharacter ? 'character:' : 'series:',
          qrsCharacterOrSeries,
        );

        await querySimilars(
          relatedCOSSingle,
          widget.isCharacter ? 'series:' : 'character:',
          qrsCOSSingle,
        );
      }

      setState(() {
        qureyLoaded = true;
      });

      Future.delayed(Duration(milliseconds: 300)).then((value) {
        ec.expanded = true;
      });
    });
  }

  Future<void> querySimilars(List<Tuple2<String, double>> similars,
      String prefix, List<List<QueryResult>> qrs) async {
    var unescape = new HtmlUnescape();
    for (int i = 0; i < similars.length; i++) {
      var postfix = similars[i].item1.toLowerCase().replaceAll(' ', '_');
      var queryString = HitomiManager.translate2query(prefix +
          postfix +
          ' ' +
          Settings.includeTags +
          ' ' +
          Settings.excludeTags
              .where((e) => e.trim() != '')
              .map((e) => '-$e')
              .join(' '));
      final qm = QueryManager.queryPagination(queryString);
      qm.itemsPerPage = 10;

      var x = await qm.next();
      if (x == null || x.length == 0) {
        qrs.add(List<QueryResult>());
        continue;
      }
      var y = [x[0]];

      var titles = [unescape.convert((x[0].title() as String).trim())];
      if (titles[0].contains('Ch.'))
        titles[0] = titles[0].split('Ch.')[0];
      else if (titles[0].contains('ch.')) titles[0] = titles[0].split('ch.')[0];

      for (int i = 1; i < x.length; i++) {
        var skip = false;
        var ff = unescape.convert((x[i].title() as String).trim());
        if (ff.contains('Ch.'))
          ff = ff.split('Ch.')[0];
        else if (ff.contains('ch.')) ff = ff.split('ch.')[0];
        for (int j = 0; j < titles.length; j++) {
          var tt = titles[j];
          if (Distance.levenshteinDistanceComparable(
                  tt.runes.map((e) => e.toString()).toList(),
                  ff.runes.map((e) => e.toString()).toList()) <
              3) {
            skip = true;
            break;
          }
        }
        if (skip) continue;
        y.add(x[i]);
        titles.add(ff.trim());
      }

      qrs.add(y);
    }
  }

  Future<List<QueryResult>> query(dynamic obj) async {
    var artist = obj[0] as String;
    var isGroup = obj[1] as bool;
    var isUploader = obj[2] as bool;
    var isSeries = obj[3] as bool;
    var isCharacter = obj[4] as bool;

    var query = HitomiManager.translate2query((isGroup
            ? 'group:'
            : isUploader
                ? 'uploader:'
                : isSeries
                    ? 'series:'
                    : isCharacter
                        ? 'character:'
                        : 'artist:') +
        '${artist.replaceAll(' ', '_')} ' +
        Settings.includeTags +
        ' ' +
        Settings.excludeTags
            .where((e) => e.trim() != '')
            .map((e) => '-$e')
            .join(' '));

    // DateTime dt = DateTime.now();
    QueryManager qm = await QueryManager.query(query + ' ORDER BY Id DESC');
    // print((DateTime.now().difference(dt)).inSeconds);

    return qm.results;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);
    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
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
                  child: qureyLoaded
                      ? SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              Container(
                                height: 16,
                              ),
                              nameArea(),
                              queryResult()
                            ],
                          ),
                        )
                      : Column(
                          children: <Widget>[
                            Container(
                              height: 16,
                            ),
                            nameArea(),
                            Expanded(
                              child: Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget nameArea() {
    return GestureDetector(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: FlareActor(
              'assets/flare/likeUtsua.flr',
              animation: isBookmarked ? "Like" : "IdleUnlike",
              controller: flareController,
            ),
          ),
          Text(
              (widget.isGroup
                      ? 'Groups: '
                      : widget.isUploader
                          ? 'Uploader: '
                          : widget.isSeries
                              ? 'Series: '
                              : widget.isCharacter
                                  ? 'Character: '
                                  : 'Artist: ') +
                  widget.artist,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      onTap: () async {
        isBookmarked = !isBookmarked;

        var type = widget.isGroup
            ? 1
            : widget.isUploader
                ? 2
                : widget.isSeries
                    ? 3
                    : widget.isCharacter
                        ? 4
                        : 0;

        FlutterToast(context).showToast(
          child: ToastWrapper(
            isCheck: true,
            msg:
                '${widget.artist}${Translations.of(context).trans(isBookmarked ? 'addtobookmark' : 'removetobookmark')}',
          ),
          gravity: ToastGravity.BOTTOM,
          toastDuration: Duration(seconds: 4),
        );

        if (!isBookmarked) {
          await (await Bookmark.getInstance())
              .unbookmarkArtist(widget.artist, type);
          flareController.play('Unlike');
        } else {
          await (await Bookmark.getInstance())
              .bookmarkArtist(widget.artist, type);
          flareController.play('Like');
        }
      },
    );
  }

  bool isExpanded = false;

  Widget queryResult() {
    final width = MediaQuery.of(context).size.width;
    var axis1 = charts.AxisSpec<String>(
        renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(
                fontSize: isExpanded ? 10 : 14,
                color: charts.MaterialPalette.white),
            lineStyle: charts.LineStyleSpec(
                color: charts.MaterialPalette.transparent)));
    var axis2 = charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
      labelStyle: charts.TextStyleSpec(
          fontSize: 10, color: charts.MaterialPalette.white),
    ));
    return Container(
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(64, 16, 64, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                      flex: femaleTags,
                      child: Container(
                        height: 8,
                        color: Colors.pink,
                      )),
                  Expanded(
                      flex: maleTags,
                      child: Container(
                        height: 8,
                        color: Colors.blue,
                      )),
                  Expanded(
                      flex: tags,
                      child: Container(
                        height: 8,
                        color: Colors.grey,
                      )),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(4),
          ),
          InkWell(
            child: SizedBox(
                width: width - 16 - 32,
                height: isExpanded
                    ? lff.length * 14.0 + 10
                    : lff.length * 22.0 + 10,
                child: charts.BarChart(
                  [
                    new charts.Series<Tuple2<String, int>, String>(
                        id: 'Sales',
                        data: lff,
                        domainFn: (Tuple2<String, int> sales, f) =>
                            sales.item1.contains(':')
                                ? sales.item1.split(':')[1]
                                : sales.item1,
                        measureFn: (Tuple2<String, int> sales, _) =>
                            sales.item2,
                        colorFn: (Tuple2<String, int> sales, _) {
                          if (sales.item1.startsWith('female:'))
                            return charts.MaterialPalette.pink.shadeDefault;
                          else if (sales.item1.startsWith('male:'))
                            return charts.MaterialPalette.blue.shadeDefault;
                          else
                            return charts.MaterialPalette.gray.shadeDefault;
                        }),
                  ],
                  primaryMeasureAxis: Settings.themeWhat ? axis2 : null,
                  domainAxis: Settings.themeWhat ? axis1 : null,
                  animate: true,
                  vertical: false,
                )),
            onTap: () {},
            onTapCancel: () {
              isExpanded = !isExpanded;
              if (isExpanded)
                lff = lffOrigin;
              else
                lff = lffOrigin.take(5).toList();
              setState(() {});
            },
          ),
          ExpandableNotifier(
            controller: ec,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: ScrollOnExpand(
                child: ExpandablePanel(
                  theme: ExpandableThemeData(
                      iconColor:
                          Settings.themeWhat ? Colors.white : Colors.grey,
                      animationDuration: const Duration(milliseconds: 500)),
                  header: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                    child: Text(
                        '${Translations.of(context).trans('articles')} (${cc.length})'),
                  ),
                  expanded: Column(children: <Widget>[
                    articleArea(),
                    Visibility(
                        visible: cc.length > 6,
                        child: more(ArticleListPage(
                            cc: cc,
                            name: (widget.isGroup
                                    ? 'Groups: '
                                    : widget.isUploader
                                        ? 'Uploader: '
                                        : widget.isSeries
                                            ? 'Series: '
                                            : widget.isCharacter
                                                ? 'Character: '
                                                : 'Artist: ') +
                                widget.artist)))
                  ]),
                ),
              ),
            ),
          ),
          widget.isCharacter || widget.isSeries
              ? ExpandableNotifier(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: ScrollOnExpand(
                      child: ExpandablePanel(
                        theme: ExpandableThemeData(
                            iconColor:
                                Settings.themeWhat ? Colors.white : Colors.grey,
                            animationDuration:
                                const Duration(milliseconds: 500)),
                        header: Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                          child: Text(Translations.of(context)
                                  .trans('related') +
                              ' ' +
                              (widget.isSeries
                                  ? Translations.of(context).trans('iseries')
                                  : Translations.of(context)
                                      .trans('icharacter'))),
                        ),
                        expanded: relatedArea(),
                      ),
                    ),
                  ),
                )
              : Container(),
          widget.isCharacter || widget.isSeries
              ? ExpandableNotifier(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: ScrollOnExpand(
                      child: ExpandablePanel(
                        theme: ExpandableThemeData(
                            iconColor:
                                Settings.themeWhat ? Colors.white : Colors.grey,
                            animationDuration:
                                const Duration(milliseconds: 500)),
                        header: Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                          child: Text(Translations.of(context)
                                  .trans('related') +
                              ' ' +
                              (widget.isCharacter
                                  ? Translations.of(context).trans('iseries')
                                  : Translations.of(context)
                                      .trans('icharacter'))),
                        ),
                        expanded: relatedSingleArea(),
                      ),
                    ),
                  ),
                )
              : Container(),
          ExpandableNotifier(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: ScrollOnExpand(
                child: ExpandablePanel(
                  theme: ExpandableThemeData(
                      iconColor:
                          Settings.themeWhat ? Colors.white : Colors.grey,
                      animationDuration: const Duration(milliseconds: 500)),
                  header: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                    child: Text(Translations.of(context).trans('similar') +
                        ' ' +
                        (widget.isGroup
                            ? Translations.of(context).trans('igroups')
                            : widget.isUploader
                                ? Translations.of(context).trans('iuploader')
                                : widget.isSeries
                                    ? Translations.of(context).trans('iseries')
                                    : widget.isCharacter
                                        ? Translations.of(context)
                                            .trans('icharacter')
                                        : Translations.of(context)
                                            .trans('iartists'))),
                  ),
                  expanded: similarArea(),
                ),
              ),
            ),
          ),
          ExpandableNotifier(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: ScrollOnExpand(
                child: ExpandablePanel(
                  theme: ExpandableThemeData(
                      iconColor:
                          Settings.themeWhat ? Colors.white : Colors.grey,
                      animationDuration: const Duration(milliseconds: 500)),
                  header: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                    child: Text(Translations.of(context).trans('series') +
                        ' (${series.length})'),
                  ),
                  expanded: seriesArea(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ExpandableController ec = ExpandableController();

  Widget more(Widget what) {
    return SizedBox(
        height: 60,
        child: InkWell(
            onTap: () async {
              if (!Platform.isIOS) {
                Navigator.of(context).push(PageRouteBuilder(
                  opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    var begin = Offset(0.0, 1.0);
                    var end = Offset.zero;
                    var curve = Curves.ease;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                  pageBuilder: (_, __, ___) => what,
                ));
              } else {
                Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (_) => what));
              }
            },
            child: Row(
              children: [Text(Translations.of(context).trans('more'))],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
            )));
  }

  Widget articleArea() {
    var windowWidth = MediaQuery.of(context).size.width;
    return LiveGrid(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      showItemInterval: Duration(milliseconds: 50),
      showItemDuration: Duration(milliseconds: 150),
      visibleFraction: 0.001,
      itemCount: min(cc.length, 6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (context, index, animation) {
        return FadeTransition(
          opacity: Tween<double>(
            begin: 0,
            end: 1,
          ).animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, -0.1),
              end: Offset.zero,
            ).animate(animation),
            child: Padding(
              padding: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  child: Provider<ArticleListItem>.value(
                    value: ArticleListItem.fromArticleListItem(
                      queryResult: cc[index],
                      showDetail: false,
                      addBottomPadding: false,
                      width: (windowWidth - 4.0) / 3,
                      thumbnailTag: Uuid().v4(),
                    ),
                    child: ArticleListItemVerySimpleWidget(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget similarArea() {
    var windowWidth = MediaQuery.of(context).size.width;
    return ListView.builder(
        padding: EdgeInsets.all(0),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: similars.length + 1,
        itemBuilder: (BuildContext ctxt, int index) {
          if (index == similars.length) {
            return more(SimilarListPage(
              prefix: prefix,
              similarsAll: similarsAll,
              isGroup: widget.isGroup,
              isUploader: widget.isUploader,
              isCharacter: widget.isCharacter,
              isSeries: widget.isSeries,
            ));
          }
          var e = similars[index];
          var qq = qrs[index];
          return InkWell(
            onTap: () async {
              if (!Platform.isIOS) {
                Navigator.of(context).push(PageRouteBuilder(
                  // opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    var begin = Offset(0.0, 1.0);
                    var end = Offset.zero;
                    var curve = Curves.ease;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                  pageBuilder: (_, __, ___) => ArtistInfoPage(
                    isGroup: widget.isGroup,
                    isUploader: widget.isUploader,
                    isCharacter: widget.isCharacter,
                    isSeries: widget.isSeries,
                    artist: e.item1,
                  ),
                ));
              } else {
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => ArtistInfoPage(
                    isGroup: widget.isGroup,
                    isUploader: widget.isUploader,
                    isCharacter: widget.isCharacter,
                    isSeries: widget.isSeries,
                    artist: e.item1,
                  ),
                ));
              }
            },
            child: SizedBox(
              height: 195,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        // crossAxisAlignment: CrossAxisAlignment,
                        children: <Widget>[
                          Text(
                              // (index + 1).toString() +
                              //     '. ' +
                              ' ' +
                                  e.item1 +
                                  ' (' +
                                  HitomiManager.getArticleCount(
                                          widget.isGroup
                                              ? 'group'
                                              : widget.isUploader
                                                  ? 'uploader'
                                                  : widget.isSeries
                                                      ? 'series'
                                                      : widget.isCharacter
                                                          ? 'character'
                                                          : 'artist',
                                          e.item1)
                                      .toString() +
                                  ')',
                              style: TextStyle(fontSize: 17)),
                          Text(
                              '${Translations.of(context).trans('score')}: ' +
                                  e.item2.toStringAsFixed(1) +
                                  ' ',
                              style: TextStyle(
                                color: Settings.themeWhat
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              )),
                        ],
                      ),
                      SizedBox(
                        height: 162,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                                flex: 1,
                                child: qq.length > 0
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[0],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 1
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[1],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 2
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[2],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                          ],
                        ),
                      ),
                      // Container(
                      //   padding: EdgeInsets.all(2),
                      // ),
                      // Text('Score: ' + e.item2.toStringAsFixed(1),
                      //     style: TextStyle(color: Colors.grey.shade300)),
                    ],
                  )),
            ),
          );
        });
  }

  Widget seriesArea() {
    var unescape = new HtmlUnescape();
    var windowWidth = MediaQuery.of(context).size.width;
    return ListView.builder(
        padding: EdgeInsets.all(0),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: min(series.length, 6) + (series.length > 6 ? 1 : 0),
        itemBuilder: (BuildContext ctxt, int index) {
          if (index == 6) {
            return more(SeriesListPage(
              cc: cc,
              prefix: prefix,
              series: series,
            ));
          }
          var e = series[index];
          return InkWell(
            onTap: () async {
              var page = ArticleListPage(
                  cc: e.map((e) => cc[e]).toList(), name: 'Series');

              if (!Platform.isIOS) {
                Navigator.of(context).push(PageRouteBuilder(
                  opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    var begin = Offset(0.0, 1.0);
                    var end = Offset.zero;
                    var curve = Curves.ease;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                  pageBuilder: (_, __, ___) => page,
                ));
              } else {
                Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (_) => page));
              }
              // Navigator.of(context).push(PageRouteBuilder(
              //   // opaque: false,
              //   transitionDuration: Duration(milliseconds: 500),
              //   transitionsBuilder:
              //       (context, animation, secondaryAnimation, child) {
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
              //     isGroup: widget.isGroup,
              //     isUploader: widget.isUploader,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Flexible(
                              child: Text(
                                  // (index + 1).toString() +
                                  //     '. ' +
                                  ' ' + unescape.convert(cc[e[0]].title()),
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
                      SizedBox(
                        height: 162,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                                flex: 1,
                                child: e.length > 0
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: cc[e[0]],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
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
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: cc[e[1]],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
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
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: cc[e[2]],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
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
                  )),
            ),
          );
        });
  }

  Widget relatedArea() {
    var windowWidth = MediaQuery.of(context).size.width;
    return ListView.builder(
        padding: EdgeInsets.all(0),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: relatedCharacterOrSeries.length + 1,
        itemBuilder: (BuildContext ctxt, int index) {
          if (index == relatedCharacterOrSeries.length) {
            return more(SimilarListPage(
              prefix: prefix,
              similarsAll: relatedCharacterOrSeriesAll,
              isGroup: widget.isGroup,
              isUploader: widget.isUploader,
              isCharacter: widget.isCharacter,
              isSeries: widget.isSeries,
            ));
          }
          var e = relatedCharacterOrSeries[index];
          var qq = qrsCharacterOrSeries[index];
          return InkWell(
            onTap: () async {
              if (!Platform.isIOS) {
                Navigator.of(context).push(PageRouteBuilder(
                  // opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    var begin = Offset(0.0, 1.0);
                    var end = Offset.zero;
                    var curve = Curves.ease;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                  pageBuilder: (_, __, ___) => ArtistInfoPage(
                    isGroup: widget.isGroup,
                    isUploader: widget.isUploader,
                    isCharacter: widget.isCharacter,
                    isSeries: widget.isSeries,
                    artist: e.item1,
                  ),
                ));
              } else {
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => ArtistInfoPage(
                    isGroup: widget.isGroup,
                    isUploader: widget.isUploader,
                    isCharacter: widget.isCharacter,
                    isSeries: widget.isSeries,
                    artist: e.item1,
                  ),
                ));
              }
            },
            child: SizedBox(
              height: 195,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        // crossAxisAlignment: CrossAxisAlignment,
                        children: <Widget>[
                          Text(
                              // (index + 1).toString() +
                              //     '. ' +
                              ' ' +
                                  e.item1 +
                                  ' (' +
                                  HitomiManager.getArticleCount(
                                          widget.isSeries
                                              ? 'series'
                                              : 'character',
                                          e.item1)
                                      .toString() +
                                  ')',
                              style: TextStyle(fontSize: 17)),
                          Text(
                              '${Translations.of(context).trans('score')}: ' +
                                  e.item2.toStringAsFixed(1) +
                                  ' ',
                              style: TextStyle(
                                color: Settings.themeWhat
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              )),
                        ],
                      ),
                      SizedBox(
                        height: 162,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                                flex: 1,
                                child: qq.length > 0
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[0],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 1
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[1],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 2
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[2],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                          ],
                        ),
                      ),
                      // Container(
                      //   padding: EdgeInsets.all(2),
                      // ),
                      // Text('Score: ' + e.item2.toStringAsFixed(1),
                      //     style: TextStyle(color: Colors.grey.shade300)),
                    ],
                  )),
            ),
          );
        });
  }

  Widget relatedSingleArea() {
    var windowWidth = MediaQuery.of(context).size.width;
    return ListView.builder(
        padding: EdgeInsets.all(0),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: relatedCOSSingle.length + 1,
        itemBuilder: (BuildContext ctxt, int index) {
          if (index == relatedCOSSingle.length) {
            return more(SimilarListPage(
              prefix: widget.isCharacter ? 'series:' : 'character:',
              similarsAll: relatedCOSSingleAll,
              isGroup: widget.isGroup,
              isUploader: widget.isUploader,
              isSeries: widget.isCharacter,
              isCharacter: widget.isSeries,
            ));
          }
          var e = relatedCOSSingle[index];
          var qq = qrsCOSSingle[index];
          return InkWell(
            onTap: () async {
              if (!Platform.isIOS) {
                Navigator.of(context).push(PageRouteBuilder(
                  // opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    var begin = Offset(0.0, 1.0);
                    var end = Offset.zero;
                    var curve = Curves.ease;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                  pageBuilder: (_, __, ___) => ArtistInfoPage(
                    isGroup: widget.isGroup,
                    isUploader: widget.isUploader,
                    isSeries: widget.isCharacter,
                    isCharacter: widget.isSeries,
                    artist: e.item1,
                  ),
                ));
              } else {
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => ArtistInfoPage(
                    isGroup: widget.isGroup,
                    isUploader: widget.isUploader,
                    isSeries: widget.isCharacter,
                    isCharacter: widget.isSeries,
                    artist: e.item1,
                  ),
                ));
              }
            },
            child: SizedBox(
              height: 195,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        // crossAxisAlignment: CrossAxisAlignment,
                        children: <Widget>[
                          Text(
                              // (index + 1).toString() +
                              //     '. ' +
                              ' ' +
                                  e.item1 +
                                  ' (' +
                                  HitomiManager.getArticleCount(
                                          widget.isCharacter
                                              ? 'series'
                                              : 'character',
                                          e.item1)
                                      .toString() +
                                  ')',
                              style: TextStyle(fontSize: 17)),
                          Text(
                              '${Translations.of(context).trans('score')}: ' +
                                  e.item2.toStringAsFixed(1) +
                                  ' ',
                              style: TextStyle(
                                color: Settings.themeWhat
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              )),
                        ],
                      ),
                      SizedBox(
                        height: 162,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                                flex: 1,
                                child: qq.length > 0
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[0],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 1
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[1],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 2
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Provider<ArticleListItem>.value(
                                          value: ArticleListItem
                                              .fromArticleListItem(
                                            queryResult: qq[2],
                                            showDetail: false,
                                            addBottomPadding: false,
                                            width:
                                                (windowWidth - 16 - 4.0 - 1.0) /
                                                    3,
                                            thumbnailTag: Uuid().v4(),
                                            disableFilter: true,
                                          ),
                                          child:
                                              ArticleListItemVerySimpleWidget(),
                                        ),
                                      )
                                    : Container()),
                          ],
                        ),
                      ),
                      // Container(
                      //   padding: EdgeInsets.all(2),
                      // ),
                      // Text('Score: ' + e.item2.toStringAsFixed(1),
                      //     style: TextStyle(color: Colors.grey.shade300)),
                    ],
                  )),
            ),
          );
        });
  }
}
