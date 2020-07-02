// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:auto_animated/auto_animated.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/component/hitomi/title_cluster.dart';
import 'package:violet/database.dart';
import 'package:violet/settings.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:violet/widgets/article_list_item_widget.dart';

class ArtistInfoPage extends StatefulWidget {
  final String artist;
  final bool isGroup;
  final bool isUploader;

  ArtistInfoPage({this.artist, this.isGroup, this.isUploader});

  @override
  _ArtistInfoPageState createState() => _ArtistInfoPageState();
}

class _ArtistInfoPageState extends State<ArtistInfoPage> {
  bool qureyLoaded = false;
  int femaleTags = 0;
  int maleTags = 0;
  int tags = 0;
  List<QueryResult> cc;
  List<Tuple2<String, int>> lff = List<Tuple2<String, int>>();
  List<Tuple2<String, int>> lffOrigin;
  List<Tuple2<String, double>> similars;
  List<List<QueryResult>> qrs = List<List<QueryResult>>();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      cc = await query([widget.artist, widget.isGroup, widget.isUploader]);
      var clustering = HitomiTitleCluster.doClustering(
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
      else
        similars = HitomiIndexs.calculateSimilarArtists(widget.artist);

      similars = similars.take(6).toList();

      var prefix = 'artist:';
      if (widget.isGroup)
        prefix = 'group:';
      else if (widget.isUploader) prefix = 'uploader:';

      for (int i = 0; i < similars.length; i++) {
        var postfix = similars[i].item1.toLowerCase().replaceAll(' ', '_');
        if (widget.isUploader) postfix = similars[i].item1;
        var queryString = HitomiManager.translate2query(prefix +
            postfix +
            ' ' +
            Settings.includeTags.join(' ') +
            ' ' +
            Settings.excludeTags.map((e) => '-$e').join(' '));
        final qm = QueryManager.queryPagination(queryString);
        qm.itemsPerPage = 10;

        var x = await qm.next();
        var y = [x[0]];

        var titles = [x[0].title() as String];

        for (int i = 1; i < x.length; i++) {
          var skip = false;
          var ff = x[i].title() as String;
          if (ff.contains('Ch.'))
            ff = ff.split('Ch.')[0];
          else if (ff.contains('ch.')) ff = ff.split('ch.')[0];
          for (int j = 0; j < titles.length; j++) {
            var tt = titles[j];
            if (tt.contains('Ch.'))
              tt = tt.split('Ch.')[0];
            else if (tt.contains('ch.')) tt = tt.split('ch.')[0];
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
          titles.add(ff);
        }

        qrs.add(y);
      }

      setState(() {
        qureyLoaded = true;
      });
    });
  }

  Future<List<QueryResult>> query(dynamic obj) async {
    var artist = obj[0] as String;
    var isGroup = obj[1] as bool;
    var isUploader = obj[2] as bool;

    var query = HitomiManager.translate2query(
        (isGroup ? 'group:' : isUploader ? 'uploader:' : 'artist:') +
            '${artist.replaceAll(' ', '_')}' +
            Settings.includeTags.join(' ') +
            ' ' +
            Settings.excludeTags.map((e) => '-$e').join(' '));

    // DateTime dt = DateTime.now();
    QueryManager qm = await QueryManager.query(query);
    // print((DateTime.now().difference(dt)).inSeconds);
    return qm.results;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return Padding(
      // padding: EdgeInsets.all(0),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
              height: height - 16,
              child: Container(
                child: qureyLoaded
                    ? SingleChildScrollView(
                        child: Column(
                          children: <Widget>[
                            Container(
                              height: 16,
                            ),
                            Text(
                                (widget.isGroup
                                        ? 'Groups: '
                                        : widget.isUploader
                                            ? 'Uploader: '
                                            : 'Artist: ') +
                                    widget.artist,
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            queryResult()
                          ],
                        ),
                      )
                    : Column(
                        children: <Widget>[
                          Container(
                            height: 16,
                          ),
                          Text(
                              (widget.isGroup
                                      ? 'Groups: '
                                      : widget.isUploader
                                          ? 'Uploader: '
                                          : 'Artist: ') +
                                  widget.artist,
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
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
                // child:  SingleChildScrollView(
                //   child: Column(
                //     children: <Widget>[
                //       Container(
                //         height: 16,
                //       ),
                //       Text(
                //           (widget.isGroup ? 'Groups:' : 'Artist: ') +
                //               widget.artist,
                //           style: TextStyle(
                //               fontSize: 20, fontWeight: FontWeight.bold)),
                //       qureyLoaded
                //           ? queryResult()
                //           : Expanded(
                //               child: Align(
                //                 alignment: Alignment.center,
                //                 child: SizedBox(
                //                   width: 50,
                //                   height: 50,
                //                   child: CircularProgressIndicator(),
                //                 ),
                //               ),
                //             ),
                //     ],
                //   ),
                // ),
              ),
            ),
          ),
        ],
      ),
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
                    child: Text('Articles (${cc.length})'),
                  ),
                  expanded: Container(child: Text('asdf')),
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
                    child: Text('Similar'),
                  ),
                  expanded: similarArea(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget similarArea() {
    var windowWidth = MediaQuery.of(context).size.width;
    return ListView.builder(
        padding: EdgeInsets.all(0),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: similars.length,
        itemBuilder: (BuildContext ctxt, int index) {
          var e = similars[index];
          var qq = qrs[index];
          return InkWell(
            onTap: () async {
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
                pageBuilder: (_, __, ___) => ArtistInfoPage(
                  isGroup: widget.isGroup,
                  isUploader: widget.isUploader,
                  artist: e.item1,
                ),
              ));
            },
            child: SizedBox(
              height: 192,
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
                              ' ' + e.item1 +
                                  ' (' +
                                  HitomiManager.getArticleCount(
                                          widget.isGroup
                                              ? 'group'
                                              : widget.isUploader
                                                  ? 'uploader'
                                                  : 'artist',
                                          e.item1)
                                      .toString() +
                                  ')',
                              style: TextStyle(fontSize: 17)),
                          Text('Score: ' + e.item2.toStringAsFixed(1) + ' ',
                              style: TextStyle(color: Colors.grey.shade300)),
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
                                        child: ArticleListItemVerySimpleWidget(
                                          queryResult: qq[0],
                                          showDetail: false,
                                          addBottomPadding: false,
                                          width:
                                              (windowWidth - 16 - 4.0 - 1.0) /
                                                  3,
                                        ))
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 1
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: ArticleListItemVerySimpleWidget(
                                          queryResult: qq[1],
                                          showDetail: false,
                                          addBottomPadding: false,
                                          width:
                                              (windowWidth - 16 - 4.0 - 16.0) /
                                                  3,
                                        ))
                                    : Container()),
                            Expanded(
                                flex: 1,
                                child: qq.length > 2
                                    ? Padding(
                                        padding: EdgeInsets.all(4),
                                        child: ArticleListItemVerySimpleWidget(
                                          queryResult: qq[2],
                                          showDetail: false,
                                          addBottomPadding: false,
                                          width:
                                              (windowWidth - 16 - 4.0 - 16.0) /
                                                  3,
                                        ))
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
    // Column(
    //   // mainAxisAlignment: MainAxisAlignment.start,
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: AnimationConfiguration.toStaggeredList(
    //       duration: const Duration(milliseconds: 900),
    //       childAnimationBuilder: (widget) => SlideAnimation(
    //             horizontalOffset: 50.0,
    //             child: FadeInAnimation(
    //               child: widget,
    //             ),
    //           ),
    //       children: children
    //       ),
    // ),
    // );
  }
}

