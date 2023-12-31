// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/v1/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabUserRecentRecords extends StatefulWidget {
  final String userAppId;

  const LabUserRecentRecords(this.userAppId, {super.key});

  @override
  State<LabUserRecentRecords> createState() => _LabUserRecentRecordsState();
}

class _LabUserRecentRecordsState extends State<LabUserRecentRecords> {
  List<Tuple2<QueryResult, int>> records = <Tuple2<QueryResult, int>>[];
  int limit = 10;
  final ScrollController _controller = ScrollController();
  FlareControls flareController = FlareControls();
  bool isBookmarked = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then(updateRercord);
  }

  Future<void> updateRercord(dummy) async {
    try {
      isBookmarked =
          await (await Bookmark.getInstance()).isBookmarkUser(widget.userAppId);

      var trecords =
          await VioletServer.userRecent(widget.userAppId, 100, limit);
      if (trecords is int || trecords == null || trecords.length == 0) return;

      var xrecords = trecords as List<Tuple3<int, int, int>>;

      var queryRaw =
          '${HitomiManager.translate2query('${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}')} AND ';

      queryRaw += '(${xrecords.map((e) => 'Id=${e.item2}').join(' OR ')})';
      var query = await QueryManager.query(queryRaw);

      if (query.results!.isEmpty) return;

      /* Statistics -- */

      lff = <Tuple2<String, int>>[];
      lffOrigin = null;
      isExpanded = false;
      femaleTags = 0;
      maleTags = 0;
      tags = 0;

      var ffstat = <String, int>{};

      for (var element in query.results!) {
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

      /* -- Statistics */

      var qr = <String, QueryResult>{};
      for (var element in query.results!) {
        qr[element.id().toString()] = element;
      }

      var result = <Tuple2<QueryResult, int>>[];
      for (var element in xrecords) {
        if (qr[element.item2.toString()] == null) {
          continue;
        }
        result.add(Tuple2<QueryResult, int>(
            qr[element.item2.toString()]!, element.item3));
      }

      records.insertAll(0, result);

      setState(() {});
    } catch (e, st) {
      Logger.error('[lab-recent_record] E: $e\n'
          '$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    var windowWidth = MediaQuery.of(context).size.width;
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: records.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.all(0),
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    itemCount: records.length + 1,
                    itemBuilder: (BuildContext ctxt, int index) {
                      if (index == 0) {
                        return _tagChart();
                      }
                      index -= 1;
                      return Align(
                        key: Key('records$index/${records[index].item1.id()}'),
                        alignment: Alignment.center,
                        child: Provider<ArticleListItem>.value(
                          value: ArticleListItem.fromArticleListItem(
                            queryResult: records[index].item1,
                            showDetail: true,
                            addBottomPadding: true,
                            width: (windowWidth - 4.0),
                            thumbnailTag: const Uuid().v4(),
                            seconds: records[index].item2,
                          ),
                          child: const ArticleListItemWidget(),
                        ),
                      );
                    },
                  )
                : const Column(
                    children: <Widget>[
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
          Row(
            children: [
              Container(width: 16),
              Text('Limit: $limit${Translations.instance!.trans('second')}'),
              Expanded(
                child: ListTile(
                  dense: true,
                  title: Align(
                    child: SliderTheme(
                      data: const SliderThemeData(
                        activeTrackColor: Colors.blue,
                        inactiveTrackColor: Color(0xffd0d2d3),
                        trackHeight: 3,
                        thumbShape:
                            RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        value: limit.toDouble(),
                        max: 180,
                        min: 0,
                        divisions: (180 - 0),
                        inactiveColor: Settings.majorColor.withOpacity(0.7),
                        activeColor: Settings.majorColor,
                        onChangeEnd: (value) async {
                          limit = value.toInt();
                          records = <Tuple2<QueryResult, int>>[];
                          setState(() {});
                          await updateRercord(null);
                        },
                        onChanged: (value) {
                          setState(() {
                            limit = value.toInt();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Chart component lists
  List<Tuple2<String, int>> lff = <Tuple2<String, int>>[];
  List<Tuple2<String, int>>? lffOrigin;
  bool isExpanded = false;
  // This is used for top color bar
  int femaleTags = 0;
  int maleTags = 0;
  int tags = 0;

  _tagChart() {
    final width = MediaQuery.of(context).size.width;
    var axis1 = charts.AxisSpec<String>(
        renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(
                fontSize: isExpanded ? 10 : 14,
                color: charts.MaterialPalette.white),
            lineStyle: const charts.LineStyleSpec(
                color: charts.MaterialPalette.transparent)));
    var axis2 = const charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
      labelStyle: charts.TextStyleSpec(
          fontSize: 10, color: charts.MaterialPalette.white),
    ));
    return Column(children: [
      Container(
        height: 16,
      ),
      GestureDetector(
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
            Text(widget.userAppId.substring(0, 16),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        onTap: () async {
          isBookmarked = !isBookmarked;

          if (!isBookmarked) {
            await (await Bookmark.getInstance())
                .unbookmarkUser(widget.userAppId);
            flareController.play('Unlike');
          } else {
            await (await Bookmark.getInstance()).bookmarkUser(widget.userAppId);
            flareController.play('Like');
          }
          setState(() {});
        },
      ),
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
            lff = lffOrigin!;
          } else {
            lff = lffOrigin!.take(5).toList();
          }
          setState(() {});
          Future.delayed(const Duration(milliseconds: 100)).then((value) =>
              _controller.animateTo(0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn));
        },
      ),
      Container(
        padding: const EdgeInsets.all(8),
      ),
    ]);
  }
}
