// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:html/parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/eh/eh_provider.dart';
import 'package:violet/component/hisoki/hisoki_getter.dart';
import 'package:violet/component/hisoki/hisoki_provider.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/hitomi_parser.dart';
import 'package:violet/component/hitomi/hitomi_provider.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';

class SearchResult {
  final List<QueryResult> results;
  final int offset;
  final int? next;

  const SearchResult({required this.results, required this.offset, this.next});
}

//
// Hentai Component
// Search and Image Download Method
//
// 1. Search
//    - From Database
//    - From Web
//    require info: title, id, pages
//          option: thumbnail, url
//    this function is implemented on `search` method
//
// 2. Image donwload
//    require info: Images
//          option: Header (Most sites only need 0 or 1 header for all images)
//    this funciton is implemented on `getImageListFromEHId` method
//
class HentaiManager {
  // <Query Results, next offset>
  // if next offset == 0, then search start
  // if next offset == -1, then search end
  static Future<SearchResult> search(String what,
      [int offset = 0, int next = 0]) async {
    int? no = int.tryParse(what);
    // is Id Search?
    if (no != null) {
      return await idSearch(what);
    }
    // is random pick?
    else if (what.split(' ').any((x) => x == 'random') ||
        what.split(' ').any((x) => x.startsWith('random:'))) {
      return await _randomSearch(what, offset);
    }
    // is db search?
    else if (!Settings.searchNetwork) {
      return await _dbSearch(what, offset);
    }
    // is web search?
    else {
      return await _networkSearch(what, offset, next);
    }
  }

  static Future<SearchResult> idSearch(String what) async {
    final queryString = HitomiManager.translate2query(what);
    final queryResult = (await (await DataBaseManager.getInstance())
            .query('$queryString ORDER BY Id DESC LIMIT 1 OFFSET 0'))
        .map((e) => QueryResult(result: e))
        .toList();

    if (queryResult.isNotEmpty) {
      return SearchResult(results: queryResult, offset: -1);
    }

    try {
      return await idSearchHitomi(what);
    } catch (e, st) {
      Logger.error('[hentai-idSearch] E: $e\n'
          '$st');
      try {
        return await idSearchEhentai(what);
      } catch (e, st) {
        Logger.error('[hentai-idSearch] E: $e\n'
            '$st');
        try {
          return await idSearchExhentai(what);
        } catch (e, st) {
          Logger.error('[hentai-idSearch] E: $e\n'
              '$st');
        }
      }
    }

    return const SearchResult(results: [], offset: -1);
  }

  static Future<SearchResult> idSearchHitomi(String what) async {
    final id = int.parse(what);
    final headers =
        await ScriptManager.runHitomiGetHeaderContent(id.toString());
    final hh = await http.get('https://ltn.hitomi.la/galleryblock/$id.html',
        headers: headers);
    final article = await HitomiParser.parseGalleryBlock(hh.body);
    final meta = {
      'Id': id,
      'Title': article['Title'],
      'Artists': article['Artists']?.join('|'),
      'Language': article['Language'],
    };
    return SearchResult(results: [QueryResult(result: meta)], offset: -1);
  }

  static Future<SearchResult> idSearchEhentai(String what) async {
    final id = int.parse(what);
    String? hash;
    try {
      final listHtml = await EHSession.requestString(
          'https://e-hentai.org/?next=${(id + 1)}');
      final href = parse(listHtml)
          .querySelector('a[href*="/g/$id/"]')
          ?.attributes['href'];
      hash = href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
    } catch (e, st) {
      Logger.error('[idSearchEhentai] $e\n'
          '$st');
      if (e.toString().contains('Connection reset by peer')) {
        rethrow;
      }
    }
    if (hash == null) {
      try {
        // Expunged
        final listHtml = await EHSession.requestString(
            'https://e-hentai.org/?next=${(id + 1)}&f_sh=on');
        final href = parse(listHtml)
            .querySelector('a[href*="/g/$id/"]')
            ?.attributes['href'];
        hash =
            href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
      } catch (e, st) {
        Logger.error('[idSearchEhentai] $e\n'
            '$st');
        if (e.toString().contains('Connection reset by peer')) {
          rethrow;
        }
      }
    }
    if (hash == null) throw 'Cannot find hash';
    final html = await EHSession.requestString(
        'https://e-hentai.org/g/$id/$hash/?p=0&inline_set=ts_m');
    final articleEh = EHParser.parseArticleData(html);
    final meta = {
      'Id': id,
      'EHash': hash,
      'Title': articleEh.title,
      'Artists': articleEh.artist?.join('|') ?? 'N/A',
    };

    return SearchResult(results: [QueryResult(result: meta)], offset: -1);
  }

