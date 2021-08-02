// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabUserRecentRecords extends StatefulWidget {
  final String userAppId;

  LabUserRecentRecords(this.userAppId);

  @override
  _LabUserRecentRecordsState createState() => _LabUserRecentRecordsState();
}

class _LabUserRecentRecordsState extends State<LabUserRecentRecords> {
  List<Tuple2<QueryResult, int>> records = <Tuple2<QueryResult, int>>[];
  int limit = 10;
  Timer timer;
  ScrollController _controller = ScrollController();
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
      } else
        isTop = false;
    });

    Future.delayed(Duration(milliseconds: 100)).then(updateRercord).then(
        (value) => _controller.jumpTo(_controller.position.maxScrollExtent));
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Future<void> updateRercord(dummy) async {
    try {
      var trecords =
          await VioletServer.userRecent(widget.userAppId, 100, limit);
      if (trecords is int || trecords == null || trecords.length == 0) return;

      var xrecords = trecords as List<Tuple4<int, int, int, String>>;

      var queryRaw = HitomiManager.translate2query(Settings.includeTags +
              ' ' +
              Settings.excludeTags
                  .where((e) => e.trim() != '')
                  .map((e) => '-$e')
                  .join(' ')) +
          ' AND ';

      queryRaw += '(' + xrecords.map((e) => 'Id=${e.item2}').join(' OR ') + ')';
      var query = await QueryManager.query(queryRaw);

      if (query.results.length == 0) return;

      var qr = Map<String, QueryResult>();
      query.results.forEach((element) {
        qr[element.id().toString()] = element;
      });

      var result = <Tuple2<QueryResult, int>>[];
      xrecords.forEach((element) {
        if (qr[element.item2.toString()] == null) {
          return;
        }
        result.add(Tuple2<QueryResult, int>(
            qr[element.item2.toString()], element.item3));
      });

      records.insertAll(0, result);

      if (isTop) {
        setState(() {});
        Future.delayed(Duration(milliseconds: 50)).then((x) {
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
          );
        });
      } else
        setState(() {});
    } catch (e, st) {
      Logger.error(
          '[lab-recent_record] E: ' + e.toString() + '\n' + st.toString());
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
            child: records.length != 0
                ? ListView.builder(
                    padding: EdgeInsets.all(0),
                    controller: _controller,
                    physics: BouncingScrollPhysics(),
                    itemCount: records.length,
                    reverse: true,
                    itemBuilder: (BuildContext ctxt, int index) {
                      return Align(
                        key: Key('records' +
                            index.toString() +
                            '/' +
                            records[records.length - index - 1]
                                .item1
                                .id()
                                .toString()),
                        alignment: Alignment.center,
                        child: Provider<ArticleListItem>.value(
                          value: ArticleListItem.fromArticleListItem(
                            queryResult:
                                records[records.length - index - 1].item1,
                            showDetail: true,
                            addBottomPadding: true,
                            width: (windowWidth - 4.0),
                            thumbnailTag: Uuid().v4(),
                            seconds: records[records.length - index - 1].item2,
                          ),
                          child: ArticleListItemVerySimpleWidget(),
                        ),
                      );
                    },
                  )
                : Column(
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
              Text('Limit: $limit${Translations.instance.trans('second')}'),
              Expanded(
                child: ListTile(
                  dense: true,
                  title: Align(
                    child: SliderTheme(
                      data: SliderThemeData(
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
