// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

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

  const SearchResult({required this.results, required this.offset});
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
  static Future<SearchResult> search(String what, [int offset = 0]) async {
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
      return await _networkSearch(what, offset);
    }
  }

  static Future<SearchResult> idSearch(String what) async {
    final queryString = HitomiManager.translate2query(what);
    var queryResult = (await (await DataBaseManager.getInstance())
            .query('$queryString ORDER BY Id DESC LIMIT 1 OFFSET 0'))
        .map((e) => QueryResult(result: e))
        .toList();
    int no = int.parse(what);

    if (queryResult.isNotEmpty) {
      return SearchResult(results: queryResult, offset: -1);
    }

    try {
      var headers =
          await ScriptManager.runHitomiGetHeaderContent(no.toString());
      var hh = await http.get('https://ltn.hitomi.la/galleryblock/$no.html',
          headers: headers);
      var article = await HitomiParser.parseGalleryBlock(hh.body);
      var meta = {
        'Id': no,
        'Title': article['Title'],
        'Artists': article['Artists']?.join('|'),
        'Language': article['Language'],
      };
      return SearchResult(results: [QueryResult(result: meta)], offset: -1);
    } catch (e, st) {
      Logger.error('[hentai-idSearch] E: $e\n'
          '$st');
      try {
        late var gallery_url,gallery_token;
        var list_html = await EHSession.requestString(
          'https://e-hentai.org/?next=${(no + 1)}'
        );
        parse(list_html)
          .querySelector('a[href*="/g/$no/"]')
          ?.attributes.forEach((key, value) {
            if(key == 'href'){
              gallery_url = value;
              gallery_token = value.split('/').lastWhere((element) => element.isNotEmpty);
            }
          });
        var html = await EHSession.requestString('https://e-hentai.org/g/${no}/${gallery_token}/?p=0&inline_set=ts_m');
        var article_eh = EHParser.parseArticleData(html);
        var meta = {
          'Id': no,
          'Title': article_eh.title,
          'EHash': gallery_token,
          'Artists': article_eh.artist == null ? 'N/A' : article_eh.artist?.join('|'),
          'Language': article_eh.language,
        };
        return SearchResult(results: [QueryResult(result: meta)], offset: -1);
      } catch(e1,st1){
        Logger.error('[hentai-idSearch] E: $e\n'
            '$st');
      }
    }

    return const SearchResult(results: [], offset: -1);
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
        '$what ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ').trim()}').replaceAll('AND ExistOnHitomi=1', '');

    await Logger.info('[Database Query]\nSQL: $queryString');

    const int itemsPerPage = 500;
    var dbManager = await DataBaseManager.getInstance();
    var dbResult = await dbManager.query('$queryString ORDER BY Id DESC LIMIT $itemsPerPage OFFSET $offset');
    var queryResult = dbResult.map((e) => QueryResult(result: e));
    var queryList = queryResult.toList();

    return SearchResult(
      results: queryList,
      offset: queryList.length >= itemsPerPage ? offset + itemsPerPage : -1,
    );
  }

  static Future<SearchResult> _networkSearch(String what,
      [int offset = 0]) async {
    var route = Settings.searchRule;
    for (int i = 0; i < route.length; i++) {
      try {
        switch (route[i]) {
          case 'EHentai':
            var result = await searchEHentai(what, (offset ~/ 25).toString());
            return SearchResult(
              results: result,
              offset: result.length >= 25 ? offset + 25 : -1,
            );
          case 'ExHentai':
            var result =
                await searchEHentai(what, (offset ~/ 25).toString(), true);
            return SearchResult(
              results: result,
              offset: result.length >= 25 ? offset + 25 : -1,
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

  static Future<VioletImageProvider> getImageProvider(QueryResult qr) async {
    final route = Settings.routingRule;

    do {
      final v4 = ScriptManager.enableV4;

      for (int i = 0; i < route.length; i++) {
        try {
          switch (route[i]) {
            case 'EHentai':
              if (qr.ehash() != null) {
                var html = await EHSession.requestString(
                    'https://e-hentai.org/g/${qr.id()}/${qr.ehash()}/?p=0&inline_set=ts_m');
                var article = EHParser.parseArticleData(html);
                return EHentaiImageProvider(
                  count: article.length,
                  thumbnail: article.thumbnail,
                  pagesUrl: List<String>.generate(
                      (article.length / 40).ceil(),
                      (index) =>
                          'https://e-hentai.org/g/${qr.id()}/${qr.ehash()}/?p=$index'),
                  isEHentai: true,
                );
              }
              break;
            case 'ExHentai':
              if (qr.ehash() != null) {
                var html = await EHSession.requestString(
                    'https://exhentai.org/g/${qr.id()}/${qr.ehash()}/?p=0&inline_set=ts_m');
                var article = EHParser.parseArticleData(html);
                return EHentaiImageProvider(
                  count: article.length,
                  thumbnail: article.thumbnail,
                  pagesUrl: List<String>.generate(
                      (article.length / 40).ceil(),
                      (index) =>
                          'https://exhentai.org/g/${qr.id()}/${qr.ehash()}/?p=$index'),
                  isEHentai: false,
                );
              }
              break;
            case 'Hitomi':
              {
                var urls = await HitomiManager.getImageList(qr.id().toString());
                if (urls.item1.isEmpty || urls.item2.isEmpty) break;
                return HitomiImageProvider(urls, qr.id().toString());
              }

            case 'Hisoki':
              {
                var urls = await HisokiGetter.getImages(qr.id());
                if (urls == null || urls.isEmpty) break;
                return HisokiImageProvider(infos: urls, id: qr.id());
              }

            case 'NHentai':
              if (qr.language() == null) {
                var lang = qr.language() as String;
                if (lang == 'english' ||
                    lang == 'japanese' ||
                    lang == 'chinese') {
                  // return HitomiImageProvider(
                  //     await NHentaiManager.getImageList(qr.id().toString()));
                }
              }
              break;
          }
        } catch (e, st) {
          Logger.error('[hentai-getImageProvider] E: $e\n'
              '$st');
        }
      }

      if (v4) break;

      await Future.delayed(const Duration(milliseconds: 500));
    } while (true);

    throw Exception('gallery not found');
  }

  static Future<List<QueryResult>> searchEHentai(String what, String page,
      [bool exh = false]) async {
    final search = Uri.encodeComponent(what);
    final url =
        'https://e${exh ? 'x' : '-'}hentai.org/?page=$page&f_cats=993&f_search=$search&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_spf=&f_spt=';

    final cookie =
        (await (await MultiPreferences.getInstance()).getString('eh_cookies')) ?? '';
    final html =
        (await http.get(url, headers: {'Cookie': '$cookie;sl=dm_2'})).body;

    final result = EHParser.parseReulstPageExtendedListView(html);

    return result.map((element) {
      var tag = <String>[];

      if (element.descripts != null) {
        if (element.descripts!['female'] != null) {
          tag.addAll(element.descripts!['female']!.map((e) => 'female:$e'));
        }
        if (element.descripts!['male'] != null) {
          tag.addAll(element.descripts!['male']!.map((e) => 'male:$e'));
        }
        if (element.descripts!['misc'] != null) {
          tag.addAll(element.descripts!['misc']!);
        }
      }

      var map = {
        'Id': int.parse(element.url!.split('/')[4]),
        'EHash': element.url!.split('/')[5],
        'Title': element.title,
        'Artists': element.descripts!['artist'] != null
            ? element.descripts!['artist']!.join('|')
            : 'n/a',
        'Groups': element.descripts!['group'] != null
            ? element.descripts!['group']!.join('|')
            : null,
        'Characters': element.descripts!['character'] != null
            ? element.descripts!['character']!.join('|')
            : null,
        'Series': element.descripts!['parody'] != null
            ? element.descripts!['parody']!.join('|')
            : 'n/a',
        'Language': element.descripts!['language'] != null
            ? element.descripts!['language']!
                .where((element) => !element.contains('translate'))
                .join('|')
            : 'n/a',
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
}
