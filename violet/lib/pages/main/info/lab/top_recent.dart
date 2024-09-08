// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabTopRecent extends StatefulWidget {
  const LabTopRecent({super.key});

  @override
  State<LabTopRecent> createState() => _LabTopRecentState();
}

class _LabTopRecentState extends State<LabTopRecent> {
  List<(QueryResult, int)> records = <(QueryResult, int)>[];
  int limit = 10;
  Timer? timer;
  final ScrollController _controller = ScrollController();
  bool isTop = false;
  String desc = '로딩';

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      if (_controller.position.atEdge) {
        if (_controller.position.pixels == 0) {
          isTop = false;
        } else {
          isTop = true;
        }
      } else {
        isTop = false;
      }
    });

    Future.delayed(const Duration(milliseconds: 100)).then(updateRercord).then(
        (value) => Future.delayed(const Duration(milliseconds: 100)).then(
            (value) => _controller.animateTo(0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn)));
  }

  Future<void> updateRercord(dummy) async {
    try {
      var trecords = await VioletServer.topRecent(limit);
      if (trecords is int || trecords == null || trecords.length == 0) return;

      var xrecords = trecords as List<(int, int)>;

      var queryRaw =
          '${HitomiManager.translate2query('${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}')} AND ';

      queryRaw += 'Id IN (${xrecords.map((e) => e.$1).join(',')})';
      var query = await QueryManager.query(queryRaw);

      if (query.results!.isEmpty) return;

      var qr = <String, QueryResult>{};
      for (var element in query.results!) {
        qr[element.id().toString()] = element;
      }

      var result = <(QueryResult, int)>[];
      for (var element in xrecords) {
        if (qr[element.$1.toString()] == null) {
          continue;
        }
        result.add((qr[element.$1.toString()]!, element.$2));
      }

      records = result;

      setState(() {});
      Future.delayed(const Duration(milliseconds: 50)).then((x) {
        _controller.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
        );
      });

      var sts = (await VioletServer.topTs(limit)) as DateTime;
      var cts = (await VioletServer.curTs()) as DateTime;

      var x = cts.difference(sts);

      setState(() {
        if (x.inHours > 0) {
          desc = '${x.inHours}시간';
        } else if (x.inMinutes > 0) {
          desc = '${x.inMinutes}분';
        } else if (x.inSeconds > 0) {
          desc = '${x.inSeconds}초';
        } else {
          desc = '?';
        }
      });
    } catch (e, st) {
      Logger.error('[lab-top_recent] E: $e\n'
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
            child: ListView.builder(
              padding: const EdgeInsets.all(0),
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              itemCount: records.length,
              itemBuilder: (BuildContext ctxt, int index) {
                return Align(
                  key: Key('records$index/${records[index].$1.id()}'),
                  alignment: Alignment.center,
                  child: Provider<ArticleListItem>.value(
                    value: ArticleListItem.fromArticleListItem(
                      queryResult: records[index].$1,
                      showDetail: true,
                      addBottomPadding: true,
                      width: (windowWidth - 4.0),
                      thumbnailTag: const Uuid().v4(),
                      viewed: records[index].$2,
                    ),
                    child: const ArticleListItemWidget(),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Container(width: 16),
              Text('Limit: $limit($desc)'),
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
                        max: 30000,
                        min: 1,
                        divisions: (30000 - 1),
                        inactiveColor: Settings.majorColor.withOpacity(0.7),
                        activeColor: Settings.majorColor,
                        onChangeEnd: (value) async {
                          limit = value.toInt();
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
}
