// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/settings/settings.dart';

class Statistics extends StatefulWidget {
  const Statistics({Key? key}) : super(key: key);

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  final ScrollController _controller = ScrollController();
  bool _allowOverlap = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then(updateRercord);
  }

  int totalRead = 0;
  int pureRead = 0;

  Future<void> updateRercord(dummy) async {
    try {
      final articles = await User.getInstance()
          .then((value) => value.getUserLog().then((value) async {
                totalRead = value.length;
                var overap = HashSet<String>();
                var rr = <ArticleReadLog>[];
                value.forEach((element) {
                  if (overap.contains(element.articleId())) return;
                  rr.add(element);
                  overap.add(element.articleId());
                });
                pureRead = rr.length;
                return rr;
              }));

      final queryRaw =
          '${HitomiManager.translate2query('${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}')} AND '
          '(${articles.map((e) => 'Id=${e.articleId()}').join(' OR ')})';
      final query = await QueryManager.query(queryRaw);

      if (query.results!.isEmpty) return;

      /* Statistics -- */

      lff = <Tuple2<String, int>>[];
      lffOrigin = null;
      isExpanded = false;
      femaleTags = 0;
      maleTags = 0;
      tags = 0;

      var ffstat = <String, int>{};

      if (!_allowOverlap) {
        query.results!.forEach((element) {
          if (element.tags() == null) return;
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
        });
      } else {
        final log =
            await User.getInstance().then((value) => value.getUserLog());
        final idMap = <String, QueryResult>{};
        query.results!.forEach((element) {
          idMap[element.id().toString()] = element;
        });
        log.forEach((element) {
          if (!idMap.containsKey(element.articleId())) return;
          final qr = idMap[element.articleId()]!;
          if (qr.tags() == null) return;
          (qr.tags() as String)
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
        });
      }

      ffstat.forEach((key, value) {
        lff.add(Tuple2<String, int>(key, value));
      });
      lff.sort((x, y) => y.item2.compareTo(x.item2));

      lffOrigin = lff;
      lff = lff.take(5).toList();

      if (femaleTags + maleTags + tags == 0) tags = 0;

      setState(() {});
    } catch (e, st) {
      Logger.error('[lab-statistics] E: $e\n'
          '$st');
    }
  }

  // Chart component lists
  List<Tuple2<String, int>> lff = <Tuple2<String, int>>[];
  List<Tuple2<String, int>>? lffOrigin;
  bool isExpanded = false;
  // This is used for top color bar
  int femaleTags = 0;
  int maleTags = 0;
  int tags = 0;

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: lff.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.all(0),
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    itemCount: 2,
                    itemBuilder: (BuildContext ctxt, int index) {
                      if (index == 0) {
                        return _tagChart();
                      }
                      return Column(
                        children: [
                          Text('Total Read: $totalRead'),
                          Text('Total Read (no overlap): $pureRead'),
                        ],
                      );
                    },
                  )
                : Column(
                    children: const <Widget>[
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
              Expanded(
                child: CheckboxListTile(
                  dense: true,
                  title: const Text('Allow Overlap'),
                  value: _allowOverlap,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    if (value != null) {
                      _allowOverlap = value;
                      Future.delayed(const Duration(milliseconds: 100))
                          .then(updateRercord);
                      setState(() {});
                    }
                  },
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

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
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('My Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
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
