// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/displayed_tag.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class HitomiManager {
  // [Image List], [Big Thumbnail List (Perhaps only two are valid.)], [Small Thubmnail List]
  static Future<Tuple3<List<String>, List<String>, List<String>>> getImageList(
      String id) async {
    final result = await ScriptManager.runHitomiGetImageList(int.parse(id));
    if (result != null) return result;
    return const Tuple3<List<String>, List<String>, List<String>>(
        <String>[], <String>[], <String>[]);
  }

  static int? getArticleCount(String classification, String name) {
    if (tagmap == null) {
      final subdir = Platform.isAndroid ? '/data' : '';
      final path =
          File('${Variables.applicationDocumentsDirectory}$subdir/index.json');
      final text = path.readAsStringSync();
      tagmap = jsonDecode(text);
    }

    return tagmap![classification][name];
  }

  static void reloadIndex() {
    final subdir = Platform.isAndroid ? '/data' : '';
    final path =
        File('${Variables.applicationDocumentsDirectory}$subdir/index.json');
    final text = path.readAsStringSync();
    tagmap = jsonDecode(text);
  }

  static String normalizeTagPrefix(String pp) {
    switch (pp) {
      case 'tags':
        return 'tag';

      case 'language':
      case 'languages':
        return 'lang';

      case 'artists':
        return 'artist';

      case 'groups':
        return 'group';

      case 'types':
        return 'type';

      case 'characters':
        return 'character';

      case 'classes':
        return 'class';
    }

    return pp;
  }

  static Future<void> loadIndexIfRequired() async {
    if (tagmap == null) {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        final file = File(join(Directory.current.path, 'test/db/index.json'));
        tagmap = jsonDecode(await file.readAsString());
      } else {
        final subdir = Platform.isAndroid ? '/data' : '';
        final directory = await getApplicationDocumentsDirectory();
        final path = File('${directory.path}$subdir/index.json');
        final text = path.readAsStringSync();
        tagmap = jsonDecode(text);
      }

      // split `tag:female:` and `tag:male:` to `female:` and `male:`
      if (tagmap!.containsKey('tag')) {
        final tags = tagmap!['tag'] as Map<String, dynamic>;
        final femaleTags = tags.entries
            .where((e) => e.key.startsWith('female:'))
            .map((e) => MapEntry(e.key.split(':')[1], e.value))
            .toList();
        final maleTags = tags.entries
            .where((e) => e.key.startsWith('male:'))
            .map((e) => MapEntry(e.key.split(':')[1], e.value))
            .toList();
        tagmap!['female'] = Map.fromEntries(femaleTags);
        tagmap!['male'] = Map.fromEntries(maleTags);

        tags.removeWhere(
            (tag, _) => tag.startsWith('female:') || tag.startsWith('male:'));
      }
    }
  }

  static Map<String, dynamic>? tagmap;
  static Future<List<Tuple2<DisplayedTag, int>>> queryAutoComplete(
      String prefix,
      [bool useTranslated = false]) async {
    await loadIndexIfRequired();

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':') && prefix.split(':')[0] != 'random') {
      return _queryAutoCompleteWithTagmap(prefix, useTranslated);
    }

    return _queryAutoCompleteFullSearch(prefix, useTranslated);
  }

  static List<Tuple2<DisplayedTag, int>> _queryAutoCompleteWithTagmap(
      String prefix, bool useTranslated) {
    final groupOrig = prefix.split(':')[0];
    final group = normalizeTagPrefix(groupOrig);
    final name = prefix.split(':').last;

    final results = <Tuple2<DisplayedTag, int>>[];
    if (!tagmap!.containsKey(group)) return results;

    final nameCountsMap = tagmap![group] as Map<dynamic, dynamic>;
    if (!useTranslated) {
      results.addAll(nameCountsMap.entries
          .where((e) => e.key.toString().toLowerCase().contains(name))
          .map((e) => Tuple2<DisplayedTag, int>(
              DisplayedTag(group: group, name: e.key), e.value)));
    } else {
      results.addAll(TagTranslate.containsTotal(name)
          .where((e) => e.group! == group && nameCountsMap.containsKey(e.name))
          .map((e) => Tuple2<DisplayedTag, int>(e, nameCountsMap[e.name])));
    }
    results.sort((a, b) => b.item2.compareTo(a.item2));
    return results;
  }

  static List<Tuple2<DisplayedTag, int>> _queryAutoCompleteFullSearch(
      String prefix, bool useTranslated) {
    if (useTranslated) {
      final results = TagTranslate.containsTotal(prefix)
          .where((e) => tagmap![e.group].containsKey(e.name))
          .map((e) => Tuple2<DisplayedTag, int>(e, tagmap![e.group][e.name]))
          .toList();
      results.sort((a, b) => b.item2.compareTo(a.item2));
      return results;
    }

    final results = <Tuple2<DisplayedTag, int>>[];

    tagmap!['tag'].forEach((group, count) {
      if (group.contains(':')) {
        final subGroup = group.split(':');
        if (subGroup[1].contains(prefix)) {
          results.add(Tuple2<DisplayedTag, int>(
              DisplayedTag(group: subGroup[0], name: group), count));
        }
      } else if (group.contains(prefix)) {
        results.add(Tuple2<DisplayedTag, int>(
            DisplayedTag(group: 'tag', name: group), count));
      }
    });

    tagmap!.forEach((group, value) {
      if (group != 'tag') {
        value.forEach((name, count) {
          if (name.toLowerCase().contains(prefix)) {
            results.add(Tuple2<DisplayedTag, int>(
                DisplayedTag(group: group, name: name), count));
          }
        });
      }
    });

    results.sort((a, b) => b.item2.compareTo(a.item2));
    return results;
  }

  static Future<List<Tuple2<DisplayedTag, int>>> queryAutoCompleteFuzzy(
      String prefix,
      [bool useTranslated = false]) async {
    await loadIndexIfRequired();

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':')) {
      final groupOrig = prefix.split(':')[0];
      final group = normalizeTagPrefix(groupOrig);
      final name = prefix.split(':').last;

      // <Tag, Similarity, Count>
      final results = <Tuple3<DisplayedTag, int, int>>[];
      if (!tagmap!.containsKey(group)) return <Tuple2<DisplayedTag, int>>[];

      final nameCountsMap = tagmap![group];
      if (!useTranslated) {
        nameCountsMap.forEach((key, value) {
          results.add(Tuple3<DisplayedTag, int, int>(
              DisplayedTag(group: group, name: key),
              Distance.levenshteinDistance(
                  name.runes.toList(), key.runes.toList()),
              value));
        });
      } else {
        results.addAll(TagTranslate.containsFuzzingTotal(name)
            .where((e) =>
                e.item1.group! == group &&
                nameCountsMap.containsKey(e.item1.name))
            .map((e) => Tuple3<DisplayedTag, int, int>(
                e.item1, e.item2, nameCountsMap[e.item1.name])));
      }
      results.sort((a, b) => a.item2.compareTo(b.item2));
      return results
          .map((e) => Tuple2<DisplayedTag, int>(e.item1, e.item3))
          .toList();
    } else {
      if (!useTranslated) {
        final results = <Tuple3<DisplayedTag, int, int>>[];
        tagmap!.forEach((group, value) {
          value.forEach((name, count) {
            results.add(Tuple3<DisplayedTag, int, int>(
                DisplayedTag(group: group, name: name),
                Distance.levenshteinDistance(
                    prefix.runes.toList(), name.runes.toList()),
                count));
          });
        });
        results.sort((a, b) => a.item2.compareTo(b.item2));
        return results
            .map((e) => Tuple2<DisplayedTag, int>(e.item1, e.item3))
            .toList();
      } else {
        final results = TagTranslate.containsFuzzingTotal(prefix)
            .where((e) => tagmap![e.item1.group].containsKey(e.item1.name))
            .map((e) => Tuple3<DisplayedTag, int, int>(
                e.item1, tagmap![e.item1.group][e.item1.name], e.item2))
            .toList();
        results.sort((a, b) => a.item3.compareTo(b.item3));
        return results
            .map((e) => Tuple2<DisplayedTag, int>(e.item1, e.item2))
            .toList();
      }
    }
  }

  static List<String> splitTokens(String tokens) {
    final result = <String>[];
    final builder = StringBuffer();
    for (int i = 0; i < tokens.length; i++) {
      if (tokens[i] == ' ') {
        result.add(builder.toString());
        builder.clear();
        continue;
      } else if (tokens[i] == '(' || tokens[i] == ')') {
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

  static String translate2query(String tokens, {bool filter = true}) {
    tokens = tokens.trim();
    final nn = int.tryParse(tokens.split(' ')[0]);
    if (nn != null) {
      return 'SELECT * FROM HitomiColumnModel WHERE Id=$nn';
    }

    final filterExistsOnHitomi = !Settings.searchPure && filter;

    if (tokens.isEmpty) {
      return 'SELECT * FROM HitomiColumnModel ${filterExistsOnHitomi ? 'WHERE ExistOnHitomi=1' : ''}';
    }

    final split =
        splitTokens(tokens).map((x) => x.trim()).where((x) => x != '').toList();
    var where = '';

    for (int i = 0; i < split.length; i++) {
      var negative = false;
      var val = split[i];
      if (split[i] == '-') {
        negative = true;
        val = split[++i];
      } else if (split[i].startsWith('-')) {
        negative = true;
        val = split[i].substring(1);
      }
      if (split[i].contains(':')) {
        var prefix = '';
        final ss = val.split(':');
        var postfix = '';

        switch (ss[0]) {
          case 'male':
          case 'female':
            postfix = '|${val.replaceAll('_', ' ')}|';
            prefix = 'Tags';
            break;

          case 'tag':
            postfix = '|${ss[1].replaceAll('_', ' ')}|';
            prefix = 'Tags';
            break;

          case 'lang':
            prefix = 'Language';
            break;
          case 'series':
            postfix = '|${ss[1].replaceAll('_', ' ')}|';
            prefix = 'Series';
            break;
          case 'artist':
            postfix = '|${ss[1].replaceAll('_', ' ')}|';
            prefix = 'Artists';
            break;
          case 'group':
            postfix = '|${ss[1].replaceAll('_', ' ')}|';
            prefix = 'Groups';
            break;
          case 'uploader':
            prefix = 'Uploader';
            postfix = ss[1];
            break;
          case 'character':
            postfix = '|${ss[1].replaceAll('_', ' ')}|';
            prefix = 'Characters';
            break;
          case 'type':
            prefix = 'Type';
            break;
          case 'class':
            prefix = 'Class';
            break;
          case 'recent':
            return 'SELECT * FROM HitomiColumnModel ${filterExistsOnHitomi ? 'where ExistOnHitomi=1' : ''}';
        }
        if (prefix == '') return '';
        if (postfix == '') postfix = ss[1].replaceAll('_', ' ');

        if (negative) where += '(';

        where += "$prefix LIKE '%$postfix%'";

        if (negative) where += ') IS NOT 1';

        if (prefix == 'Uploader') where += ' COLLATE NOCASE';
      } else if ('=<>()'.contains(split[i])) {
        if (split[i] == '(' && negative) where += 'NOT ';
        where += split[i];
        if (split[i] == '(') continue;
      } else if (split[i].startsWith('page') &&
          (split[i].contains('>') ||
              split[i].contains('=') ||
              split[i].contains('<'))) {
        final re = RegExp(r'page([\=\<\>]{1,2})(\d+)');
        print(split[i]);
        if (re.hasMatch(split[i])) {
          final matches = re.allMatches(split[i]).elementAt(0);
          where += 'Files ${matches.group(1)} ${matches.group(2)}';
        }
      } else {
        if (negative) {
          where += "Title NOT LIKE '%$val%'";
        } else {
          where += "Title LIKE '%$val%'";
        }
      }

      if (i != split.length - 1) {
        if (split[i + 1].toLowerCase() == 'or') {
          where += ' OR ';
          i++;
        } else if (split[i + 1] != ')') {
          where += ' AND ';
        }
      }
    }

    return 'SELECT * FROM HitomiColumnModel WHERE $where ${filterExistsOnHitomi ? ' AND ExistOnHitomi=1' : ''}';
  }
}