// class PieSmartLabels extends StatefulWidget {
//   PieSmartLabels({this.sample, Key key}) : super(key: key);
//   SubItem sample;

//   @override
//   _PieSmartLabelsState createState() => _PieSmartLabelsState(sample);
// }

// class _PieSmartLabelsState extends State<PieSmartLabels> {
//   _PieSmartLabelsState(this.sample);
//   final SubItem sample;

//   @override
//   Widget build(BuildContext context) {
//     return getScopedModel(getSmartLabelPieChart(false), sample);
//   }
// }

class ChartSampleData {
  ChartSampleData(
      {this.x,
      this.y,
      this.xValue,
      this.yValue,
      this.yValue2,
      this.yValue3,
      this.pointColor,
      this.size,
      this.text,
      this.open,
      this.close});
  final dynamic x;
  final num y;
  final dynamic xValue;
  final num yValue;
  final num yValue2;
  final num yValue3;
  final Color pointColor;
  final num size;
  final String text;
  final num open;
  final num close;
}

SfCircularChart getSmartLabelPieChart(List<Tuple2<String, int>> ff) {
  return SfCircularChart(
    // title: ChartTitle(text: isTileView ? '' : 'Largest islands in the world'),
    series: gettSmartLabelPieSeries(ff),
    tooltipBehavior: TooltipBehavior(enable: true),
  );
}

List<PieSeries<ChartSampleData, String>> gettSmartLabelPieSeries(
    List<Tuple2<String, int>> ff) {
  // final List<ChartSampleData> chartData = <ChartSampleData>[
  //   ChartSampleData(x: 'Greenland', y: 2130800),
  //   ChartSampleData(x: 'New\nGuinea', y: 785753),
  //   ChartSampleData(x: 'Borneo', y: 743330),
  //   ChartSampleData(x: 'Madagascar', y: 587713),
  //   ChartSampleData(x: 'Baffin\nIsland', y: 507451),
  //   ChartSampleData(x: 'Sumatra', y: 443066),
  //   ChartSampleData(x: 'Honshu', y: 225800),
  //   ChartSampleData(x: 'Victoria\nIsland', y: 217291),
  // ];
  var chartData = ff
      .map((e) => ChartSampleData(
          x: e.item1,
          y: e.item2,
          pointColor: e.item1.startsWith('female:')
              ? Colors.pink
              : e.item1.startsWith('male:')
                  ? Colors.blue
                  : e.item1 == 'etc' ? Colors.grey.shade200 : Colors.grey))
      .toList();
  return <PieSeries<ChartSampleData, String>>[
    PieSeries<ChartSampleData, String>(
        dataSource: chartData,
        xValueMapper: (ChartSampleData data, _) => data.x,
        yValueMapper: (ChartSampleData data, _) => data.y,
        dataLabelMapper: (ChartSampleData data, _) => data.x,
        pointColorMapper: (ChartSampleData data, _) => data.pointColor,
        pointRadiusMapper: (ChartSampleData data, _) =>
            (data.y / ff[0].item2 * 100.0).toString() + '%',
        radius: '65%',
        startAngle: 80,
        endAngle: 80,
        dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            connectorLineSettings:
                ConnectorLineSettings(type: ConnectorType.curve)))
  ];
}
