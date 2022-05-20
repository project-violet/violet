// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/displayed_tag.dart';
import 'package:violet/component/hitomi/tag_translated_regacy.dart';

class TagTranslate {
  static const defaultLanguage = 'korean';
  // <Origin, Translated>
  static Map<String, String> _translateMap;
  // <Translated-Andro, Origin>
  static Map<String, String> _reverseAndroMap;

  static Future<void> init() async {
    String data;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      var file = File('/home/ubuntu/violet/assets/locale/tag/korean.json');
      data = await file.readAsString();
    } else {
      data = await rootBundle
          .loadString('assets/locale/tag/$defaultLanguage.json');
    }
    Map<String, dynamic> result = json.decode(data);

    _translateMap = <String, String>{};
    _reverseAndroMap = <String, String>{};

    for (var element in result.entries) {
      if (element.value.toString().trim() == '') continue;
      if (_translateMap.containsKey(element.key)) continue;
      _translateMap[element.key] = element.value as String;
      _reverseAndroMap[disassembly((element.value as String)
          .replaceAll('female:', '')
          .replaceAll('male:', ''))] = element.key;
    }
  }

  static String of(String classification, String key) {
    if (_translateMap.containsKey('$classification:$key')) {
      return _translateMap['$classification:$key'].split('|').first;
    }

    return TagTranslatedRegacy.mapSeries2Kor(
        TagTranslatedRegacy.mapTag2Kor(key));
  }

  static String ofAny(String key) {
    if (_translateMap.containsKey('series:$key')) {
      return _translateMap['series:$key'].split('|').first;
    }
    if (_translateMap.containsKey('character:$key')) {
      return _translateMap['character:$key'].split('|').first;
    }
    if (_translateMap.containsKey('tag:female:$key')) {
      return _translateMap['tag:female:$key'].split('|').first;
    }
    if (_translateMap.containsKey('tag:male:$key')) {
      return _translateMap['tag:male:$key'].split('|').first;
    }
    if (_translateMap.containsKey('tag:$key')) {
      return _translateMap['tag:$key'].split('|').first;
    }

    return TagTranslatedRegacy.mapSeries2Kor(
        TagTranslatedRegacy.mapTag2Kor(key));
  }

  // [<Origin, Translated>]
  static List<DisplayedTag> contains(String part) {
    part = part.replaceAll(' ', '');
    return _translateMap.entries
        .where((element) => element.value.replaceAll(' ', '').contains(part))
        .map((e) => DisplayedTag(tag: e.key, translated: e.value))
        .toList();
  }

  // [<Origin, Translated>]
  static List<DisplayedTag> containsAndro(String part) {
    part = disassembly(part.replaceAll(' ', ''));
    return _reverseAndroMap.entries
        .where((element) => element.key.replaceAll(' ', '').contains(part))
        .map((e) =>
            DisplayedTag(tag: e.value, translated: _translateMap[e.value]))
        .toList();
  }

  // [<Origin, Translated>]
  static List<DisplayedTag> containsTotal(String part) {
    var result = contains(part) + containsAndro(part);
    var overlap = <String>{};
    var rresult = <DisplayedTag>[];
    for (var element in result) {
      if (overlap.contains(element.getTag())) continue;
      overlap.add(element.getTag());
      rresult.add(element);
    }
    return rresult;
  }

  // [<Origin, Translated>]
  static List<Tuple2<DisplayedTag, int>> containsFuzzing(String part) {
    part = part.replaceAll(' ', '');
    var result = _translateMap.entries
        .map((e) => Tuple2<DisplayedTag, int>(
            DisplayedTag(tag: e.key, translated: e.value.split('|')[0]),
            Distance.levenshteinDistance(
                e.value.replaceAll(' ', '').split('|')[0].runes.toList(),
                part.runes.toList())))
        .toList();
    result.sort((x, y) => x.item2.compareTo(y.item2));
    return result;
  }

  // [<Origin, Translated>]
  static List<Tuple2<DisplayedTag, int>> containsFuzzingAndro(String part) {
    part = disassembly(part.replaceAll(' ', ''));
    var result = _reverseAndroMap.entries
        .map((e) => Tuple2<DisplayedTag, int>(
            DisplayedTag(
                tag: e.value, translated: _translateMap[e.value].split('|')[0]),
            Distance.levenshteinDistance(
                e.key.replaceAll(' ', '').split('|')[0].runes.toList(),
                part.runes.toList())))
        .toList();
    result.sort((x, y) => x.item2.compareTo(y.item2));
    return result;
  }

  // [<Origin, Translated>]
  static List<Tuple2<DisplayedTag, int>> containsFuzzingTotal(String part) {
    var result = containsFuzzing(part) + containsFuzzingAndro(part);
    result.sort((x, y) => x.item2.compareTo(y.item2));
    var overlap = <String>{};
    var rresult = <Tuple2<DisplayedTag, int>>[];
    for (var element in result) {
      if (overlap.contains(element.item1.getTag())) continue;
      overlap.add(element.item1.getTag());
      rresult.add(element);
    }
    return rresult;
  }

  // ignore: constant_identifier_names
  static const index_letter_2 = [
    'r', 'R', 'rt', 's', 'sw', 'sg', 'e', 'E', //
    'f', 'fr', 'fa', 'fq', 'ft', 'fe', 'fv', 'fg', //
    'a', 'q', 'Q', 'qt', 't', 'T', 'd', 'w', //
    'W', '', 'z', 'e', 'v', 'g', 'k', 'o', //
    'i', 'O', 'j', 'p', 'u', 'P', 'h', 'hk', //
    'ho', 'hl', 'y', 'n', 'nj', 'np', 'nl', 'b', //
    'm', 'ml', 'l', ' ', 'ss', 'se', 'st', ' ', //
    'frt', 'fe', 'fqt', ' ', 'fg', 'aq', 'at', ' ', //
    ' ', 'qr', 'qe', 'qtr', 'qte', 'qw', 'qe', ' ', //
    ' ', 'tr', 'ts', 'te', 'tq', 'tw', ' ', 'dd', //
    'd', 'dt', ' ', ' ', 'gg', ' ', 'yi', 'yO', //
    'yl', 'bu', 'bP', 'bl'
  ];
  // ignore: constant_identifier_names
  static const index_initial_2 = [
    'r', 'R', 's', 'e', 'E', 'f', 'a', 'q', //
    'Q', 't', 'T', 'd', 'w', 'W', 'c', 'z', //
    'x', 'v', 'g' //
  ];
  // ignore: constant_identifier_names
  static const index_medial_2 = [
    'k', 'o', 'i', 'O', 'j', 'p', 'u', 'P', //
    'h', 'hk', 'ho', 'hl', 'y', 'n', 'nj', 'np', //
    'nl', 'b', 'm', 'ml', 'l' //
  ];
  // ignore: constant_identifier_names
  static const index_final_2 = [
    '', 'r', 'R', 'rt', 's', 'sw', 'sg', 'e', //
    'f', 'fr', 'fa', 'fq', 'ft', 'fx', 'fv', 'fg', //
    'a', 'q', 'qt', 't', 'T', 'd', 'w', '', //
    'z', 'x', 'v', 'g' //
  ];
  // ignore: constant_identifier_names
  static const index_final_2_du = [
    't', 'w', 'g', 'r', 'a', 'q', 'x', 'v' //
  ];

  static Map<String, int> distortion(int ch) {
    var ret = <String, int>{};
    var unis = ch - 0xAC00;
    ret['initial'] = unis ~/ (21 * 28);
    ret['medial'] = (unis % (21 * 28)) ~/ 28;
    ret['final'] = (unis % (21 * 28)) % 28;
    return ret;
  }

  static bool checkLetter(int ch) {
    return 0xac00 <= ch && ch <= 0xd7fb;
  }

  static bool checkJamo31(int ch) {
    return 0x3131 <= ch && ch <= 0x3163;
  }

  static bool checkJamo11(int ch) {
    return 0x1100 <= ch && ch <= 0x1100 + 91 - 1;
  }

  static String disassemblyCharacter(int ch) {
    if (checkLetter(ch)) {
      var jamo = distortion(ch);
      return index_initial_2[jamo['initial']] +
          index_medial_2[jamo['medial']] +
          index_final_2[jamo['final']];
    } else if (checkJamo31(ch)) {
      return index_letter_2[ch - 0x3131];
    } else if (checkJamo11(ch)) {
      return index_letter_2[ch - 0x1100];
    }
    return String.fromCharCode(ch);
  }

  static String disassembly(String str) {
    var tstr = '';
    for (var i = 0; i < str.length; i++) {
      tstr += disassemblyCharacter(str.codeUnitAt(i));
    }
    return tstr;
  }
}
