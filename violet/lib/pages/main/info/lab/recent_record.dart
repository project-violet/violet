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
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabRecentRecords extends StatefulWidget {
  @override
  _LabRecentRecordsState createState() => _LabRecentRecordsState();
}

class _LabRecentRecordsState extends State<LabRecentRecords> {
  List<Tuple2<QueryResult, int>> records = <Tuple2<QueryResult, int>>[];
  int latestId = 0;
  Timer timer;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100)).then(updateRercord);
    timer = Timer.periodic(Duration(seconds: 1), updateRercord);
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Future<void> updateRercord(dummy) async {
    try {
      var trecords = await VioletServer.record(latestId);
      if (trecords is int || trecords == null || trecords.length == 0) return;

      var xrecords = trecords as List<Tuple3<int, int, int>>;

      latestId = max(latestId,
          xrecords.reduce((x, y) => x.item1 > y.item1 ? x : y).item1 + 1);

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
            child: ListView.builder(
              physics: BouncingScrollPhysics(),
              itemCount: records.length,
              itemBuilder: (BuildContext ctxt, int index) {
                return Align(
                  key: Key('records' +
                      index.toString() +
                      '/' +
                      records[index].item1.id().toString()),
                  alignment: Alignment.center,
                  child: Provider<ArticleListItem>.value(
                    value: ArticleListItem.fromArticleListItem(
                      queryResult: records[index].item1,
                      showDetail: true,
                      addBottomPadding: true,
                      width: (windowWidth - 4.0),
                      thumbnailTag: Uuid().v4(),
                      seconds: records[index].item2,
                    ),
                    child: ArticleListItemVerySimpleWidget(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
