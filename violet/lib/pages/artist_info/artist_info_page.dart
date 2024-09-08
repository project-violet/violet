// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:auto_animated/auto_animated.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:expandable/expandable.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
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
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/artist_info/article_list_page.dart';
import 'package:violet/pages/artist_info/series_list_page.dart';
import 'package:violet/pages/artist_info/similar_list_page.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/segment/three_article_panel.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/util/strings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class ArtistInfoPage extends StatefulWidget {
  final String name;
  final ArtistType type;

  const ArtistInfoPage({
    super.key,
    required this.name,
    required this.type,
  });

  @override
  State<ArtistInfoPage> createState() => _ArtistInfoPageState();
}

class _ArtistInfoPageState extends State<ArtistInfoPage> {
  bool qureyLoaded = false;
  // This is used for top color bar
  int femaleTags = 0;
  int maleTags = 0;
  int tags = 0;
  // Artist Articles
  late List<QueryResult> cc;
  // Chart component lists
  late List<Tuple2<String, int>> lff = <Tuple2<String, int>>[];
  late List<Tuple2<String, int>> lffOrigin;
  // Similar Aritsts Info
  late List<Tuple2<String, double>> similars;
  late List<Tuple2<String, double>> similarsAll;
  late List<Tuple2<String, double>> relatedCOSSingle;
  late List<Tuple2<String, double>> relatedCharacterOrSeries;
  late List<Tuple2<String, double>> relatedCOSSingleAll;
  late List<Tuple2<String, double>> relatedCharacterOrSeriesAll;
  // Similar Item Lists
  List<List<QueryResult>> qrs = [];
  List<List<QueryResult>> qrsCOSSingle = [];
  List<List<QueryResult>> qrsCharacterOrSeries = [];
  // Title clustering
  late List<List<int>> series;
  // Comments
  List<Tuple3<DateTime, String, String>>? comments;

  bool isBookmarked = false;
  FlareControls flareController = FlareControls();

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      //
      // Check bookmark
      //
      isBookmarked = await (await Bookmark.getInstance())
          .isBookmarkArtist(widget.name, widget.type);

      //
      //  Get query
      //
      cc = await query();

      //
      //  Title based article clustering
      //
      series = HitomiTitleCluster.doClustering(
              cc.map((e) => e.title() as String).toList())
          .toList();

      //
      //  Statistics
      //
      var ffstat = <String, int>{};

      for (var element in cc) {
        if (element.tags() == null) continue;
        (element.tags() as String)
            .split('|')
            .where((element) => element != '')
            .forEach((element) {
          if (element.startsWith('female:')) {
            femaleTags += 1;
          } else if (element.startsWith('male:')) {
            maleTags += 1;
          } else {
            tags += 1;
          }

          if (!ffstat.containsKey(element)) ffstat[element] = 0;
          ffstat[element] = ffstat[element]! + 1;
        });
      }

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
      switch (widget.type) {
        case ArtistType.artist:
          similars = HitomiIndexs.calculateSimilarArtists(widget.name);
          break;
        case ArtistType.group:
          similars = HitomiIndexs.calculateSimilarGroups(widget.name);
          break;
        case ArtistType.uploader:
          similars = HitomiIndexs.calculateSimilarUploaders(widget.name);
          break;
        case ArtistType.series:
          similars = HitomiIndexs.calculateSimilarSeries(widget.name);
          break;
        case ArtistType.character:
          similars = HitomiIndexs.calculateSimilarCharacter(widget.name);
          break;
      }

      similarsAll = similars;
      similars = similars.take(6).toList();

      await querySimilars(similars, widget.type.name, qrs);

