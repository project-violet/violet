// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class ArtistListPage extends StatelessWidget {
  final List<String> artists;
  final bool isLast;

  const ArtistListPage({this.artists, this.isLast});

  static final RegExp _chDot = RegExp('[cC]h\\.');

  Future<List<QueryResult>> _future(String e) async {
    String resolveTitle(String origin) {
      return HtmlUnescape().convert(origin.trim()).split(_chDot)[0];
    }

    var postfix = e.trim().toLowerCase().replaceAll(' ', '_');
    var queryString = HitomiManager.translate2query((isLast ? '' : 'artist:') +
        postfix +
        ' ' +
        Settings.includeTags +
        ' ' +
        Settings.excludeTags
            .where((e) => e.trim() != '')
            .map((e) => '-$e')
            .join(' '));

    final queryManager = QueryManager.queryPagination(queryString);
    queryManager.itemsPerPage = 10;

    final queryResults = await queryManager.next();
    final filtered = <QueryResult>[];
    final titles = <String>[];

    for (int i = 0; i < queryResults.length; i++) {
      var skip = false;
      final iTitle = resolveTitle(queryResults[i].title() as String);

      for (int j = 0; j < titles.length; j++) {
        final jTitle = titles[j];

        if (Distance.levenshteinDistanceString(jTitle, iTitle) < 3) {
          skip = true;
          break;
        }
      }

      if (skip) continue;

      filtered.add(queryResults[i]);
      titles.add(iTitle);
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Card(
          elevation: 5,
          color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
            physics: ClampingScrollPhysics(),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];

              String classification;
              String name;

              if (isLast) {
                final tokens = artist.split(':');
                assert(tokens.length == 2);

                classification = tokens.first;
                name = tokens.last;
              } else {
                classification = 'artist';
                name = artist;
              }

              return FutureBuilder<List<QueryResult>>(
                future: _future(artist),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('Error: ${snapshot.error}');
                    print(snapshot.stackTrace);

                    return Container(
                      height: 195,
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error),
                          Text(
                            snapshot.error.toString(),
                            overflow: TextOverflow.fade,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Container(
                      height: 195,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  final queryResults = snapshot.data;
                  final articleCount =
                      HitomiManager.getArticleCount(classification, name);

                  return InkWell(
                    onTap: () async {
                      if (!Platform.isIOS) {
                        Navigator.of(context).push(PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 500),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            var begin = const Offset(0.0, 1.0);
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
                            isGroup: isLast && classification == 'group',
                            isUploader: false,
                            artist: name,
                          ),
                        ));
                      } else {
                        Navigator.of(context).push(CupertinoPageRoute(
                          builder: (_) => ArtistInfoPage(
                            isGroup: false,
                            isUploader: false,
                            artist: artist,
                          ),
                        ));
                      }
                    },
                    child: Container(
                      height: 195,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            articleCount != null
                                ? ' $artist ($articleCount)'
                                : ' $artist',
                            style: const TextStyle(fontSize: 17),
                          ),
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                _buildImage(queryResults, 0),
                                _buildImage(queryResults, 1),
                                _buildImage(queryResults, 2),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImage(List<QueryResult> queryResults, int index) {
    if (queryResults.length <= index) {
      return const Spacer();
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            assert(constraints.minWidth == constraints.maxWidth);
            final width = (constraints.minWidth + constraints.maxWidth) / 2;

            return Provider<ArticleListItem>.value(
              value: ArticleListItem.fromArticleListItem(
                queryResult: queryResults[index],
                showDetail: false,
                addBottomPadding: false,
                width: width,
                thumbnailTag: Uuid().v4(),
                disableFilter: true,
                usableTabList: queryResults,
              ),
              child: ArticleListItemVerySimpleWidget(),
            );
          },
        ),
      ),
    );
  }
}
