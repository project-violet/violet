// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:violet/pages/segment/three_article_panel.dart';
import 'package:violet/settings/settings.dart';

class ArtistSearch extends StatefulWidget {
  const ArtistSearch({super.key});

  @override
  State<ArtistSearch> createState() => _ArtistSearchState();
}

class _ArtistSearchState extends State<ArtistSearch> {
  String selectedType = 'artists';

  static const testTagGroup = {
    'tag:tankoubon': 16,
    'female:ffm_threadsome': 10,
    'female:loli': 4,
    'male:shota': 3,
    'male:yaoi': 1,
  };

  final testLff =
      testTagGroup.entries.map((e) => Tuple2(e.key, e.value)).toList();

  List<Tuple2<String, double>> similarsAll = [];

  ObjectKey listViewKey = ObjectKey(const Uuid().v4());

  Future<void> doMatch() async {
    final tagGroup = <String, dynamic>{};

    final tagSrcs = {
      'artists': HitomiIndexs.tagArtist,
      'groups': HitomiIndexs.tagGroup,
      'series': HitomiIndexs.tagSeries,
      'character': HitomiIndexs.tagCharacter,
      'uploader': HitomiIndexs.tagUploader,
    };

    testTagGroup.entries.forEach((element) {
      var key = element.key;

      if (key.startsWith('tag:')) {
        key = key.substring(5);
      }

      if (HitomiIndexs.tagIndex.containsKey(key)) {
        tagGroup[HitomiIndexs.tagIndex[key].toString()] = element.value;
      } else if (HitomiIndexs.tagIndex
          .containsKey(element.key.replaceAll('_', ' '))) {
        tagGroup[HitomiIndexs.tagIndex[key.replaceAll('_', ' ')].toString()] =
            element.value;
      }
    });

    similarsAll =
        HitomiIndexs.caclulateSimilarsManual(tagSrcs[selectedType]!, tagGroup);

    print(similarsAll);

    setState(() {});
  }

  Future<List<QueryResult>> query(String artist) async {
    final query = HitomiManager.translate2query(
        '${getNormalizedType()}${selectedType != 'uploader' ? artist.replaceAll(' ', '_') : artist} '
        '${Settings.includeTags} '
        '${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}');

    QueryManager qm = await QueryManager.query('$query ORDER BY Id DESC');

    return qm.results!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      doMatch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Container(
            height: 16,
          ),
          titleArea(),
          Container(
            padding: const EdgeInsets.all(2),
          ),
          tagGroupArea(),
          Expanded(
            child: artistListArea(),
          ),
        ],
      ),
    );
  }

  titleArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text('Artist Search',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  tagGroupArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: tagChart(),
          ),
          typeSelector(),
        ],
      ),
    );
  }

  tagChart() {
    const axis1 = charts.AxisSpec<String>(
      renderSpec: charts.GridlineRendererSpec(
        labelStyle: charts.TextStyleSpec(
            fontSize: 14, color: charts.MaterialPalette.white),
        lineStyle: charts.LineStyleSpec(
          color: charts.MaterialPalette.transparent,
        ),
      ),
    );

    const axis2 = charts.NumericAxisSpec(
      renderSpec: charts.GridlineRendererSpec(
        labelStyle: charts.TextStyleSpec(
          fontSize: 10,
          color: charts.MaterialPalette.white,
        ),
      ),
    );

    final series = charts.Series<Tuple2<String, int>, String>(
      id: 'Sales',
      data: testLff,
      domainFn: (Tuple2<String, int> sales, f) =>
          sales.item1.contains(':') ? sales.item1.split(':')[1] : sales.item1,
      measureFn: (Tuple2<String, int> sales, _) => sales.item2,
      colorFn: (Tuple2<String, int> sales, _) {
        if (sales.item1.startsWith('female:')) {
          return charts.MaterialPalette.pink.shadeDefault;
        } else if (sales.item1.startsWith('male:')) {
          return charts.MaterialPalette.blue.shadeDefault;
        } else {
          return charts.MaterialPalette.gray.shadeDefault;
        }
      },
    );

    return InkWell(
      child: SizedBox(
        height: testLff.length * 22.0 + 10,
        child: charts.BarChart(
          [series],
          primaryMeasureAxis: Settings.themeWhat ? axis2 : null,
          domainAxis: Settings.themeWhat ? axis1 : null,
          animate: true,
          vertical: false,
        ),
      ),
      onTap: () {},
    );
  }

  typeSelector() {
    final dropDown = DropdownButton<String>(
      value: selectedType,
      items: <String>['artists', 'groups', 'series', 'character', 'uploader']
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            Translations.instance!.trans(value),
            style: const TextStyle(fontSize: 16),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        similarsAll = [];

        setState(() {
          selectedType = newValue ?? selectedType;
        });

        Future.delayed(Duration(milliseconds: 100)).then((value) {
          doMatch();
        });
      },
    );

    return dropDown;
  }

  String getNormalizedType() {
    if (selectedType == 'artists') {
      return 'artist';
    } else if (selectedType == 'groups') {
      return 'group';
    }
    return selectedType;
  }

  artistListArea() {
    return ListView.builder(
      key: listViewKey,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      physics: const ClampingScrollPhysics(),
      itemCount: similarsAll.length,
      itemBuilder: (BuildContext ctxt, int index) {
        final e = similarsAll[index];
        return FutureBuilder<List<QueryResult>>(
          future: artistListfuture(e.item1),
          builder: (BuildContext context,
              AsyncSnapshot<List<QueryResult>> snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 195,
              );
            }

            final type = getNormalizedType();

            return ThreeArticlePanel(
              tappedRoute: () => ArtistInfoPage(
                isGroup: type == 'group',
                isUploader: type == 'uploader',
                isCharacter: type == 'character',
                isSeries: type == 'series',
                artist: e.item1,
              ),
              title:
                  ' ${e.item1} (${HitomiManager.getArticleCount(type, e.item1)})',
              count:
                  '${Translations.of(context).trans('score')}: ${e.item2.toStringAsFixed(1)} ',
              articles: snapshot.data!,
            );
          },
        );
      },
    );
  }

  Future<List<QueryResult>> artistListfuture(String e) async {
    final unescape = HtmlUnescape();

    final prefix = getNormalizedType();
    final postfix = e.toLowerCase().replaceAll(' ', '_');

    final queryString = HitomiManager.translate2query(
        '$prefix:$postfix ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}');
    final qm = QueryManager.queryPagination(queryString);
    qm.itemsPerPage = 10;

    final x = await qm.next();
    final y = [x[0]];

    final titles = [unescape.convert((x[0].title() as String).trim())];
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

    return y;
  }
}
