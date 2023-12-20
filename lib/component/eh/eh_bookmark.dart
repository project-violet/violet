// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';

import 'package:html/parser.dart';
import 'package:violet/component/eh/eh_headers.dart';

class EHBookmark {
  static List<HashSet<int>>? bookmarkInfo;
  static Future<List<HashSet<int>>> process() async {
    // https://e-hentai.org/favorites.php?page=0&favcat=0
    // https://exhentai.org/favorites.php?page=0&favcat=0

    var result = <HashSet<int>>[];
    var rr = RegExp(r'https://exhentai\.org/g/\d+/a-f0-9+');
    var r2 = RegExp(r'https://e\-hentai\.org/g/\d+/a-f0-9+');

    for (int i = 0; i < 10; i++) {
      var hh = HashSet<int>();
      var href_arr = [];
      try {
        for (int j = 0; j < 1000; j++) {
          var html = await EHSession.requestString(
              'https://exhentai.org/favorites.php?page=$j&favcat=$i');
          // var matched = rr.allMatches(html).map((e) => e.group(0));
          var doc = parse(html);
          final before = href_arr.length;
          doc.querySelectorAll('a[href*="/g/"]').forEach((element) {
            var href;
            element.attributes.forEach((key, value) {
              if(key == 'href'){
                href = value;
              }
            });
            if(href == null) return;
            if(href_arr.contains(href)){
              return;
            }
            href_arr.add(href);
            hh.add(int.parse((href!.split('/')[4])));
          });
          // if (matched.isEmpty) break;
          // for (var element in matched) {
          //   hh.add(int.parse(element!.split('/')[4]));
          // }
          final after = href_arr.length;
          if(before == after){
            break;
          }
        }
      } catch (_) {}
      result.add(hh);
      print(hh.length);
    }

    for (int i = 0; i < 10; i++) {
      var href_arr = [];
      try {
        for (int j = 0; j < 1000; j++) {
          var html = await EHSession.requestString(
              'https://e-hentai.org/favorites.php?page=$j&favcat=$i');
          // var matched = r2.allMatches(html).map((e) => e.group(0));
          final before = href_arr.length;
          parse(html).querySelectorAll('a[href*="/g/"]').forEach((element) {
            var href;
            element.attributes.forEach((key, value) {
              if(key == 'href'){
                href = value;
              }
            });
            if(href == null) return;
            if(href_arr.contains(href) || result[i].contains(int.parse((href!.split('/')[4])))){
              return;
            }
            href_arr.add(href);
            result[i].add(int.parse((href!.split('/')[4])));
          });
          // if (matched.isEmpty) break;
          // for (var element in matched) {
          //   result[i].add(int.parse(element!.split('/')[4]));
          // }
          final after = href_arr.length;
          if(before == after){
            break;
          }
        }
      } catch (_) {}
    }

    return bookmarkInfo = result;
  }
}
