// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:html/parser.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/util/helper.dart';

class EHBookmark {
  static List<HashSet<int>>? bookmarkInfo;
  static Future<List<HashSet<int>>> process() async {
    // https://e-hentai.org/favorites.php?page=0&favcat=0
    // https://exhentai.org/favorites.php?page=0&favcat=0

    var result = <HashSet<int>>[];

    const candidateHosts = [
      'https://exhentai.org',
      'https://e-hentai.org',
    ];

    for (final host in candidateHosts) {
      for (int i = 0; i < 10; i++) {
        var bookmark = HashSet<int>();

        await catchUnwind(() async {
          for (int j = 0; j < 1000; j++) {
            final html = await EHSession.requestString(
                '$host/favorites.php?favcat=$i&page=$j');
            final prev = bookmark.length;

            parse(html).querySelectorAll('a[href*="/g/"]').forEach((element) {
              final href = element.attributes['href'];
              if (href == null) return;
              bookmark.add(int.parse((href.split('/')[4])));
            });

            if (prev == bookmark.length) {
              break;
            }
          }
        });

        result.add(bookmark);
      }
    }

    return bookmarkInfo = result;
  }
}
