// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class ArtistListPage extends StatelessWidget {
  final List<String> artists;
  final bool isLast;

  const ArtistListPage(
      {super.key, required this.artists, required this.isLast});

  static final RegExp _chDot = RegExp('[cC]h\\.');

  Future<List<QueryResult>> _future(String e) async {
    String resolveTitle(String origin) {
      return HtmlUnescape().convert(origin.trim()).split(_chDot)[0];
    }

    final postfix = e.trim().toLowerCase().replaceAll(' ', '_');
    final queryString = HitomiManager.translate2query(
        '${isLast ? '' : 'artist:'}$postfix ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}');

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
    final mediaQuery = MediaQuery.of(context);
    final color = Palette.themeColor;

    return Container(
      color: color,
      padding: EdgeInsets.only(
        top: mediaQuery.padding.top,
        bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Card(
          elevation: 5,
          color: Palette.themeColor,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
            physics: const ClampingScrollPhysics(),
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
                          const Icon(Icons.error),
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
                    return const SizedBox(
                      height: 195,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final queryResults = snapshot.data!;
                  final articleCount =
                      HitomiManager.getArticleCount(classification, name);

                  late final ArtistType type;
                  if (isLast && classification == 'group') {
                    type = ArtistType.group;
                  } else {
                    type = ArtistType.artist;
                  }

                  return InkWell(
                    onTap: () async {
                      PlatformNavigator.navigateSlide(
                        context,
                        ArtistInfoPage(
                          type: type,
                          name: name,
                        ),
                      );
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
                thumbnailTag: const Uuid().v4(),
                disableFilter: true,
                usableTabList: queryResults,
              ),
              child: const ArticleListItemWidget(),
            );
          },
        ),
      ),
    );
  }
}