      if (widget.type.isCharacter || widget.type.isSeries) {
        if (widget.type.isCharacter) {
          relatedCharacterOrSeriesAll =
              HitomiIndexs.calculateRelatedSeriesCharacter(widget.name);
          relatedCOSSingleAll = HitomiIndexs.getRelatedSeries(widget.name);
        } else {
          relatedCharacterOrSeriesAll =
              HitomiIndexs.calculateRelatedCharacterSeries(widget.name);
          relatedCOSSingleAll = HitomiIndexs.getRelatedCharacters(widget.name);
        }
        relatedCharacterOrSeries = relatedCharacterOrSeriesAll.take(6).toList();
        relatedCOSSingle = relatedCOSSingleAll.take(6).toList();

        await querySimilars(
          relatedCharacterOrSeries,
          widget.type.name,
          qrsCharacterOrSeries,
        );

        await querySimilars(
          relatedCOSSingle,
          widget.type.name,
          qrsCOSSingle,
        );
      }

      setState(() {
        qureyLoaded = true;
      });

      Future.delayed(const Duration(milliseconds: 300)).then((value) {
        ec.expanded = true;
        commentAreaEC.expanded = true;
      });

      Future.delayed(const Duration(microseconds: 100))
          .then((value) async => await readComments());
    });
  }

  Future<void> readComments() async {
    final tcomments = (await VioletCommunityAnonymous.getArtistComments(
        '${widget.type.name}:${widget.name}'))['result'] as List<dynamic>;

    comments = tcomments
        .map((e) => Tuple3<DateTime, String, String>(
            DateTime.parse(e['TimeStamp']), e['UserAppId'], e['Body']))
        .toList()
        .reversed
        .toList();

    if (comments!.isNotEmpty) setState(() {});
  }

  Future<void> querySimilars(List<Tuple2<String, double>> similars,
      String prefix, List<List<QueryResult>> qrs) async {
    var unescape = HtmlUnescape();
    for (int i = 0; i < similars.length; i++) {
      var postfix = similars[i].item1.toLowerCase().replaceAll(' ', '_');
      var queryString = HitomiManager.translate2query(
          '$prefix:$postfix ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}');
      final qm = QueryManager.queryPagination(queryString);
      qm.itemsPerPage = 10;

      var x = await qm.next();
      if (x.isEmpty) {
        qrs.add(<QueryResult>[]);
        continue;
      }
      var y = [x[0]];

      var titles = [unescape.convert((x[0].title() as String).trim())];
      if (titles[0].contains('Ch.')) {
        titles[0] = titles[0].split('Ch.')[0];
      } else if (titles[0].contains('ch.')) {
        titles[0] = titles[0].split('ch.')[0];
      }

      for (int i = 1; i < x.length; i++) {
        var skip = false;
        var ff = unescape.convert((x[i].title() as String).trim());
        if (ff.contains('Ch.')) {
          ff = ff.split('Ch.')[0];
        } else if (ff.contains('ch.')) {
          ff = ff.split('ch.')[0];
        }
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

  Future<List<QueryResult>> query() async {
    final token = '${widget.type.name}:${widget.name.replaceAll(' ', '_')}';
    final excludes = Settings.excludeTags
        .where((e) => e.trim() != '')
        .map((e) => '-$e')
        .join(' ');
    final query = HitomiManager.translate2query(
        '$token ${Settings.includeTags} $excludes');
    final qm = await QueryManager.query('$query ORDER BY Id DESC');
    return qm.results!;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);
    return Container(
      color: Palette.themeColor,
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
              color: Palette.themeColor,
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
                            const Expanded(
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
              animation: isBookmarked ? 'Like' : 'IdleUnlike',
              controller: flareController,
            ),
          ),
          Text('${widget.type.name.titlecase()}: ${widget.name}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      onTap: () async {
        isBookmarked = !isBookmarked;

        showToast(
          level: ToastLevel.check,
          message:
              '${widget.name}${Translations.instance!.trans(isBookmarked ? 'addtobookmark' : 'removetobookmark')}',
        );

        if (!isBookmarked) {
          await (await Bookmark.getInstance())
              .unbookmarkArtist(widget.name, widget.type);
          flareController.play('Unlike');
        } else {
          await (await Bookmark.getInstance())
              .bookmarkArtist(widget.name, widget.type);
          flareController.play('Like');
        }
      },
    );
  }

  bool isExpanded = false;

  Widget queryResult() {
    final width = MediaQuery.of(context).size.width;
    final maxItemCount =
        MediaQuery.of(context).orientation == Orientation.landscape ? 8 : 6;
    final axis1 = charts.AxisSpec<String>(
        renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(
                fontSize: isExpanded ? 10 : 14,
                color: charts.MaterialPalette.white),
            lineStyle: const charts.LineStyleSpec(
                color: charts.MaterialPalette.transparent)));
    const axis2 = charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
      labelStyle: charts.TextStyleSpec(
          fontSize: 10, color: charts.MaterialPalette.white),
    ));
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(64, 16, 64, 0),
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
          padding: const EdgeInsets.all(4),
        ),
        InkWell(
          child: SizedBox(
              width: width - 16 - 32,
              height:
                  isExpanded ? lff.length * 14.0 + 10 : lff.length * 22.0 + 10,
              child: charts.BarChart(
                [
                  charts.Series<Tuple2<String, int>, String>(
                      id: 'Sales',
                      data: lff,
                      domainFn: (Tuple2<String, int> sales, f) =>
                          sales.item1.contains(':')
                              ? sales.item1.split(':')[1]
                              : sales.item1,
                      measureFn: (Tuple2<String, int> sales, _) => sales.item2,
                      colorFn: (Tuple2<String, int> sales, _) {
                        if (sales.item1.startsWith('female:')) {
                          return charts.MaterialPalette.pink.shadeDefault;
                        } else if (sales.item1.startsWith('male:')) {
                          return charts.MaterialPalette.blue.shadeDefault;
                        } else {
                          return charts.MaterialPalette.gray.shadeDefault;
                        }
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
            if (isExpanded) {
              lff = lffOrigin;
            } else {
              lff = lffOrigin.take(5).toList();
            }
            setState(() {});
          },
        ),
        ExpandableNotifier(
          controller: ec,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ScrollOnExpand(
              child: ExpandablePanel(
                theme: ExpandableThemeData(
                    iconColor: Settings.themeWhat ? Colors.white : Colors.grey,
                    animationDuration: const Duration(milliseconds: 500)),
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                  child: Text(
                      '${Translations.instance!.trans('articles')} (${cc.length})'),
                ),
                expanded: Column(children: <Widget>[
                  articleArea(),
                  Visibility(
                      visible: cc.length > maxItemCount,
                      child: more(() => ArticleListPage(
                          cc: cc,
                          name:
                              '${widget.type.name.titlecase()}: ${widget.name}')))
                ]),
                collapsed: Container(),
              ),
            ),
          ),
        ),
        ExpandableNotifier(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ScrollOnExpand(
              child: ExpandablePanel(
                theme: ExpandableThemeData(
                    iconColor: Settings.themeWhat ? Colors.white : Colors.grey,
                    animationDuration: const Duration(milliseconds: 500)),
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                  child: Text(
                      '${Translations.instance!.trans('comment')} (${(comments != null ? comments!.length : 0)})'),
                ),
                expanded: commentArea(),
                collapsed: Container(),
              ),
            ),
          ),
        ),
        widget.type.isCharacter || widget.type.isSeries
            ? ExpandableNotifier(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ScrollOnExpand(
                    child: ExpandablePanel(
                      theme: ExpandableThemeData(
                          iconColor:
                              Settings.themeWhat ? Colors.white : Colors.grey,
                          animationDuration: const Duration(milliseconds: 500)),
                      header: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                        child: Text(
                            '${Translations.instance!.trans('related')} ${widget.type.isSeries ? Translations.instance!.trans('iseries') : Translations.instance!.trans('icharacter')}'),
                      ),
                      expanded: relatedArea(),
                      collapsed: Container(),
                    ),
                  ),
                ),
              )
            : Container(),
        widget.type.isCharacter || widget.type.isSeries
            ? ExpandableNotifier(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ScrollOnExpand(
                    child: ExpandablePanel(
                      theme: ExpandableThemeData(
                          iconColor:
                              Settings.themeWhat ? Colors.white : Colors.grey,
                          animationDuration: const Duration(milliseconds: 500)),
                      header: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                        child: Text(
                            '${Translations.instance!.trans('related')} ${widget.type.isCharacter ? Translations.instance!.trans('iseries') : Translations.instance!.trans('icharacter')}'),
                      ),
                      expanded: relatedSingleArea(),
                      collapsed: Container(),
                    ),
                  ),
                ),
              )
            : Container(),
        ExpandableNotifier(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ScrollOnExpand(
              child: ExpandablePanel(
                theme: ExpandableThemeData(
                    iconColor: Settings.themeWhat ? Colors.white : Colors.grey,
                    animationDuration: const Duration(milliseconds: 500)),
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                  child: Text(
                      '${Translations.instance!.trans('similar')} ${widget.type.isGroup ? Translations.instance!.trans('igroups') : widget.type.isUploader ? Translations.instance!.trans('iuploader') : widget.type.isSeries ? Translations.instance!.trans('iseries') : widget.type.isCharacter ? Translations.instance!.trans('icharacter') : Translations.instance!.trans('iartists')}'),
                ),
                expanded: similarArea(),
                collapsed: Container(),
              ),
            ),
          ),
        ),
        ExpandableNotifier(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ScrollOnExpand(
              child: ExpandablePanel(
                theme: ExpandableThemeData(
                    iconColor: Settings.themeWhat ? Colors.white : Colors.grey,
                    animationDuration: const Duration(milliseconds: 500)),
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                  child: Text(
                      '${Translations.instance!.trans('series')} (${series.length})'),
                ),
                expanded: seriesArea(),
                collapsed: Container(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  ExpandableController ec = ExpandableController();
  ExpandableController commentAreaEC = ExpandableController();

  Widget more(Widget Function() what) {
    return SizedBox(
      height: 60,
      child: InkWell(
        onTap: () async {
          PlatformNavigator.navigateSlide(context, what(), opaque: false);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Text(Translations.instance!.trans('more'))],
        ),
      ),
    );
  }

  Widget articleArea() {
    final windowWidth = MediaQuery.of(context).size.width;
    final columnCount =
        MediaQuery.of(context).orientation == Orientation.landscape ? 4 : 3;
    final maxItemCount =
        MediaQuery.of(context).orientation == Orientation.landscape ? 8 : 6;
    return LiveGrid(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      showItemInterval: const Duration(milliseconds: 50),
      showItemDuration: const Duration(milliseconds: 150),
      visibleFraction: 0.001,
      itemCount: min(cc.length, maxItemCount),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
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
              begin: const Offset(0, -0.1),
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
                      width: (windowWidth - 4.0) / columnCount,
                      thumbnailTag: const Uuid().v4(),
                      usableTabList: cc,
                    ),
                    child: const ArticleListItemWidget(),
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
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: similars.length + 1,
      itemBuilder: (BuildContext ctxt, int index) {
        if (index == similars.length) {
          return more(() => SimilarListPage(
                similarsAll: similarsAll,
                type: widget.type,
              ));
        }
        var e = similars[index];
        var qq = qrs[index];

        return ThreeArticlePanel(
          tappedRoute: () => ArtistInfoPage(
            type: widget.type,
            name: e.item1,
          ),
          title:
              ' ${e.item1} (${HitomiManager.getArticleCount(widget.type.name, e.item1).toString()})',
          count:
              '${Translations.instance!.trans('score')}: ${e.item2.toStringAsFixed(1)} ',
          articles: qq,
        );
      },
    );
  }

  Widget seriesArea() {
    var unescape = HtmlUnescape();
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: min(series.length, 6) + (series.length > 6 ? 1 : 0),
      itemBuilder: (BuildContext ctxt, int index) {
        if (index == 6) {
          return more(() => SeriesListPage(
                cc: cc,
                series: series,
              ));
        }
        var e = series[index];

        return ThreeArticlePanel(
          tappedRoute: () =>
              ArticleListPage(cc: e.map((e) => cc[e]).toList(), name: 'Series'),
          title: ' ${unescape.convert(cc[e[0]].title())}',
          count: '${e.length} ',
          articles: e.map((e) => cc[e]).toList(),
        );
      },
    );
  }

  Widget commentArea() {
    if (comments != null && comments!.isNotEmpty) {
      var children = List<Widget>.from(comments!.map((e) {
        return InkWell(
          onTap: () async {
            AlertDialog alert = AlertDialog(
              content: SelectableText(e.item3),
            );
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return alert;
              },
            );
          },
          splashColor: Colors.white,
          child: ListTile(
            title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text(e.item2.substring(0, 6)),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                          DateFormat('yyyy-MM-dd HH:mm')
                              .format(e.item1.toLocal()),
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ]),
            subtitle: Text(e.item3),
          ),
        );
      }));

      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children + [comment(context)],
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Align(
                  child: Text(
                    Translations.instance!.trans('nocomment'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            ],
          ),
          comment(context),
        ],
      );
    }
  }

  Widget comment(context) {
    return InkWell(
      onTap: () async {
        TextEditingController text = TextEditingController();
        Widget okButton = TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          child: Text(Translations.instance!.trans('ok')),
          onPressed: () async {
            if (text.text.length < 5 || text.text.length > 500) {
              await showOkDialog(context, 'Comment too short or long!',
                  Translations.instance!.trans('comment'));
              return;
            }
            await VioletCommunityAnonymous.postArtistComment(
                null, '${widget.type.name}:${widget.name}', text.text);
            await readComments();
            Navigator.pop(context, true);
          },
        );
        Widget cancelButton = TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          child: Text(Translations.instance!.trans('cancel')),
          onPressed: () {
            Navigator.pop(context, false);
          },
        );
        await showDialog(
          useRootNavigator: false,
          context: context,
          builder: (BuildContext context) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            title: Text(Translations.instance!.trans('writecomment')),
            content: TextField(
              controller: text,
              autofocus: true,
            ),
            actions: [okButton, cancelButton],
          ),
        );
      },
      splashColor: Colors.white,
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Text(Translations.instance!.trans('writecomment'))],
        ),
      ),
    );
  }

  Widget relatedArea() {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: relatedCharacterOrSeries.length + 1,
      itemBuilder: (BuildContext ctxt, int index) {
        if (index == relatedCharacterOrSeries.length) {
          return more(() => SimilarListPage(
                similarsAll: relatedCharacterOrSeriesAll,
                type: widget.type,
              ));
        }

        var e = relatedCharacterOrSeries[index];
        var qq = qrsCharacterOrSeries[index];

        return ThreeArticlePanel(
          tappedRoute: () => ArtistInfoPage(
            type: widget.type,
            name: e.item1,
          ),
          title:
              ' ${e.item1} (${HitomiManager.getArticleCount(widget.type.name, e.item1)})',
          count:
              '${Translations.instance!.trans('score')}: ${e.item2.toStringAsFixed(1)} ',
          articles: qq,
        );
      },
    );
  }

  Widget relatedSingleArea() {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: relatedCOSSingle.length + 1,
      itemBuilder: (BuildContext ctxt, int index) {
        if (index == relatedCOSSingle.length) {
          return more(() => SimilarListPage(
                similarsAll: relatedCOSSingleAll,
                type: widget.type,
              ));
        }
        var e = relatedCOSSingle[index];
        var qq = qrsCOSSingle[index];

        return ThreeArticlePanel(
          tappedRoute: () => ArtistInfoPage(
            type: widget.type,
            name: e.item1,
          ),
          title:
              ' ${e.item1} (${HitomiManager.getArticleCount(widget.type.name, e.item1)})',
          count:
              '${Translations.instance!.trans('score')}: ${e.item2.toStringAsFixed(1)} ',
          articles: qq,
        );
      },
    );
  }
}
