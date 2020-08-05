// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/settings/settings.dart';

import 'package:http/http.dart' as http;

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
    var route = Settings.searchRule;
    // is db search?
    if (!Settings.searchNetwork) {
      final queryString = HitomiManager.translate2query(what +
          ' ' +
          Settings.includeTags +
          ' ' +
          Settings.excludeTags
              .where((e) => e.trim() != '')
              .map((e) => '-$e')
              .join(' ')
              .trim());

      const int itemsPerPage = 500;
      var queryResult = (await (await DataBaseManager.getInstance()).query(
              "$queryString ORDER BY Id DESC LIMIT $itemsPerPage OFFSET ${itemsPerPage * offset}"))
          .map((e) => QueryResult(result: e))
          .toList();
      return Tuple2<List<QueryResult>, int>(
          queryResult, queryResult.length >= itemsPerPage ? offset + 1 : -1);
    }
    // is web search?
    else {
      for (int i = 0; i < route.length; i++) {
        switch (route[i]) {
          case 'EHentai':
            var result = await _searchEHentai(what, offset.toString());
            return Tuple2<List<QueryResult>, int>(
                result, result.length >= 25 ? offset + 1 : -1);
          case 'ExHentai':
            var result = await _searchEHentai(what, offset.toString(), true);
            return Tuple2<List<QueryResult>, int>(
                result, result.length >= 25 ? offset + 1 : -1);
          case 'Hitomi':
            // https://hiyobi.me/search/loli|sex
            break;
          case 'Hiyobi':
            break;
          case 'NHentai':
            break;
        }
      }
    }

    // not taken
    throw Exception('Never Taken');
  }

  // [Image List], [Big Thumbnail List (Perhaps only two are valid.)], [Small Thubmnail List]
  static Future<Tuple3<List<String>, List<String>, List<String>>>
      getImageListFromEHId(QueryResult qr) async {
    var lang = qr.language() as String;
    var route = Settings.routingRule;

    for (int i = 0; i < route.length; i++) {
      Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>> nt = null;
      switch (route[i]) {

        // Scroll View Prohibited
        case 'EHentai':
          nt = await _tryHiyobi(qr);
          break;
        case 'ExHentai':
          nt = await _tryHiyobi(qr);
          break;

        // Scroll View Allowed
        case 'Hitomi':
          nt = await _tryHitomi(qr);
          break;
        case 'Hiyobi':
          if (lang == 'korean') nt = await _tryHiyobi(qr);
          break;
        case 'NHentai':
          if (lang == 'english' || lang == 'japanese' || lang == 'chinese')
            nt = await _tryNHentai(qr);
          break;
      }

      if (nt != null && nt.item1) return nt.item2;
    }

    return null;
  }

  static Future<Tuple2<List<Future<String>>, Map<String, dynamic>>> getImages(
      QueryResult qr) async {}

  static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
      _tryEHentai(QueryResult qr) async {}
  static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
      _tryExHentai(QueryResult qr) async {}

  static Stream<String> eHentaiStream(QueryResult qr) async* {
    var gg = await http.get('https://e-hentai.org/g/${qr.id()}/${qr.ehash()}/');
    var urls = EHParser.getPagesUrl(gg.body);
    var imgurls = List<String>();

    for (int i = 0; i < urls.length; i++) {
      var page = await http.get(urls[i]);
      imgurls.addAll(EHParser.getImagesUrl(page.body));
    }

    for (int i = 0; i < imgurls.length; i++) {
      var img = await http.get(urls[i]);
      yield EHParser.getImagesAddress(img.body);
    }
  }

  static Future<void> exHentaiStream(QueryResult qr) async {
    var gg = await EHSession.requestString(
        'https://exhentai.org/g/${qr.id()}/${qr.ehash()}/');
    var urls = EHParser.getPagesUrl(gg);
    var imgurls = List<String>();

    for (int i = 0; i < urls.length; i++) {
      var page = await EHSession.requestString(urls[i]);
      imgurls.addAll(EHParser.getImagesUrl(page));
    }

    for (int i = 0; i < imgurls.length; i++) {
      var img = await EHSession.requestString(imgurls[i]);
      print(EHParser.getImagesAddress(img));
    }
  }

  static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
      _tryHitomi(QueryResult qr) async {}
  static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
      _tryHiyobi(QueryResult qr) async {}
  static Future<Tuple2<bool, Tuple3<List<String>, List<String>, List<String>>>>
      _tryNHentai(QueryResult qr) async {}

  static Future<List<QueryResult>> _searchEHentai(String what, String page,
      [bool exh = false]) async {
    var search = Uri.encodeComponent(what);
    var url =
        'https://e${exh ? 'x' : '-'}hentai.org/?inline_set=dm_e&page=$page&f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=$search&page=0&f_apply=Apply+Filter&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_srdd=2';

    var cookie =
        (await SharedPreferences.getInstance()).getString('eh_cookies');
    var html =
        (await http.get(url, headers: {'Cookie': cookie + ';sl=dm_2'})).body;

    var result = EHParser.parseReulstPageExtendedListView(html);

    return result.map((element) {
      var tag = List<String>();

      if (element.descripts['female'] != null)
        tag.addAll(element.descripts['female'].map((e) => "female:" + e));
      if (element.descripts['male'] != null)
        tag.addAll(element.descripts['male'].map((e) => "male:" + e));
      if (element.descripts['misc'] != null)
        tag.addAll(element.descripts['misc']);

      var map = {
        'Id': element.url.split('/')[4],
        'EHash': element.url.split('/')[5],
        'Title': element.title,
        'Artists': element.descripts['artist'] != null
            ? element.descripts['artist'].join('|')
            : 'n/a',
        'Groups': element.descripts['group'] != null
            ? element.descripts['group'].join('|')
            : null,
        'Characters': element.descripts['character'] != null
            ? element.descripts['character'].join('|')
            : null,
        'Series': element.descripts['parody'] != null
            ? element.descripts['parody'].join('|')
            : 'n/a',
        'Language': element.descripts['language'] != null
            ? element.descripts['language']
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
