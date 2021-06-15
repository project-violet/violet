// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/component/hitomi/hitomi.dart';

class TagTranslate {
  static const defaultLanguage = 'korean';
  static Map<String, String> _translateMap;

  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final subdir = Platform.isAndroid ? '/data' : '';

    final path1 =
        File('${directory.path}$subdir/result-$defaultLanguage-tag.json');
    final path2 =
        File('${directory.path}$subdir/result-$defaultLanguage-series.json');
    final path3 =
        File('${directory.path}$subdir/result-$defaultLanguage-character.json');
    if (!await path1.exists() || !await path2.exists() || !await path3.exists())
      return;

    var tag = jsonDecode(await path1.readAsString()) as Map<String, dynamic>;
    var series = jsonDecode(await path2.readAsString()) as Map<String, dynamic>;
    var character =
        jsonDecode(await path3.readAsString()) as Map<String, dynamic>;

    _translateMap = Map<String, String>();

    tag.entries.forEach((element) {
      if (element.value.toString().trim() == '') return;
      if (_translateMap.containsKey(element.key)) return;
      _translateMap[element.key] = element.value as String;
    });

    series.entries.forEach((element) {
      if (element.value.toString().trim() == '') return;
      if (_translateMap.containsKey(element.key)) return;
      _translateMap[element.key] = element.value as String;
    });

    character.entries.forEach((element) {
      if (element.value.toString().trim() == '') return;
      if (_translateMap.containsKey(element.key)) return;
      _translateMap[element.key] = element.value as String;
    });
  }

  static String of(String key) {
    if (_translateMap.containsKey(key)) return _translateMap[key];

    return HitomiManager.mapSeries2Kor(HitomiManager.mapTag2Kor(key));
  }

  static const index_letter_2 = [
    "r", "R", "rt", "s", "sw", "sg", "e", "E", //
    "f", "fr", "fa", "fq", "ft", "fe", "fv", "fg", //
    "a", "q", "Q", "qt", "t", "T", "d", "w", //
    "W", "", "z", "e", "v", "g", "k", "o", //
    "i", "O", "j", "p", "u", "P", "h", "hk", //
    "ho", "hl", "y", "n", "nj", "np", "nl", "b", //
    "m", "ml", "l", " ", "ss", "se", "st", " ", //
    "frt", "fe", "fqt", " ", "fg", "aq", "at", " ", //
    " ", "qr", "qe", "qtr", "qte", "qw", "qe", " ", //
    " ", "tr", "ts", "te", "tq", "tw", " ", "dd", //
    "d", "dt", " ", " ", "gg", " ", "yi", "yO", //
    "yl", "bu", "bP", "bl"
  ];
  static const index_initial_2 = [
    "r", "R", "s", "e", "E", "f", "a", "q", //
    "Q", "t", "T", "d", "w", "W", "", "z", //
    "x", "v", "g" //
  ];
  static const index_medial_2 = [
    "k", "o", "i", "O", "j", "p", "u", "P", //
    "h", "hk", "ho", "hl", "y", "n", "nj", "np", //
    "nl", "b", "m", "ml", "l" //
  ];
  static const index_final_2 = [
    "", "r", "R", "rt", "s", "sw", "sg", "e", //
    "f", "fr", "fa", "fq", "ft", "fx", "fv", "fg", //
    "a", "q", "qt", "t", "T", "d", "w", "", //
    "z", "x", "v", "g" //
  ];
  static const index_final_2_du = [
    't', 'w', 'g', 'r', 'a', 'q', 'x', 'v' //
  ];

  static Map<String, int> distortion(int ch) {
    var ret = Map<String, int>();
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
    return 0x1100 <= ch && ch <= 0x11ff;
  }

  static String _disassembly(int ch) {
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
      tstr += _disassembly(str.codeUnitAt(i));
    }
    return tstr;
  }
}
