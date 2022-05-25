// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/eh/eh_provider.dart';
import 'package:violet/component/hisoki/hisoki_getter.dart';
import 'package:violet/component/hisoki/hisoki_provider.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/hitomi_parser.dart';
import 'package:violet/component/hitomi/hitomi_provider.dart';
import 'package:violet/component/hiyobi/hiyobi.dart';
import 'package:violet/component/hiyobi/hiyobi_provider.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';

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
  static Future<Tuple2<List<QueryResult>, int>> search(String what,
      [int offset = 0]) async {
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

  static Future<Tuple2<List<QueryResult>, int>> idSearch(String what) async {
    final queryString = HitomiManager.translate2query(what);
    var queryResult = (await (await DataBaseManager.getInstance())
            .query("$queryString ORDER BY Id DESC LIMIT 1 OFFSET 0"))
        .map((e) => QueryResult(result: e))
        .toList();
    int? no = int.tryParse(what);

    if (queryResult.isNotEmpty) {
      return Tuple2<List<QueryResult>, int>(queryResult, -1);
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
        'Artists': article['Artists'].join('|'),
      };
      return Tuple2<List<QueryResult>, int>([QueryResult(result: meta)], -1);
    } catch (e, st) {
      Logger.error(
          '[hentai-idSearch] E: ' + e.toString() + '\n' + st.toString());
    }

    return Tuple2<List<QueryResult>, int>([], -1);
  }

  // static double _latestSeed = 0;
  static Future<Tuple2<List<QueryResult>, int>> _randomSearch(String what,
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

        return Tuple2<List<QueryResult>, int>([], -1);
      }
    }
    final queryString = HitomiManager.translate2query(wwhat +
        ' ' +
        Settings.includeTags +
        ' ' +
        Settings.excludeTags
            .where((e) => e.trim() != '')
            .map((e) => '-$e')
            .join(' ')
            .trim());

    // if (offset == 0 && seed < 0) _latestSeed = new Random().nextDouble() + 1;
    await Logger.info('[Database Query]\nSQL: $queryString');

    const int itemsPerPage = 500;
    var queryResult = (await (await DataBaseManager.getInstance()).query(
            "$queryString ORDER BY " +
                "Id * $seed - ROUND(Id * $seed - 0.5, 0) DESC" +
                " LIMIT $itemsPerPage OFFSET $offset"))
        .map((e) => QueryResult(result: e))
        .toList();
    return Tuple2<List<QueryResult>, int>(queryResult,
        queryResult.length >= itemsPerPage ? offset + itemsPerPage : -1);
  }

  static Future<Tuple2<List<QueryResult>, int>> _dbSearch(String what,
      [int offset = 0]) async {
    final queryString = HitomiManager.translate2query(what +
        ' ' +
        Settings.includeTags +
        ' ' +
        Settings.excludeTags
            .where((e) => e.trim() != '')
            .map((e) => '-$e')
            .join(' ')
            .trim());

    await Logger.info('[Database Query]\nSQL: $queryString');

    const int itemsPerPage = 500;
    var queryResult = (await (await DataBaseManager.getInstance()).query(
            "$queryString ORDER BY Id DESC LIMIT $itemsPerPage OFFSET $offset"))
        .map((e) => QueryResult(result: e))
        .toList();
    return Tuple2<List<QueryResult>, int>(queryResult,
        queryResult.length >= itemsPerPage ? offset + itemsPerPage : -1);
  }

  static Future<Tuple2<List<QueryResult>, int>> _networkSearch(String what,
      [int offset = 0]) async {
    var route = Settings.searchRule;
    for (int i = 0; i < route.length; i++) {
      try {
        switch (route[i]) {
          case 'EHentai':
            var result = await searchEHentai(what, (offset ~/ 25).toString());
            return Tuple2<List<QueryResult>, int>(
                result, result.length >= 25 ? offset + 25 : -1);
          case 'ExHentai':
            var result = await searchEHentai(what, offset.toString(), true);
            return Tuple2<List<QueryResult>, int>(
                result, result.length >= 25 ? offset + 25 : -1);
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
        Logger.error('[hentai-_networkSearch] E: ' +
            e.toString() +
            '\n' +
            st.toString());
      }
    }

    // not taken
    throw Exception('Never Taken');
  }

  static Future<int> countSearch(String what) async {
    final queryString = HitomiManager.translate2query(what +
        ' ' +
        Settings.includeTags +
        ' ' +
        Settings.excludeTags
            .where((e) => e.trim() != '')
            .map((e) => '-$e')
            .join(' ')
            .trim());

    var count = (await (await DataBaseManager.getInstance()).query(queryString
            .replaceAll('SELECT * FROM', 'SELECT COUNT(*) AS C FROM')))
        .first['C'] as int;

    return count;
  }

  static Future<VioletImageProvider> getImageProvider(QueryResult qr) async {
    var lang = qr.language() as String;
    var route = Settings.routingRule;

    for (int i = 0; i < route.length; i++) {
      try {
        switch (route[i]) {
          case 'EHentai':
            if (qr.ehash() != null) {
              var html = await EHSession.requestString(
                  'https://e-hentai.org/g/${qr.id()}/${qr.ehash()}/?p=0&inline_set=ts_l');
              var article = EHParser.parseArticleData(html);
              print(article.title);
              return EHentaiImageProvider(
                count: article.length,
                thumbnail: article.thumbnail,
                pagesUrl: EHParser.getPagesUrl(html),
                isEHentai: true,
              );
            }
            break;
          case 'ExHentai':
            if (qr.ehash() != null) {
              var html = await EHSession.requestString(
                  'https://exhentai.org/g/${qr.id()}/${qr.ehash()}/?p=0&inline_set=ts_l');
              var article = EHParser.parseArticleData(html);
              return EHentaiImageProvider(
                count: article.length,
                thumbnail: article.thumbnail,
                pagesUrl: EHParser.getPagesUrl(html),
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

          case 'Hiyobi':
            {
              var urls = await HiyobiManager.getImageList(qr.id().toString());
              if (urls.item2.isEmpty) break;
              return HiyobiImageProvider(urls);
            }

          case 'Hisoki':
            {
              var urls = await HisokiGetter.getImages(qr.id());
              if (urls == null || urls.isEmpty) break;
              return HisokiImageProvider(infos: urls, id: qr.id());
            }

          case 'NHentai':
            if (lang == 'english' || lang == 'japanese' || lang == 'chinese') {
              // return HitomiImageProvider(
              //     await NHentaiManager.getImageList(qr.id().toString()));
            }
            break;
        }
      } catch (e, st) {
        Logger.error('[hentai-getImageProvider] E: ' +
            e.toString() +
            '\n' +
            st.toString());
      }
    }

    throw Exception('gallery not found');
  }

  // [Image List], [Big Thumbnail List (Perhaps only two are valid.)], [Small Thubmnail List]
  // static Future<Tuple3<List<String>, List<String>, List<String>>>
  //     getImageListFromEHId(QueryResult qr) async {
  //   var lang = qr.language() as String;
  //   var route = Settings.routingRule;

  //   for (int i = 0; i < route.length; i++) {
  //     Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>> nt = null;
  //     switch (route[i]) {
  //       case 'EHentai':
  //         nt = await _tryHiyobi(qr);
  //         break;
  //       case 'ExHentai':
  //         nt = await _tryHiyobi(qr);
  //         break;
  //       case 'Hitomi':
  //         nt = await _tryHitomi(qr);
  //         break;
  //       case 'Hiyobi':
  //         if (lang == 'korean') nt = await _tryHiyobi(qr);
  //         break;
  //       case 'NHentai':
  //         if (lang == 'english' || lang == 'japanese' || lang == 'chinese')
  //           nt = await _tryNHentai(qr);
  //         break;
  //     }

  //     if (nt != null && nt.item1) return nt.item2;
  //   }

  //   return null;
  // }

  // static Future<Tuple2<List<Future<String>>, Map<String, dynamic>>> getImages(
  //     QueryResult qr) async {}

  // static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
  //     _tryEHentai(QueryResult qr) async {}
  // static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
  //     _tryExHentai(QueryResult qr) async {}

  // static Stream<String> eHentaiStream(QueryResult qr) async* {
  //   var gg = await http.get('https://e-hentai.org/g/${qr.id()}/${qr.ehash()}/');
  //   var urls = EHParser.getPagesUrl(gg.body);
  //   var imgurls = List<String>();

  //   for (int i = 0; i < urls.length; i++) {
  //     var page = await http.get(urls[i]);
  //     imgurls.addAll(EHParser.getImagesUrl(page.body));
  //   }

  //   for (int i = 0; i < imgurls.length; i++) {
  //     var img = await http.get(urls[i]);
  //     yield EHParser.getImagesAddress(img.body);
  //   }
  // }

  // static Future<void> exHentaiStream(QueryResult qr) async {
  //   var gg = await EHSession.requestString(
  //       'https://exhentai.org/g/${qr.id()}/${qr.ehash()}/');
  //   var urls = EHParser.getPagesUrl(gg);
  //   var imgurls = List<String>();

  //   for (int i = 0; i < urls.length; i++) {
  //     var page = await EHSession.requestString(urls[i]);
  //     imgurls.addAll(EHParser.getImagesUrl(page));
  //   }

  //   for (int i = 0; i < imgurls.length; i++) {
  //     var img = await EHSession.requestString(imgurls[i]);
  //     print(EHParser.getImagesAddress(img));
  //   }
  // }

  // static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
  //     _tryHitomi(QueryResult qr) async {}
  // static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
  //     _tryHiyobi(QueryResult qr) async {}
  // static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
  //     _tryNHentai(QueryResult qr) async {}

  static Future<List<QueryResult>> searchEHentai(String what, String page,
      [bool exh = false]) async {
    var search = Uri.encodeComponent(what);
    // var url =
    //     'https://e${exh ? 'x' : '-'}hentai.org/?inline_set=dm_e&page=$page&f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=$search&page=0&f_apply=Apply+Filter&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_srdd=2';
//    var url =
    //      'https://e${exh ? 'x' : '-'}hentai.org/?page=$page&f_cats=0&f_search=$what&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_spf=&f_spt=';
    var url =
        'https://e${exh ? 'x' : '-'}hentai.org/?page=$page&f_cats=993&f_search=$search&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_spf=&f_spt=';

    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies') ?? '';
    var html =
        (await http.get(url, headers: {'Cookie': cookie + ';sl=dm_2'})).body;

    var result = EHParser.parseReulstPageExtendedListView(html);

    return result.map((element) {
      var tag = <String>[];

      if (element.descripts != null) {
        if (element.descripts!['female'] != null)
          tag.addAll(element.descripts!['female']!.map((e) => "female:" + e));
        if (element.descripts!['male'] != null)
          tag.addAll(element.descripts!['male']!.map((e) => "male:" + e));
        if (element.descripts!['misc'] != null)
          tag.addAll(element.descripts!['misc']!);
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
