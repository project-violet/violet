// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/main/info/lab/recent_user_record.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/v1/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabRecentRecordsU extends StatefulWidget {
  const LabRecentRecordsU({super.key});

  @override
  State<LabRecentRecordsU> createState() => _LabRecentRecordsUState();
}

class _LabRecentRecordsUState extends State<LabRecentRecordsU> {
  List<Tuple3<QueryResult, int, String>> records =
      <Tuple3<QueryResult, int, String>>[];
  int latestId = 0;
  int limit = 10;
  late Timer timer;
  final ScrollController _controller = ScrollController();
  bool isTop = false;

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
            (value) => _controller.animateTo(
                _controller.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn)));
    timer = Timer.periodic(const Duration(seconds: 1), updateRercord);
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Future<void> updateRercord(dummy) async {
    try {
      var trecords = await VioletServer.recordU(latestId, 10, limit);
      if (trecords is int || trecords == null || trecords.length == 0) return;

      var xrecords = trecords as List<Tuple4<int, int, int, String>>;

      latestId = max(latestId,
          xrecords.reduce((x, y) => x.item1 > y.item1 ? x : y).item1 + 1);

      var queryRaw =
          '${HitomiManager.translate2query('${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}')} AND ';

      queryRaw += '(${xrecords.map((e) => 'Id=${e.item2}').join(' OR ')})';
      var query = await QueryManager.query(queryRaw);

      if (query.results!.isEmpty) return;

      var qr = <String, QueryResult>{};
      for (var element in query.results!) {
        qr[element.id().toString()] = element;
      }

      var result = <Tuple3<QueryResult, int, String>>[];
      for (var element in xrecords) {
        if (qr[element.item2.toString()] == null) {
          continue;
        }
        result.add(Tuple3<QueryResult, int, String>(
            qr[element.item2.toString()]!, element.item3, element.item4));
      }

      records.insertAll(0, result);

      if (isTop) {
        setState(() {});
        Future.delayed(const Duration(milliseconds: 50)).then((x) {
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
          );
        });
      } else {
        setState(() {});
      }
    } catch (e, st) {
      Logger.error('[lab-recent_record] E: $e\n'
          '$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    var xrecords = records.where((x) => x.item2 > limit).toList();
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
              itemCount: xrecords.length,
              reverse: true,
              itemBuilder: (BuildContext ctxt, int index) {
                return Align(
                  key: Key(
                      'records$index/${xrecords[xrecords.length - index - 1].item1.id()}'),
                  alignment: Alignment.center,
                  child: Provider<ArticleListItem>.value(
                    value: ArticleListItem.fromArticleListItem(
                      queryResult: xrecords[xrecords.length - index - 1].item1,
                      showDetail: true,
                      addBottomPadding: true,
                      width: (windowWidth - 4.0),
                      thumbnailTag: const Uuid().v4(),
                      seconds: xrecords[xrecords.length - index - 1].item2,
                      doubleTapCallback: () => _doubleTapCallback(
                          xrecords[xrecords.length - index - 1].item3),
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

  _doubleTapCallback(String userAppId) {
    PlatformNavigator.navigateSlide(context, LabUserRecentRecords(userAppId));
  }
}
