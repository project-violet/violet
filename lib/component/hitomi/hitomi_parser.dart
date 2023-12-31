// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';

class HitomiParser {
  // Extract only title and artists
  static Future<Map<String, dynamic>> parseGalleryBlock(String html) async {
    var doc = (await compute(parse, html)).querySelector('div');

    var title = doc!.querySelector('h1')!.text.trim();
    var artists = ['N/A'];
    var language = 'N/A';
    List<String> series = [];
    List<String> tags = [];
    String type = 'N/A';
    // var character;
    // var group;
    // Group and Character is not available in "related galleries"(galleryblock) in hitomi.la

    try {
      artists = doc
          .querySelector('div.artists-list')!
          .querySelectorAll('li')
          .map((e) => e.querySelector('a')!.text.trim())
          .toList();
    } catch (_) {
      try {
        artists = doc
            .querySelector('div.artist-list')!
            .querySelectorAll('li')
            .map((e) => e.querySelector('a')!.text.trim())
            .toList();
      } catch (__) {}
    }

    doc.querySelectorAll('tr').forEach((tabRow) {
      final key = tabRow.nodes
          .firstWhere((node) => node.text?.trim().isNotEmpty ?? false)
          .text
          ?.trim();
      final value = tabRow.nodes
          .lastWhere((node) => node.text?.trim().isNotEmpty ?? false);
      switch (key) {
        // case 'Group':
        //   group;
        //   break;
        // case 'Character':
        //   character;
        //   break;
        case 'Type':
          try {
            type = value.text?.trim() ?? 'N/A';
          } catch (_) {}
          break;
        case 'Language':
          language;
          try {
            language = value.nodes
                    .firstWhere((node) => node.text?.trim().isNotEmpty ?? false)
                    .attributes['href'] ??
                'N/A';
            if (language == 'N/A') break;
            language =
                language.replaceAll('/index-', '').replaceAll('.html', '');
          } catch (_) {}
          break;
        case 'Series':
          series;
          try {
            var ul = value.nodes
                .firstWhere((node) => node.text?.trim().isNotEmpty ?? false);
            ul.nodes
                .where((node) => node.text?.trim().isNotEmpty ?? false)
                .forEach((li) {
              li.nodes
                  .where((node) => node.text?.trim().isNotEmpty ?? false)
                  .forEach((a) {
                a.nodes
                    .where((node) => node.text?.trim().isNotEmpty ?? false)
                    .forEach((text) {
                  if (text.text?.trim().isEmpty ?? true) return;
                  series.add(text.text?.trim() ?? '');
                });
              });
            });
          } catch (_) {}
          break;
        case 'Tags':
          tags;
          try {
            var ul = value.nodes
                .firstWhere((node) => node.text?.trim().isNotEmpty ?? false);
            ul.nodes
                .where((node) => node.text?.trim().isNotEmpty ?? false)
                .forEach((li) {
              li.nodes
                  .where((node) => node.text?.trim().isNotEmpty ?? false)
                  .forEach((a) {
                var tag = a.attributes['href']
                    ?.replaceAll('/tag/', '')
                    .replaceAll('-all.html', '')
                    .replaceAll('%3A', ':')
                    .replaceAll('%20', ' ');
                if (tag == null) return;
                if (!tag.contains(':')) {
                  tag = 'tag:$tag';
                }
                tags.add(tag);
              });
            });
          } catch (_) {}
          break;
      }
    });

    return {
      'Title': title,
      'Artists': artists,
      'Language': language,
      'Tags': tags,
      'Type': type,
      'Series': series
    };
  }
}
