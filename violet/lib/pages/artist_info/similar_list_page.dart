// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/three_article_panel.dart';
import 'package:violet/settings/settings.dart';

class SimilarListPage extends StatelessWidget {
  final String prefix;
  final bool isGroup;
  final bool isUploader;
  final bool isSeries;
  final bool isCharacter;
  final List<Tuple2<String, double>> similarsAll;

  const SimilarListPage({
    super.key,
    required this.prefix,
    required this.similarsAll,
    required this.isGroup,
    required this.isUploader,
    required this.isSeries,
    required this.isCharacter,
  });

  Future<List<QueryResult>> _future(String e) async {
    var unescape = HtmlUnescape();
    var postfix = e.toLowerCase().replaceAll(' ', '_');
    if (isUploader) postfix = e;
    var queryString = HitomiManager.translate2query(
        '$prefix$postfix ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}');
    final qm = QueryManager.queryPagination(queryString);
    qm.itemsPerPage = 10;

    var x = await qm.next();
    var y = [x[0]];

    var titles = [unescape.convert((x[0].title() as String).trim())];
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

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: Settings.themeWhat && Settings.themeBlack,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
        physics: const ClampingScrollPhysics(),
        itemCount: similarsAll.length,
        itemBuilder: (BuildContext ctxt, int index) {
          var e = similarsAll[index];
          return FutureBuilder<List<QueryResult>>(
            future: _future(e.item1),
            builder: (BuildContext context,
                AsyncSnapshot<List<QueryResult>> snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  height: 195,
                );
              }

              var type = 'artist';
              if (isGroup) {
                type = 'group';
              } else if (isUploader) {
                type = 'uploader';
              } else if (isSeries) {
                type = 'series';
              } else if (isCharacter) {
                type = 'character';
              }

              return ThreeArticlePanel(
                tappedRoute: () => ArtistInfoPage(
                  isGroup: isGroup,
                  isUploader: isUploader,
                  isCharacter: isCharacter,
                  isSeries: isSeries,
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
      ),
    );
  }
}