  static Future<SearchResult> idSearchExhentai(String what) async {
    final id = int.parse(what);
    String? hash;
    try {
      final listHtml = await EHSession.requestString(
          'https://exhentai.org/?next=${(id + 1)}');
      final href = parse(listHtml)
          .querySelector('a[href*="/g/$id/"]')
          ?.attributes['href'];
      hash = href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
    } catch (e, st) {
      Logger.error('[idSearchExhentai] $e\n'
          '$st');
      if (e.toString().contains('Connection reset by peer')) {
        rethrow;
      }
    }
    if (hash == null) {
      try {
        // Expunged
        final listHtml = await EHSession.requestString(
            'https://exhentai.org/?next=${(id + 1)}&f_sh=on');
        final href = parse(listHtml)
            .querySelector('a[href*="/g/$id/"]')
            ?.attributes['href'];
        hash =
            href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
      } catch (e, st) {
        Logger.error('[idSearchExhentai] $e\n'
            '$st');
        if (e.toString().contains('Connection reset by peer')) {
          rethrow;
        }
      }
    }

    if (hash == null) throw 'Cannot find hash';
    final html = await EHSession.requestString(
        'https://exhentai.org/g/$id/$hash/?p=0&inline_set=ts_m');
    final articleEh = EHParser.parseArticleData(html);
    final meta = {
      'Id': id,
      'EHash': hash,
      'Title': articleEh.title,
      'Artists': articleEh.artist?.join('|') ?? 'N/A',
    };

    return SearchResult(results: [QueryResult(result: meta)], offset: -1);
  }

  // static double _latestSeed = 0;
  static Future<SearchResult> _randomSearch(String what,
      [int offset = 0]) async {
    var wwhat = what.split(' ').where((x) => x != 'random').join(' ');
    double? seed = -1.0;
    if (what.split(' ').where((x) => x.startsWith('random:')).isNotEmpty) {
      var tseed = what
          .split(' ')
          .where((x) => x.startsWith('random:'))
          .first
          .split('random:')
          .last;
      seed = double.tryParse(tseed);

      wwhat = what.split(' ').where((x) => !x.startsWith('random:')).join(' ');

      if (seed == null) {
        Logger.error('[hentai-randomSearch] E: Seed must be double type!');

        return const SearchResult(results: [], offset: -1);
      }
    }
    final queryString = HitomiManager.translate2query(
        '$wwhat ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ').trim()}');

    // if (offset == 0 && seed < 0) _latestSeed = new Random().nextDouble() + 1;
    await Logger.info('[Database Query]\nSQL: $queryString');

    const int itemsPerPage = 500;
    final queryResult = (await (await DataBaseManager.getInstance())
            .query('$queryString ORDER BY '
                'Id * $seed - ROUND(Id * $seed - 0.5, 0) DESC'
                ' LIMIT $itemsPerPage OFFSET $offset'))
        .map((e) => QueryResult(result: e))
        .toList();

