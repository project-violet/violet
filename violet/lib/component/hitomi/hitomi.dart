// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/variables.dart';

class HitomiManager {
  // [Image List], [Big Thumbnail List (Perhaps only two are valid.)], [Small Thubmnail List]
  static Future<Tuple3<List<String>, List<String>, List<String>>> getImageList(
      String id) async {
    var gg = await http.get('https://ltn.hitomi.la/galleries/$id.js');
    var urls = gg.body;
    if (urls.trim().startsWith('<html>')) return null;
    var files = jsonDecode(urls.substring(urls.indexOf('=') + 1))
        .cast<String, dynamic>()['files'];
    const number_of_frontends = 3;
    final subdomain = String.fromCharCode(
        97 + (id[id.length - 1].codeUnitAt(0) % number_of_frontends));

    var btresult = <String>[];
    var stresult = <String>[];
    var result = <String>[];
    for (var row in files) {
      var rr = row.cast<String, dynamic>();
      var hash = rr['hash'] as String;
      var postfix = hash.substring(hash.length - 3);

      var subdomainx = subdomain;

      if (rr['haswebp'] == 0 || rr['haswebp'] == null) {
        subdomainx = 'b';
      }

      var x = int.tryParse('${postfix[0]}${postfix[1]}', radix: 16);

      if (x != null && !x.isNaN) {
        var nf = 3;
        if (x < 0x70) nf = 2;
        if (x < 0x49) x = 1;
        subdomainx = String.fromCharCode(97 + (x % nf));
      }

      if (rr['haswebp'] == 0 || rr['haswebp'] == null) {
        result.add(
            'https://${subdomainx}b.hitomi.la/images/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.${(rr['name'] as String).split('.').last}');
      } else if (hash == "")
        result.add(
            'https://${subdomainx}a.hitomi.la/webp/${rr['name'] as String}.webp');
      else if (hash.length < 3)
        result.add('https://${subdomainx}a.hitomi.la/webp/$hash.webp');
      else {
        result.add(
            'https://${subdomainx}a.hitomi.la/webp/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.webp');
      }
      btresult.add(
          'https://tn.hitomi.la/bigtn/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.jpg');
      stresult.add(
          'https://${subdomainx}tn.hitomi.la/smalltn/${postfix[2]}/${postfix[0]}${postfix[1]}/$hash.jpg');
    }
    return Tuple3<List<String>, List<String>, List<String>>(
        result, btresult, stresult);
  }

  static int getArticleCount(String classification, String name) {
    if (tagmap == null) {
      final subdir = Platform.isAndroid ? '/data' : '';
      final path =
          File('${Variables.applicationDocumentsDirectory}$subdir/index.json');
      final text = path.readAsStringSync();
      tagmap = jsonDecode(text);
    }

    return tagmap[classification][name];
  }

  static void reloadIndex() {
    final subdir = Platform.isAndroid ? '/data' : '';
    final path =
        File('${Variables.applicationDocumentsDirectory}$subdir/index.json');
    final text = path.readAsStringSync();
    tagmap = jsonDecode(text);
  }

