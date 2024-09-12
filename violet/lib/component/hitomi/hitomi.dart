// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/displayed_tag.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class ImageList {
  final List<String> urls;
  final List<String> bigThumbnails;
  final List<String>? smallThumbnails;

  const ImageList({
    required this.urls,
    required this.bigThumbnails,
    this.smallThumbnails,
  });
}

class HitomiManager {
  // [Image List], [Big Thumbnail List (Perhaps only two are valid.)], [Small Thubmnail List]
  static Future<ImageList> getImageList(String id) async {
    final result = await ScriptManager.runHitomiGetImageList(int.parse(id));
    if (result != null) return result;
    return const ImageList(urls: [], bigThumbnails: []);
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
  static Future<List<(DisplayedTag, int)>> queryAutoComplete(String prefix,
      [bool useTranslated = false]) async {
    await loadIndexIfRequired();

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':') && prefix.split(':')[0] != 'random') {
      return _queryAutoCompleteWithTagmap(prefix, useTranslated);
    }

    return _queryAutoCompleteFullSearch(prefix, useTranslated);
  }

  static List<(DisplayedTag, int)> _queryAutoCompleteWithTagmap(
      String prefix, bool useTranslated) {
    final groupOrig = prefix.split(':')[0];
    final group = normalizeTagPrefix(groupOrig);
    final name = prefix.split(':').last;

    final results = <(DisplayedTag, int)>[];
    if (!tagmap!.containsKey(group)) return results;

    final nameCountsMap = tagmap![group] as Map<dynamic, dynamic>;
    if (!useTranslated) {
      results.addAll(nameCountsMap.entries
          .where((e) => e.key.toString().toLowerCase().contains(name))
          .map((e) => (DisplayedTag(group: group, name: e.key), e.value)));
    } else {
      results.addAll(TagTranslate.containsTotal(name)
          .where((e) => e.group! == group && nameCountsMap.containsKey(e.name))
          .map((e) => (e, nameCountsMap[e.name])));
    }
    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results;
  }

  static List<(DisplayedTag, int)> _queryAutoCompleteFullSearch(
      String prefix, bool useTranslated) {
    if (useTranslated) {
      final results = TagTranslate.containsTotal(prefix)
          .where((e) => tagmap![e.group].containsKey(e.name))
          .map((e) => (e, tagmap![e.group][e.name] as int))
          .toList();
      results.sort((a, b) => b.$2.compareTo(a.$2));
      return results;
    }

    final results = <(DisplayedTag, int)>[];

    tagmap!['tag'].forEach((group, count) {
      if (group.contains(':')) {
        final subGroup = group.split(':');
        if (subGroup[1].contains(prefix)) {
          results.add((DisplayedTag(group: subGroup[0], name: group), count));
        }
      } else if (group.contains(prefix)) {
        results.add((DisplayedTag(group: 'tag', name: group), count));
      }
    });

    tagmap!.forEach((group, value) {
      if (group != 'tag') {
        value.forEach((name, count) {
          if (name.toLowerCase().contains(prefix)) {
            results.add((DisplayedTag(group: group, name: name), count));
          }
        });
      }
    });

    results.sort((a, b) => b.$2.compareTo(a.$2));
    return results;
  }

  static Future<List<(DisplayedTag, int)>> queryAutoCompleteFuzzy(String prefix,
      [bool useTranslated = false]) async {
    await loadIndexIfRequired();

    prefix = prefix.toLowerCase().replaceAll('_', ' ');

    if (prefix.contains(':')) {
      final groupOrig = prefix.split(':')[0];
      final group = normalizeTagPrefix(groupOrig);
      final name = prefix.split(':').last;

      // <Tag, Similarity, Count>
      final results = <(DisplayedTag, int, int)>[];
      if (!tagmap!.containsKey(group)) return <(DisplayedTag, int)>[];

      final nameCountsMap = tagmap![group];
      if (!useTranslated) {
        nameCountsMap.forEach((key, value) {
          results.add((
            DisplayedTag(group: group, name: key),
            Distance.levenshteinDistance(
                name.runes.toList(), key.runes.toList()),
            value
          ));
        });
      } else {
        results.addAll(TagTranslate.containsFuzzingTotal(name)
            .where((e) =>
                e.$1.group! == group && nameCountsMap.containsKey(e.$1.name))
            .map((e) => (e.$1, e.$2, nameCountsMap[e.$1.name])));
      }
      results.sort((a, b) => a.$2.compareTo(b.$2));
      return results.map((e) => (e.$1, e.$3)).toList();
    } else {
      if (!useTranslated) {
        final results = <(DisplayedTag, int, int)>[];
        tagmap!.forEach((group, value) {
          value.forEach((name, count) {
            results.add((
              DisplayedTag(group: group, name: name),
              Distance.levenshteinDistance(
                  prefix.runes.toList(), name.runes.toList()),
              count
            ));
          });
        });
        results.sort((a, b) => a.$2.compareTo(b.$2));
        return results.map((e) => (e.$1, e.$3)).toList();
      } else {
        final results = TagTranslate.containsFuzzingTotal(prefix)
            .where((e) => tagmap![e.$1.group].containsKey(e.$1.name))
            .map((e) => (e.$1, tagmap![e.$1.group][e.$1.name] as int, e.$2))
            .toList();
        results.sort((a, b) => a.$3.compareTo(b.$3));
        return results.map((e) => (e.$1, e.$2)).toList();
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

  static String translate2query(String query, {bool filter = true}) {
    query = query.trim();
    final nn = int.tryParse(query.split(' ')[0]);
    if (nn != null) {
      return 'SELECT * FROM HitomiColumnModel WHERE Id=$nn';
    }

    final filterExistsOnHitomi = !Settings.searchPure && filter;

    if (query.isEmpty) {
      return 'SELECT * FROM HitomiColumnModel ${filterExistsOnHitomi ? 'WHERE ExistOnHitomi=1' : ''}';
    }

    final tokens =
        splitTokens(query).map((x) => x.trim()).where((x) => x != '').toList();
    final where = QueryTranslator(tokens).parseExpression();

    return 'SELECT * FROM HitomiColumnModel WHERE $where ${filterExistsOnHitomi ? ' AND ExistOnHitomi=1' : ''}';
  }
}

class QueryTranslator {
  final List<String> tokens;
  int index = 0;

  QueryTranslator(this.tokens);

  String parseExpression() {
    if (index >= tokens.length) return '';

    String token = nextToken();
    var where = '';
    bool negative = false;

    if (token.startsWith('-')) {
      negative = true;
      if (token == '-') {
        token = nextToken();
      } else {
        token = token.substring(1);
      }
    }

    if (token.contains(':')) {
      where += parseTag(token, negative);
    } else if (token.startsWith('page') &&
        (token.contains('>') || token.contains('=') || token.contains('<'))) {
      where += parsePageExpression(token, negative);
    } else if (token == '(') {
      where += parseParentheses(token, negative);
      where += parseExpression();
      where += nextToken();
    } else if (token == ')') {
      return token;
    } else {
      where += parseTitle(token, negative);
    }

    if (hasMoreTokens() && lookAhead() != ')') {
      String logicalOp = parseLogicalOperator();
      where += logicalOp + parseExpression();
    }

    return where;
  }

  String parseTag(String token, bool negative) {
    var ss = token.split(':');
    var column = findColumnByTag(ss[0]);
    if (column == '') return '';

    var name = '';
    switch (ss[0]) {
      case 'male':
      case 'female':
        name = '|${token.replaceAll('_', ' ')}|';
        break;

      case 'tag':
      case 'series':
      case 'artist':
      case 'character':
      case 'group':
        name = '|${ss[1].replaceAll('_', ' ')}|';
        break;

      case 'uploader':
        name = ss[1];
        break;

      case 'lang':
      case 'type':
      case 'class':
        name = ss[1].replaceAll('_', ' ');
        break;

      case 'recent':
        return 'SELECT * FROM HitomiColumnModel';
    }

    var compare = "$column LIKE '%$name%'";
    if (column == 'Uploader') compare += ' COLLATE NOCASE';

    return (negative ? '($compare) IS NOT 1' : compare);
  }

  String parsePageExpression(String token, bool negative) {
    final re = RegExp(r'page([\=\<\>]{1,2})(\d+)');
    if (re.hasMatch(token)) {
      final matches = re.allMatches(token).elementAt(0);
      return 'Files ${matches.group(1)} ${matches.group(2)}';
    }
    return '';
  }

  String parseParentheses(String token, bool negative) {
    return negative ? 'NOT $token' : token;
  }

  String parseTitle(String token, bool negative) {
    return negative ? "Title NOT LIKE '%$token%'" : "Title LIKE '%$token%'";
  }

  String parseLogicalOperator() {
    String next = lookAhead();
    if (next.toLowerCase() == 'or') {
      nextToken();
      return ' OR ';
    }
    return ' AND ';
  }

  String nextToken() => tokens[index++];
  String lookAhead() => index < tokens.length ? tokens[index] : '';
  bool hasMoreTokens() => index < tokens.length - 1;

  static String findColumnByTag(String tag) {
    switch (tag) {
      case 'male':
      case 'female':
      case 'tag':
        return 'Tags';

      case 'lang':
        return 'Language';

      case 'series':
        return 'Series';

      case 'artist':
        return 'Artists';

      case 'group':
        return 'Groups';

      case 'uploader':
        return 'Uploader';

      case 'character':
        return 'Characters';

      case 'type':
        return 'Type';

      case 'class':
        return 'Class';
    }

    return tag;
  }
}