    return SearchResult(
      results: queryResult,
      offset: queryResult.length >= itemsPerPage ? offset + itemsPerPage : -1,
    );
  }

  static Future<SearchResult> _dbSearch(String what, [int offset = 0]) async {
    final queryString = HitomiManager.translate2query(
        '$what ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ').trim()}');

    await Logger.info('[Database Query]\nSQL: $queryString');

    const int itemsPerPage = 500;
    final queryResult = (await (await DataBaseManager.getInstance()).query(
            '$queryString ORDER BY Id DESC LIMIT $itemsPerPage OFFSET $offset'))
        .map((e) => QueryResult(result: e))
        .toList();

    return SearchResult(
      results: queryResult,
      offset: queryResult.length >= itemsPerPage ? offset + itemsPerPage : -1,
    );
  }

  static Future<SearchResult> _networkSearch(String what,
      [int offset = 0, int next = 0]) async {
    var route = Settings.searchRule;
    for (int i = 0; i < route.length; i++) {
      try {
        switch (route[i]) {
          case 'EHentai':
            var result = await searchEHentai(what, next);
            return SearchResult(
              results: result,
              offset: result.length >= 25 ? offset + 25 : -1,
              next: result.length >= 25 ? result.last.id() : -1,
            );
          case 'ExHentai':
            var result = await searchEHentai(what, next, true);
            return SearchResult(
              results: result,
              offset: result.length >= 25 ? offset + 25 : -1,
              next: result.length >= 25 ? result.last.id() : -1,
            );
          case 'Hitomi':
            // https://hiyobi.me/search/loli|sex
            break;
          case 'Hiyobi':
            // https://hiyobi.me/search/loli|sex
            break;
          case 'NHentai':
            break;
        }
      } catch (e, st) {
        Logger.error('[hentai-_networkSearch] E: $e\n'
            '$st');
      }
    }

    // not taken
    throw Exception('Never Taken');
  }

  static Future<int> countSearch(String what) async {
    final queryString = HitomiManager.translate2query(
        '$what ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ').trim()}');

    var count = (await (await DataBaseManager.getInstance()).query(queryString
            .replaceAll('SELECT * FROM', 'SELECT COUNT(*) AS C FROM')))
        .first['C'] as int;

    return count;
  }

  static Future<QueryResult> idQueryHitomi(String id) async {
    final headers = await ScriptManager.runHitomiGetHeaderContent(id);
    final res = await http.get(
      'https://ltn.hitomi.la/galleryblock/$id.html',
      headers: headers,
    );

    final article = await HitomiParser.parseGalleryBlock(res.body);
    final meta = {
      'Id': int.parse(id),
      'Title': article['Title'],
      'Artists': article['Artists'].join('|'),
    };
    return QueryResult(result: meta);
  }

  static Future<QueryResult> idQueryEhentai(String id) async {
    String? hash;
    try {
      final listHtml = await EHSession.requestString(
          'https://e-hentai.org/?next=${(int.parse(id) + 1)}');
      final href = parse(listHtml)
          .querySelector('a[href*="/g/$id/"]')
          ?.attributes['href'];
      hash = href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
    } catch (e, st) {
      Logger.error('[idQueryEhentai] $e\n'
          '$st');
      if (e.toString().contains('Connection reset by peer')) {
        rethrow;
      }
    }
    if (hash == null) {
      try {
        // Expunged
        final listHtml = await EHSession.requestString(
            'https://e-hentai.org/?next=${(int.parse(id) + 1)}&f_sh=on');
        final href = parse(listHtml)
            .querySelector('a[href*="/g/$id/"]')
            ?.attributes['href'];
        hash =
            href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
      } catch (e, st) {
        Logger.error('[idQueryEhentai] $e\n'
            '$st');
        if (e.toString().contains('Connection reset by peer')) {
          rethrow;
        }
      }
    }

    if (hash == null) throw 'Cannot find hash';
    final html = await EHSession.requestString(
        'https://e-hentai.org/g/$id/$hash/?p=0&inline_set=ts_m');
    final articleEh = EHParser.parseArticleData(html);
    final meta = {
      'Id': int.parse(id),
      'EHash': hash,
      'Title': articleEh.title,
      'Artists': articleEh.artist?.join('|') ?? 'N/A',
    };
    return QueryResult(result: meta);
  }

  static Future<QueryResult> idQueryExhentai(String id) async {
    String? hash;
    try {
      final listHtml = await EHSession.requestString(
          'https://exhentai.org/?next=${(int.parse(id) + 1)}');
      final href = parse(listHtml)
          .querySelector('a[href*="/g/$id/"]')
          ?.attributes['href'];
      hash = href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
    } catch (e, st) {
      Logger.error('[idQueryExhentai] $e\n'
          '$st');
      if (e.toString().contains('Connection reset by peer')) {
        rethrow;
      }
    }
    if (hash == null) {
      try {
        // Expunged
        final listHtml = await EHSession.requestString(
            'https://exhentai.org/?next=${(int.parse(id) + 1)}&f_sh=on');
        final href = parse(listHtml)
            .querySelector('a[href*="/g/$id/"]')
            ?.attributes['href'];
        hash =
            href?.split('/').where((element) => element.isNotEmpty).lastOrNull;
      } catch (e, st) {
        Logger.error('[idQueryExhentai] $e\n'
            '$st');
        if (e.toString().contains('Connection reset by peer')) {
          rethrow;
        }
      }
    }
    if (hash == null) throw 'Cannot find hash';
    final html = await EHSession.requestString(
        'https://exhentai.org/g/$id/$hash/?p=0&inline_set=ts_m');
    final articleEh = EHParser.parseArticleData(html);
    final meta = {
      'Id': int.parse(id),
      'EHash': hash,
      'Title': articleEh.title,
      'Artists': articleEh.artist?.join('|') ?? 'N/A',
    };
    return QueryResult(result: meta);
  }

  static Future<VioletImageProvider> getImageProvider(QueryResult qr) async {
    final route = Settings.routingRule;

    for (int i = 0; i < route.length; i++) {
      try {
        switch (route[i]) {
          case 'EHentai':
            {
              var ehash = qr.ehash();
              if (ehash == null) {
                try {
                  final listHtml = await EHSession.requestString(
                      'https://e-hentai.org/?next=${(qr.id() + 1)}');
                  final href = parse(listHtml)
                      .querySelector('a[href*="/g/${qr.id()}/"]')
                      ?.attributes['href'];
                  ehash = href
                      ?.split('/')
                      .where((element) => element.isNotEmpty)
                      .lastOrNull;
                } catch (e, st) {
                  Logger.error('[getImageProvider][EH] $e\n'
                      '$st');
                  if (e.toString().contains('Connection reset by peer')) {
                    rethrow;
                  }
                }
              }
              if (ehash == null) {
                try {
                  // Expunged try
                  final listHtml = await EHSession.requestString(
                      'https://e-hentai.org/?next=${(qr.id() + 1)}&f_sh=on');
                  final href = parse(listHtml)
                      .querySelector('a[href*="/g/${qr.id()}/"]')
                      ?.attributes['href'];
                  ehash = href
                      ?.split('/')
                      .where((element) => element.isNotEmpty)
                      .lastOrNull;
                } catch (e, st) {
                  Logger.error('[getImageProvider][EH] $e\n'
                      '$st');
                  if (e.toString().contains('Connection reset by peer')) {
                    rethrow;
                  }
                }
              }
              if (ehash == null) throw 'Cannot find hash';
              final html = await EHSession.requestString(
                  'https://e-hentai.org/g/${qr.id()}/$ehash/?p=0&inline_set=ts_m');
              final article = EHParser.parseArticleData(html);
              return EHentaiImageProvider(
                count: article.length,
                thumbnail: article.thumbnail,
                pagesUrl: List<String>.generate(
                    (article.length / 40).ceil(),
                    (index) =>
                        'https://e-hentai.org/g/${qr.id()}/$ehash/?p=$index'),
                isEHentai: true,
              );
            }

          case 'ExHentai':
            {
              var ehash = qr.ehash();
              if (ehash == null) {
                try {
                  final listHtml = await EHSession.requestString(
                      'https://exhentai.org/?next=${(qr.id() + 1)}');
                  final href = parse(listHtml)
                      .querySelector('a[href*="/g/${qr.id()}/"]')
                      ?.attributes['href'];
                  ehash = href
                      ?.split('/')
                      .where((element) => element.isNotEmpty)
                      .lastOrNull;
                } catch (e, st) {
                  Logger.error('[getImageProvider][EX] $e\n'
                      '$st');
                  if (e.toString().contains('Connection reset by peer')) {
                    rethrow;
                  }
                }
              }
              if (ehash == null) {
                try {
                  // Expunged try
                  final listHtml = await EHSession.requestString(
                      'https://exhentai.org/?next=${(qr.id() + 1)}&f_sh=on');
                  final href = parse(listHtml)
                      .querySelector('a[href*="/g/${qr.id()}/"]')
                      ?.attributes['href'];
                  ehash = href
                      ?.split('/')
                      .where((element) => element.isNotEmpty)
                      .lastOrNull;
                } catch (e, st) {
                  Logger.error('[getImageProvider][EX] $e\n'
                      '$st');
                  if (e.toString().contains('Connection reset by peer')) {
                    rethrow;
                  }
                }
              }
              if (ehash == null) throw 'Cannot find hash';
              final html = await EHSession.requestString(
                  'https://exhentai.org/g/${qr.id()}/$ehash/?p=0&inline_set=ts_m');
              final article = EHParser.parseArticleData(html);
              return EHentaiImageProvider(
                count: article.length,
                thumbnail: article.thumbnail,
                pagesUrl: List<String>.generate(
                    (article.length / 40).ceil(),
                    (index) =>
                        'https://exhentai.org/g/${qr.id()}/$ehash/?p=$index'),
                isEHentai: false,
              );
            }

          case 'Hitomi':
            {
              final imgList =
                  await HitomiManager.getImageList(qr.id().toString());
              if (imgList.bigThumbnails.isEmpty ||
                  imgList.bigThumbnails.isEmpty) {
                break;
              }
              return HitomiImageProvider(imgList, qr.id().toString());
            }

          case 'Hisoki':
            {
              var urls = await HisokiGetter.getImages(qr.id());
              if (urls == null || urls.isEmpty) break;
              return HisokiImageProvider(infos: urls, id: qr.id());
            }
        }
      } catch (e, st) {
        Logger.error('[hentai-getImageProvider] E: $e\n'
            '$st');
      }
    }

    throw Exception('gallery not found');
  }

  static Future<List<QueryResult>> searchEHentai(String what,
      [int next = 0, bool exh = false]) async {
    final search = Uri.encodeComponent(
        Settings.includeTagNetwork ? '${Settings.includeTags} ${what}' : what);
    final url =
        'https://e${exh ? 'x' : '-'}hentai.org/?${next == 0 ? '' : 'next=$next&'}f_cats=${Settings.searchCategory}&f_search=$search&advsearch=1&f_sname=on&f_stags=on${Settings.searchExpunged ? '&f_sh=on' : ''}&f_spf=&f_spt=';

    final cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies') ?? '';
    final html =
        (await http.get(url, headers: {'Cookie': '$cookie;sl=dm_2'})).body;

    final result = EHParser.parseReulstPageExtendedListView(html);

    return result.map((element) {
      final tag = <String>[];

      final descripts = element.descripts;

      tag.addAll(descripts?['female']?.map((e) => 'female:$e') ?? []);
      tag.addAll(descripts?['male']?.map((e) => 'male:$e') ?? []);
      tag.addAll(descripts?['misc'] ?? []);

      final map = {
        'Id': int.parse(element.url!.split('/')[4]),
        'EHash': element.url!.split('/')[5],
        'Title': element.title,
        'Artists': descripts?['artist']?.join('|') ?? 'n/a',
        'Groups': descripts?['group']?.join('|'),
        'Characters': descripts?['character']?.join('|'),
        'Series': descripts?['parody']?.join('|') ?? 'n/a',
        'Language': descripts?['language']
                ?.where((element) => !element.contains('translate'))
                .join('|') ??
            'n/a',
        'Tags': tag.join('|'),
        'Uploader': element.uploader,
        'PublishedEH': element.published,
        'Files': element.files,
        'Thumbnail': element.thumbnail,
        'Type': element.type,
        'URL': element.url,
      };

      return QueryResult(result: map);
    }).toList();
  }

  static Future<QueryResult> idQueryWeb(String what) async {
    try {
      return await idQueryHitomi(what);
    } catch (_) {
      try {
        return await idQueryEhentai(what);
      } catch (_) {
        return await idQueryExhentai(what);
      }
    }
  }
}