  static Map<String, dynamic> tagmap;
  static Future<List<Tuple3<String, String, int>>> queryAutoComplete(
      String prefix,
      [bool useTranslated = false]) async {
    if (tagmap == null) {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        var file = File('/home/ubuntu/violet/index.json');
        tagmap = jsonDecode(await file.readAsString());
      } else {
        final subdir = Platform.isAndroid ? '/data' : '';
        final directory = await getApplicationDocumentsDirectory();
        final path = File('${directory.path}$subdir/index.json');
        final text = path.readAsStringSync();
        tagmap = jsonDecode(text);
      }
    }

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':')) {
      final opp = prefix.split(':')[0];
      var pp = opp;

      if (pp == 'female' || pp == 'male' || pp == 'tags')
        pp = 'tag';
      else if (pp == 'language' || pp == 'languages')
        pp = 'lang';
      else if (pp == 'artists')
        pp = 'aritst';
      else if (pp == 'groups')
        pp = 'group';
      else if (pp == 'uploaders')
        pp = 'uploader';
      else if (pp == 'types')
        pp = 'type';
      else if (pp == 'characters')
        pp = 'character';
      else if (pp == 'classes') pp = 'class';

      var results = <Tuple3<String, String, int>>[];
      if (!tagmap.containsKey(pp)) return results;

      final ch = tagmap[pp];
      if (!useTranslated) {
        if (opp == 'female' || opp == 'male') {
          ch.forEach((key, value) {
            if (key.toLowerCase().startsWith(opp + ':') &&
                key.toLowerCase().contains(prefix))
              results.add(Tuple3<String, String, int>(opp, key, value));
          });
        } else if (opp == 'tag') {
          var po = prefix.split(':')[1];
          ch.forEach((key, value) {
            if (!key.toLowerCase().startsWith('female:') &&
                !key.toLowerCase().startsWith('male:') &&
                key.toLowerCase().contains(po))
              results.add(Tuple3<String, String, int>(opp, key, value));
          });
        } else {
          var po = prefix.split(':')[1];
          ch.forEach((key, value) {
            if (key.toLowerCase().contains(po))
              results.add(Tuple3<String, String, int>(pp, key, value));
          });
        }
        results.sort((a, b) => b.item3.compareTo(a.item3));
        return results;
      } else {
        var po = prefix.split(':').last;
        var results = TagTranslate.containsTotal(po)
            .where((e) =>
                e.item1.contains(opp != 'female' && opp != 'male'
                    ? opp + ':'
                    : 'tag:' + opp + ':') &&
                ch.containsKey(e.item1.substring(e.item1.indexOf(':') + 1)))
            .map((e) => Tuple3<String, String, int>(
                pp,
                e.item1.substring(e.item1.indexOf(':') + 1) +
                    '|' +
                    e.item2.split('|')[0],
                ch[e.item1.substring(e.item1.indexOf(':') + 1)]))
            .where((e) => opp == 'tag'
                ? !(e.item2.startsWith('female:') ||
                    e.item2.startsWith('male:'))
                : true)
            .toList();
        results.sort((a, b) => b.item3.compareTo(a.item3));
        return results;
      }
    } else {
      if (!useTranslated) {
        var results = <Tuple3<String, String, int>>[];
        tagmap.forEach((key1, value) {
          if (key1 == 'tag') {
            value.forEach((key2, value2) {
              if (key2.contains(':')) {
                if (key2.split(':')[1].contains(prefix))
                  results.add(Tuple3<String, String, int>(
                      key2.split(':')[0], key2, value2));
              } else if (key2.contains(prefix)) {
                if (key2.contains(':'))
                  results.add(Tuple3<String, String, int>(
                      key2.split(':')[0], key2, value2));
                else
                  results.add(Tuple3<String, String, int>('tag', key2, value2));
              }
            });
          } else {
            value.forEach((key2, value2) {
              if (key2.toLowerCase().contains(prefix))
                results.add(Tuple3<String, String, int>(key1, key2, value2));
            });
          }
        });
        results.sort((a, b) => b.item3.compareTo(a.item3));
        return results;
      } else {
        var results = TagTranslate.containsTotal(prefix)
            .where((e) => tagmap[e.item1.split(':')[0]]
                .containsKey(e.item1.substring(e.item1.indexOf(':') + 1)))
            .map((e) => Tuple3<String, String, int>(
                e.item1.split(':')[0],
                e.item1.substring(e.item1.indexOf(':') + 1) +
                    '|' +
                    e.item2.split('|')[0],
                tagmap[e.item1.split(':')[0]]
                    [e.item1.substring(e.item1.indexOf(':') + 1)]))
            .toList();
        results.sort((a, b) => b.item3.compareTo(a.item3));
        return results;
      }
    }
  }

  static Future<List<Tuple3<String, String, int>>> queryAutoCompleteFuzzy(
      String prefix,
      [bool useTranslated = false]) async {
    if (tagmap == null) {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        var file = File('/home/ubuntu/violet/index.json');
        tagmap = jsonDecode(await file.readAsString());
      } else {
        final subdir = Platform.isAndroid ? '/data' : '';
        final directory = await getApplicationDocumentsDirectory();
        final path = File('${directory.path}$subdir/index.json');
        final text = path.readAsStringSync();
        tagmap = jsonDecode(text);
      }
    }

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':')) {
      final opp = prefix.split(':')[0];
      var pp = opp;

      if (pp == 'female' || pp == 'male' || pp == 'tags')
        pp = 'tag';
      else if (pp == 'language' || pp == 'languages')
        pp = 'lang';
      else if (pp == 'artists')
        pp = 'aritst';
      else if (pp == 'groups')
        pp = 'group';
      else if (pp == 'uploaders')
        pp = 'uploader';
      else if (pp == 'types')
        pp = 'type';
      else if (pp == 'characters')
        pp = 'character';
      else if (pp == 'classes') pp = 'class';

      var results = <Tuple4<String, String, int, int>>[];
      if (!tagmap.containsKey(pp)) return <Tuple3<String, String, int>>[];

      final ch = tagmap[pp];
      if (!useTranslated) {
        if (opp == 'female' || opp == 'male') {
          ch.forEach((key, value) {
            if (key.toLowerCase().startsWith(opp + ':')
                // &&
                // key.toLowerCase().contains(prefix)
                )
              results.add(Tuple4<String, String, int, int>(
                  opp,
                  key,
                  Distance.levenshteinDistance(
                      prefix.runes.toList(), key.runes.toList()),
                  value));
          });
        } else if (opp == 'tag') {
          var po = prefix.split(':')[1];
          ch.forEach((key, value) {
            if (!key.toLowerCase().startsWith('female:') &&
                    !key.toLowerCase().startsWith('male:')
                // &&
                // key.toLowerCase().contains(po)
                )
              results.add(Tuple4<String, String, int, int>(
                  opp,
                  key,
                  Distance.levenshteinDistance(
                      po.runes.toList(), key.runes.toList()),
                  value));
          });
        } else {
          var po = prefix.split(':')[1];

          ch.forEach((key, value) {
            // if (key.toLowerCase().contains(po))
            results.add(Tuple4<String, String, int, int>(
                pp,
                key,
                Distance.levenshteinDistance(
                    po.runes.toList(), key.runes.toList()),
                value));
          });
        }
        results.sort((a, b) => a.item3.compareTo(b.item3));
        return results
            .map((e) => Tuple3<String, String, int>(e.item1, e.item2, e.item4))
            .toList();
      } else {
        var po = prefix.split(':').last;
        var results = TagTranslate.containsFuzzingTotal(po)
            .where((e) =>
                e.item1.contains(opp != 'female' && opp != 'male'
                    ? opp + ':'
                    : 'tag:' + opp + ':') &&
                ch.containsKey(e.item1.substring(e.item1.indexOf(':') + 1)))
            .map((e) => Tuple4<String, String, int, int>(
                pp,
                e.item1.substring(e.item1.indexOf(':') + 1) +
                    '|' +
                    e.item2.split('|')[0],
                ch[e.item1.substring(e.item1.indexOf(':') + 1)],
                e.item3))
            .where((e) => opp == 'tag'
                ? !(e.item2.startsWith('female:') ||
                    e.item2.startsWith('male:'))
                : true)
            .toList();
        results.sort((a, b) => a.item4.compareTo(b.item4));
        return results
            .map((e) => Tuple3<String, String, int>(e.item1, e.item2, e.item3))
            .toList();
      }
    } else {
      if (!useTranslated) {
        var results = <Tuple4<String, String, int, int>>[];
        tagmap.forEach((key1, value) {
          if (key1 == 'tag') {
            value.forEach((key2, value2) {
              if (key2.contains(':')) {
                results.add(Tuple4<String, String, int, int>(
                    key2.split(':')[0],
                    key2,
                    Distance.levenshteinDistance(
                        prefix.runes.toList(), key2.runes.toList()),
                    value2));
              } else {
                if (key2.contains(':'))
                  results.add(Tuple4<String, String, int, int>(
                      key2.split(':')[0],
                      key2,
                      Distance.levenshteinDistance(
                          prefix.runes.toList(), key2.runes.toList()),
                      value2));
                else
                  results.add(Tuple4<String, String, int, int>(
                      'tag',
                      key2,
                      Distance.levenshteinDistance(
                          prefix.runes.toList(), key2.runes.toList()),
                      value2));
              }
            });
          } else {
            value.forEach((key2, value2) {
              results.add(Tuple4<String, String, int, int>(
                  key1,
                  key2,
                  Distance.levenshteinDistance(
                      prefix.runes.toList(), key2.runes.toList()),
                  value2));
            });
          }
        });
        results.sort((a, b) => a.item3.compareTo(b.item3));
        return results
            .map((e) => Tuple3<String, String, int>(e.item1, e.item2, e.item4))
            .toList();
      } else {
        var results = TagTranslate.containsFuzzingTotal(prefix)
            .where((e) => tagmap[e.item1.split(':')[0]]
                .containsKey(e.item1.substring(e.item1.indexOf(':') + 1)))
            .map((e) => Tuple4<String, String, int, int>(
                e.item1.split(':')[0],
                e.item1.substring(e.item1.indexOf(':') + 1) +
                    '|' +
                    e.item2.split('|')[0],
                tagmap[e.item1.split(':')[0]]
                    [e.item1.substring(e.item1.indexOf(':') + 1)],
                e.item3))
            .toList();
        results.sort((a, b) => a.item4.compareTo(b.item4));
        return results
            .map((e) => Tuple3<String, String, int>(e.item1, e.item2, e.item3))
            .toList();
      }
    }
  }

  static List<String> splitTokens(String tokens) {
    var result = <String>[];
    var builder = StringBuffer();
    for (int i = 0; i < tokens.length; i++) {
      if (tokens[i] == ' ') {
        result.add(builder.toString());
        builder.clear();
        continue;
      } else if (tokens[i] == '(' ||
          tokens[i] == ')' ||
          tokens[i] == '>' ||
          tokens[i] == '<') {
        result.add(builder.toString());
        builder.clear();
        result.add(tokens[i]);
        continue;
      }

      builder.write(tokens[i]);
    }

    result.add(builder.toString());
    return result;
  }

  static String translate2query(String tokens) {
    tokens = tokens.trim();
    final nn = int.tryParse(tokens.split(' ')[0]);
    if (nn != null) {
      return 'SELECT * FROM HitomiColumnModel WHERE Id=$nn';
    }

    if (tokens == null || tokens.trim() == "")
      return 'SELECT * FROM HitomiColumnModel WHERE ExistOnHitomi=1';

    final split =
        splitTokens(tokens).map((x) => x.trim()).where((x) => x != '').toList();
    var where = '';

    for (int i = 0; i < split.length; i++) {
      var negative = false;
      var val = split[i];
      if (split[i].startsWith('-')) {
        negative = true;
        val = split[i].substring(1);
      }
      if (split[i].contains(':')) {
        var prefix = '';
        var ss = val.split(':');
        var postfix = '';

        switch (ss[0]) {
          case 'male':
          case 'female':
            postfix = '|' + val.replaceAll('_', ' ') + '|';
            prefix = 'Tags';
            break;

          case 'tag':
            postfix = '|' + ss[1].replaceAll('_', ' ') + '|';
            prefix = 'Tags';
            break;

          case 'lang':
            prefix = 'Language';
            break;
          case 'series':
            postfix = '|' + ss[1].replaceAll('_', ' ') + '|';
            prefix = 'Series';
            break;
          case 'artist':
            postfix = '|' + ss[1].replaceAll('_', ' ') + '|';
            prefix = 'Artists';
            break;
          case 'group':
            postfix = '|' + ss[1].replaceAll('_', ' ') + '|';
            prefix = 'Groups';
            break;
          case 'uploader':
            prefix = 'Uploader';
            postfix = ss[1];
            break;
          case 'character':
            postfix = '|' + ss[1].replaceAll('_', ' ') + '|';
            prefix = 'Characters';
            break;
          case 'type':
            prefix = 'Type';
            break;
          case 'class':
            prefix = 'Class';
            break;
          case 'recent':
            return 'SELECT * FROM HitomiColumnModel WHERE ExistOnHitomi=1';
        }
        if (prefix == '') return '';
        if (postfix == '') postfix = ss[1].replaceAll('_', ' ');

        if (negative) where += "(";

        where += "$prefix LIKE '%$postfix%'";

        if (negative) where += ") IS NOT 1";

        if (prefix == 'Uploader') where += ' COLLATE NOCASE';
      } else if ('=<>()'.contains(split[i])) {
        where += split[i];
        if (split[i] == '(') continue;
      } else {
        if (negative)
          where += "Title NOT LIKE '%$val%'";
        else
          where += "Title LIKE '%$val%'";
      }

      if (i != split.length - 1) {
        if (split[i + 1].toLowerCase() == 'or') {
          where += ' OR ';
          i++;
        } else if (split[i + 1] != ')') where += ' AND ';
      }
    }

    return 'SELECT * FROM HitomiColumnModel WHERE $where AND ExistOnHitomi=1';
  }
}
