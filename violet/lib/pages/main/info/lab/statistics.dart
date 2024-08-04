// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/log/act_log.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/settings/settings.dart';

class Statistics extends StatefulWidget {
  const Statistics({super.key});

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

  Map<DateTime, int> timePerDate = <DateTime, int>{};

  int cacheCount = 0;
  int cacheSize = 0;

  Future<void> updateRercord(dummy) async {
    try {
      final articles = await User.getInstance()
          .then((value) => value.getUserLog().then((value) async {
                totalRead = value.length;
                var overap = HashSet<String>();
                var rr = <ArticleReadLog>[];
                for (var element in value) {
                  if (overap.contains(element.articleId())) continue;
                  rr.add(element);
                  overap.add(element.articleId());
                }
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
      timePerDate = <DateTime, int>{};

      var ffstat = <String, int>{};

      if (!_allowOverlap) {
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
      } else {
        final log =
            await User.getInstance().then((value) => value.getUserLog());
        final idMap = <String, QueryResult>{};
        for (var element in query.results!) {
          idMap[element.id().toString()] = element;
        }
        for (var element in log) {
          if (!idMap.containsKey(element.articleId())) continue;
          final qr = idMap[element.articleId()]!;
          if (qr.tags() == null) continue;
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
        }
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
      await cacheAnalysis();

      setState(() {});
    } catch (e, st) {
      Logger.error('[lab-statistics] E: $e\n'
          '$st');
    }
  }

  bool _alreadyLogAnalysis = false;

  Future<void> logAnalysis() async {
    if (_alreadyLogAnalysis) return;
    _alreadyLogAnalysis = true;

    await logAnalysisLog();
    await logAnalysisActLog();

    setState(() {});
  }

  Future<void> logAnalysisLog() async {
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
      final s =
          dts[stopMark[i]].difference(dts[stopMark[i + 1] - 1]).abs().inSeconds;
      if (s > 60 * 60 * 24) continue;
      totalSeconds += s;
      startUpTimes += 1;
    }
  }

  Future<void> logAnalysisActLog() async {
    final logs = await ActLogger.logFile.readAsLines();
    final events = <String, List<ActLogEvent>>{};

    for (var log in logs) {
      log = log.trim();
      if (log == '') continue;

      final hash = log.substring(0, log.indexOf(' '));
      final data = log.substring(log.indexOf(' ') + 1);
      final eve = ActLogEvent.fromJson(data);
      if (!events.containsKey(hash)) events[hash] = <ActLogEvent>[];

      events[hash]!.add(eve);
      basePureTime ??= eve.dateTime;

      if (eve.type == ActLogType.appStart || eve.type == ActLogType.appResume) {
        pureStartUpTime += 1;
      }
    }

    final minDate = DateTime.fromMicrosecondsSinceEpoch(events.entries
        .map((e) =>
            e.value.map((e) => e.dateTime!.microsecondsSinceEpoch).reduce(min))
        .reduce(min));
    final maxDate = DateTime.fromMicrosecondsSinceEpoch(events.entries
        .map((e) =>
            e.value.map((e) => e.dateTime!.microsecondsSinceEpoch).reduce(max))
        .reduce(max));

    for (var i = 0;; i++) {
      final d = DateTime(minDate.year, minDate.month, minDate.day + i);

      timePerDate[d] = 0;

      if (maxDate.difference(d).isNegative) break;
    }

    totalPureSeconds = 0;
    for (var element in events.entries) {
      var accSeconds = 0;

      bool stopAcc = false;
      DateTime? base;
      for (final eve in element.value) {
        if (eve.dateTime == null) continue;
        if (base == null) {
          base = eve.dateTime;
          continue;
        }

        if (!stopAcc) {
          final diffSec = base.difference(eve.dateTime!).abs().inSeconds;

          if (diffSec < 60) {
            accSeconds += diffSec;

            final dt = DateTime(base.year, base.month, base.day);
            if (!timePerDate.containsKey(dt)) {
              timePerDate[dt] = 0;
            }
            timePerDate[dt] = timePerDate[dt]! + diffSec;
          }
        }
        if (eve.type == ActLogType.appSuspense) stopAcc = true;
        if (eve.type == ActLogType.appStart ||
            eve.type == ActLogType.appResume) {
          stopAcc = false;
        }

        base = eve.dateTime;
      }

      totalPureSeconds += accSeconds;
    }
  }

  bool _alreadyCacheAnalysis = false;

  Future<void> cacheAnalysis() async {
    if (_alreadyCacheAnalysis) return;
    _alreadyCacheAnalysis = true;

    final dir = await getTemporaryDirectory();

    if (dir.existsSync()) {
      dir
          .listSync(recursive: true, followLinks: false)
          .forEach((FileSystemEntity entity) {
        if (entity is File) {
          cacheCount++;
          cacheSize += entity.lengthSync();
        }
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
                ? ListView(
                    padding: EdgeInsets.zero,
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _tagChart(),
                      _status(),
                      _statusChart(),
                      _heatMap(),
                    ],
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
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

  _status() {
    return Column(
      children: [
        Text('읽은 작품: ${numberWithComma(totalRead)}개'),
        Text('읽은 작품 (중복없음): ${numberWithComma(pureRead)}개'),
        Text('로그 파일 크기: ${formatBytes(logSize, 2)}'),
        Container(height: 15),
        Text('캐시 파일 수: ${numberWithComma(cacheCount)}개'),
        Text('캐시 크기: ${formatBytes(cacheSize, 2)}'),
        Container(height: 15),
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

  String yvalue = '';

  _statusChart() {
    final seriesList = charts.Series<Tuple2<DateTime, int>, DateTime>(
      id: 'time',
      colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
      domainFn: (v, _) => v.item1,
      measureFn: (v, _) => v.item2,
      data: timePerDate.entries
          .map((e) => Tuple2<DateTime, int>(e.key, e.value ~/ 60))
          .toList(),
    );
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          height: 150,
          child: charts.TimeSeriesChart(
            [seriesList],
            animate: true,
            defaultRenderer: charts.LineRendererConfig(includePoints: true),
            dateTimeFactory: const charts.LocalDateTimeFactory(),
            behaviors: [
              charts.SelectNearest(
                  eventTrigger: charts.SelectionTrigger.tapAndDrag),
              charts.LinePointHighlighter(
                  symbolRenderer: TextSymbolRenderer(() => yvalue))
            ],
            selectionModels: [
              charts.SelectionModelConfig(
                  changedListener: (charts.SelectionModel model) {
                if (model.hasDatumSelection) {
                  final d = model.selectedSeries[0]
                      .domainFn(model.selectedDatum[0].index) as DateTime;

                  yvalue = '${d.month}/${d.day}, '
                      '${model.selectedSeries[0].measureFn(model.selectedDatum[0].index)}분';
                }
              })
            ],
          ),
        )
      ],
    );
  }

  _heatMap() {
    return Card(
      margin: const EdgeInsets.all(20),
      elevation: 20,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: HeatMap(
          datasets: timePerDate,
          colorMode: ColorMode.opacity,
          startDate: timePerDate.entries.map((e) => e.key).reduce(
              ((value, element) =>
                  value.compareTo(element) < 0 ? value : element)),
          showText: false,
          scrollable: true,
          onClick: (value) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(value.toString())));
          },
          colorsets: {1: Settings.majorColor},
        ),
      ),
    );
  }
}

typedef GetText = String Function();

class TextSymbolRenderer extends charts.CircleSymbolRenderer {
  TextSymbolRenderer(this.getText,
      {this.marginBottom = 8, this.padding = const EdgeInsets.all(8)});

  final GetText getText;
  final double marginBottom;
  final EdgeInsets padding;

  @override
  void paint(charts.ChartCanvas canvas, Rectangle<num> bounds,
      {List<int>? dashPattern,
      charts.Color? fillColor,
      charts.FillPatternType? fillPattern,
      charts.Color? strokeColor,
      double? strokeWidthPx}) {
    super.paint(canvas, bounds,
        dashPattern: dashPattern,
        fillColor: fillColor,
        fillPattern: fillPattern,
        strokeColor: strokeColor,
        strokeWidthPx: strokeWidthPx);

    final textStyle = canvas.graphicsFactory.createTextPaint()
      ..color = charts.Color.black
      ..fontSize = 15;

    final textElement = canvas.graphicsFactory.createTextElement(getText.call())
      ..textStyle = textStyle;

    double width = textElement.measurement.horizontalSliceWidth;
    double height = textElement.measurement.verticalSliceWidth;

    double centerX = bounds.left + bounds.width / 2;
    double centerY = bounds.top +
        bounds.height / 2 -
        marginBottom -
        (padding.top + padding.bottom);

    canvas.drawRRect(
      Rectangle(
        centerX - (width / 2) - padding.left,
        centerY - (height / 2) - padding.top,
        width + (padding.left + padding.right),
        height + (padding.top + padding.bottom),
      ),
      fill: charts.Color.white,
      radius: 16,
      roundTopLeft: true,
      roundTopRight: true,
      roundBottomRight: true,
      roundBottomLeft: true,
    );
    canvas.drawText(
      textElement,
      (centerX - (width / 2)).round(),
      (centerY - (height / 2)).round(),
    );
  }
}

// class CustomCircleSymbolRenderer extends charts.CircleSymbolRenderer {
//   @override
//   void paint(
//     charts.ChartCanvas canvas,
//     Rectangle<num> bounds, {
//     List<int>? dashPattern,
//     charts.Color? fillColor,
//     charts.FillPatternType? fillPattern,
//     charts.Color? strokeColor,
//     double? strokeWidthPx,
//   }) {
//     super.paint(canvas, bounds,
//         dashPattern: dashPattern,
//         fillColor: fillColor,
//         strokeColor: strokeColor,
//         strokeWidthPx: strokeWidthPx);
//     canvas.drawRect(
//         Rectangle(bounds.left - 5, bounds.top - 30, bounds.width + 10,
//             bounds.height + 10),
//         fill: charts.Color.white);
//     var textStyle = style.TextStyle();
//     textStyle.color = charts.Color.black;
//     textStyle.fontSize = 15;
//     canvas.drawText(TextElement("1", style: textStyle), (bounds.left).round(),
//         (bounds.top - 28).round());
//   }
// }
