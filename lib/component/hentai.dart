// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:tuple/tuple.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/database.dart';
import 'package:violet/settings.dart';

import 'package:http/http.dart' as http;

class HentaiManager {
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
          nt = await _tryHiyobi(qr);
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
}
