// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/main/info/lab/artist_search/tag_group_modify.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/segment/three_article_panel.dart';
import 'package:violet/settings/settings.dart';

class ArtistSearch extends StatefulWidget {
  const ArtistSearch({super.key});

  @override
  State<ArtistSearch> createState() => _ArtistSearchState();
}

class _ArtistSearchState extends State<ArtistSearch> {
  ArtistType selectedType = ArtistType.artist;

  Map<String, int> tagGroup = {
    'female:sole_female': 10,
    'male:sole_male': 5,
    'female:big_breasts': 3,
    'male:shota': 1,
    'tag:full_color': 1,
  };

  List<(String, double)> similarsAll = [];

  ObjectKey listViewKey = ObjectKey(const Uuid().v4());

  Future<void> doMatch() async {
    final tagGroup = <String, dynamic>{};

    final tagSrcs = {
      ArtistType.artist: HitomiIndexs.tagArtist,
      ArtistType.group: HitomiIndexs.tagGroup,
      ArtistType.series: HitomiIndexs.tagSeries,
      ArtistType.character: HitomiIndexs.tagCharacter,
      ArtistType.uploader: HitomiIndexs.tagUploader,
    };

    for (var element in this.tagGroup.entries) {
      var key = element.key;

      if (key.startsWith('tag:')) {
        key = key.substring(4);
      }

      if (HitomiIndexs.tagIndex.containsKey(key)) {
        tagGroup[HitomiIndexs.tagIndex[key].toString()] = element.value;
      } else if (HitomiIndexs.tagIndex.containsKey(key.replaceAll('_', ' '))) {
        tagGroup[HitomiIndexs.tagIndex[key.replaceAll('_', ' ')].toString()] =
            element.value;
      }
    }

    print(tagGroup);

    similarsAll =
        HitomiIndexs.caclulateSimilarsManual(tagSrcs[selectedType]!, tagGroup);

    setState(() {});
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
          Container(
            padding: const EdgeInsets.all(2),
          ),
          Expanded(
            child: artistListArea(),
          ),
        ],
      ),
    );
  }

  titleArea() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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

    final forSort = tagGroup.entries.toList();
    forSort.sort((a, b) => b.value.compareTo(a.value));

    final series = charts.Series<MapEntry<String, int>, String>(
      id: 'Sales',
      data: forSort.take(5).toList(),
      domainFn: (MapEntry<String, int> sales, f) => sales.key.contains(':')
          ? sales.key.split(':')[1].replaceAll('_', ' ')
          : sales.key.replaceAll('_', ' '),
      measureFn: (MapEntry<String, int> sales, _) => sales.value,
      colorFn: (MapEntry<String, int> sales, _) {
        if (sales.key.startsWith('female:')) {
          return charts.MaterialPalette.pink.shadeDefault;
        } else if (sales.key.startsWith('male:')) {
          return charts.MaterialPalette.blue.shadeDefault;
        } else {
          return charts.MaterialPalette.gray.shadeDefault;
        }
      },
    );

    final heightMap = [
      60.0, // 1
      70.0, // 2
      85.0, // 3
      100.0, // 4
      120.0, // 5
    ];

    return InkWell(
      child: SizedBox(
        height: heightMap[min(5, tagGroup.length) - 1],
        child: charts.BarChart(
          [series],
          primaryMeasureAxis: Settings.themeWhat ? axis2 : null,
          domainAxis: Settings.themeWhat ? axis1 : null,
          animate: true,
          vertical: false,
        ),
      ),
      onTap: () {},
      onTapCancel: () async {
        final tags = await PlatformNavigator.navigateSlide<Map<String, int>>(
            context, TagGroupModify(tagGroup: tagGroup));

        if (tags != null) {
          similarsAll = [];

          setState(() {
            tagGroup = tags;
          });

          Future.delayed(const Duration(milliseconds: 100)).then((value) {
            doMatch();
          });
        }
      },
    );
  }

  typeSelector() {
    final dropDown = DropdownButton<ArtistType>(
      value: selectedType,
      items: ArtistType.values
          .map<DropdownMenuItem<ArtistType>>((ArtistType value) {
        return DropdownMenuItem<ArtistType>(
          value: value,
          child: Text(
            Translations.instance!.trans(value.name),
            style: const TextStyle(fontSize: 16),
          ),
        );
      }).toList(),
      onChanged: (ArtistType? newValue) {
        similarsAll = [];

        setState(() {
          selectedType = newValue ?? selectedType;
        });

        Future.delayed(const Duration(milliseconds: 100)).then((value) {
          doMatch();
        });
      },
    );

    return dropDown;
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
          future: artistListfuture(e.$1),
          builder: (BuildContext context,
              AsyncSnapshot<List<QueryResult>> snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 195,
              );
            }

            return ThreeArticlePanel(
              tappedRoute: () => ArtistInfoPage(
                type: selectedType,
                name: e.$1,
              ),
              title:
                  ' ${e.$1} (${HitomiManager.getArticleCount(selectedType.name, e.$1)})',
              count:
                  '${Translations.instance!.trans('score')}: ${e.$2.toStringAsFixed(1)} ',
              articles: snapshot.data!,
            );
          },
        );
      },
    );
  }

  Future<List<QueryResult>> artistListfuture(String e) async {
    final unescape = HtmlUnescape();

    final postfix = e.toLowerCase().replaceAll(' ', '_');

    final queryString = HitomiManager.translate2query(
        '${selectedType.name}:$postfix ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}');
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
