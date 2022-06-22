// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/log/act_log.dart';
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

  int logSize = 0;
  int startUpTimes = 0;
  int totalSeconds = 0;
  DateTime? baseTime;

  DateTime? basePureTime;
  int pureStartUpTime = 0;
  int totalPureSeconds = 0;

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
          'Id IN (${articles.map((e) => e.articleId()).join(',')})';
      final query = await QueryManager.query(queryRaw);

      if (query.results!.isEmpty) return;

      /* -- Statistics -- */

      lff = <Tuple2<String, int>>[];
      lffOrigin = null;
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
      if (!isExpanded) {
        lff = lff.take(5).toList();
      }

      if (femaleTags + maleTags + tags == 0) tags = 0;

      await logAnalysis();

      setState(() {});
    } catch (e, st) {
      Logger.error('[lab-statistics] E: $e\n'
          '$st');
    }
  }

  bool _alreadyLogAnalysis = false;

  Future<void> logAnalysis() async {
    {
      if (_alreadyLogAnalysis) return;
      _alreadyLogAnalysis = true;

      /* -- Logs -- */

      logSize = await Logger.logFile.length();

      const chunkSize = 64 * 1024 * 1024;
      final chunkStarts = List.generate(
          (logSize / chunkSize.toDouble()).ceil(), (i) => i * chunkSize);
      final raf = await Logger.logFile.open(mode: FileMode.read);

      final dts = <DateTime>[];
      final stopMark = <int>[];

      var latestStopMarkPos = 0;

      for (var chunkStart in chunkStarts) {
        await raf.setPosition(chunkStart);
        final data = await raf.read(chunkSize);
        final str = String.fromCharCodes(data);

        for (final line in str.split('\n')) {
          if (line.startsWith('[')) {
            final dt = DateTime.tryParse(line.split('[')[1].split(']')[0]);
            if (dt != null) dts.add(dt);

            baseTime ??= dt;

            if (line.contains(
                'https://raw.githubusercontent.com/violet-dev/sync-data/master/syncversion.txt')) {
              stopMark.add(latestStopMarkPos);
            } else if (line.contains(
                'https://raw.githubusercontent.com/project-violet/scripts/main/hitomi_get_image_list_v3.js')) {
              latestStopMarkPos = dts.length - 1;
            }
          }
        }
      }

      final marker = List<int>.generate(dts.length, (index) => index);

      // for (var i = 0, c = 0; i < dts.length; i++) {
      //   final bs = binarySearch(stopMark, i);
      //   if (bs >= 0 && stopMark[bs] == i) {
      //     c++;
      //   }
      //   marker[i] = c;
      // }

      for (var i = 0, c = 0; i < dts.length; i++) {
        if (c < stopMark.length && stopMark[c] == i) c++;
        marker[i] = c;
      }

      totalSeconds = 0;
      startUpTimes = 0;
      for (var i = 0; i < stopMark.length - 1; i++) {
        final s = dts[stopMark[i]]
            .difference(dts[stopMark[i + 1] - 1])
            .abs()
            .inSeconds;
        if (s > 60 * 60 * 24) continue;
        totalSeconds += s;
        startUpTimes += 1;
      }
    }
    {
      final logs = await ActLogger.logFile.readAsLines();
      final events = <String, List<ActLogEvent>>{};

      for (final log in logs) {
        final hash = log.substring(0, log.indexOf(' '));
        final data = log.substring(log.indexOf(' ') + 1);
        final eve = ActLogEvent.fromJson(data);

        if (!events.containsKey(hash)) events[hash] = <ActLogEvent>[];

        events[hash]!.add(eve);
        basePureTime ??= eve.dateTime;

        if (eve.type == ActLogType.appStart ||
            eve.type == ActLogType.appResume) {
          pureStartUpTime += 1;
        }
      }

      totalPureSeconds = 0;
      events.entries.forEach((element) {
        var accSeconds = 0;

        if (element.value.first.type != ActLogType.appStart) return;

        bool stopAcc = false;
        DateTime? base;
        for (final eve in element.value) {
          if (eve.dateTime == null) continue;
          if (base == null) {
            base = eve.dateTime;
            continue;
          }

          if (!stopAcc) {
            accSeconds = base.difference(eve.dateTime!).abs().inSeconds;
          }
          if (eve.type == ActLogType.appSuspense) stopAcc = true;
          if (eve.type == ActLogType.appResume) stopAcc = false;

          base = eve.dateTime;
        }

        totalPureSeconds += accSeconds;
      });
    }

    setState(() {});
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
                      return _status();
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

  String durationToString(Duration duration) {
    var result = '';
    if (duration.inDays > 0) result += '${duration.inDays}일 ';
    if (duration.inHours > 0) {
      result += '${duration.inHours.remainder(24)}시간 ';
    }
    if (duration.inMinutes > 0) {
      result += '${duration.inMinutes.remainder(60)}분 ';
    }
    if (duration.inSeconds > 0) {
      result += '${duration.inSeconds.remainder(60)}초';
    }
    return result;
  }

  static String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  String numberWithComma(int param) {
    return NumberFormat('###,###,###,###').format(param).replaceAll(' ', '');
  }

  _status() {
    return Column(
      children: [
        Text('읽은 작품: ${numberWithComma(totalRead)}개'),
        Text('읽은 작품 (중복없음): ${numberWithComma(pureRead)}개'),
        Text('로그 파일 크기: ${formatBytes(logSize, 2)}'),
        Container(height: 30),
        Text('앱 시작 횟수: ${numberWithComma(startUpTimes)}번'),
        Text('앱 실행 시간: ${durationToString(Duration(seconds: totalSeconds))}'),
        const Text(
          '* 백그라운드 포함',
          style: TextStyle(fontSize: 13.0),
        ),
        Text(
          '* 기준: $baseTime 부터',
          style: const TextStyle(fontSize: 13.0),
        ),
        Container(height: 30),
        Text('앱 전환 횟수: ${numberWithComma(pureStartUpTime)}번'),
        Text(
            '순수 앱 사용 시간: ${durationToString(Duration(seconds: totalPureSeconds))}'),
        Text(
          '* 기준: $basePureTime 부터',
          style: const TextStyle(fontSize: 13.0),
        ),
      ],
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
          Text('나의 통계',
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
