import 'dart:convert';

import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/network/wrapper.dart' as http;

class MessageSearch {
  static late final List<Tuple3<String, String, int>> autocompleteTarget;

  static bool _init = false;

  static Future<void> init() async {
    if (_init) return;
    _init = true;

    const url =
        'https://raw.githubusercontent.com/project-violet/violet-message-search/master/SORT-COMBINE.json';

    var m = jsonDecode((await http.get(url)).body) as Map<String, dynamic>;

    autocompleteTarget = m.entries
        .map((e) => Tuple3<String, String, int>(
            e.key, TagTranslate.disassembly(e.key), e.value as int))
        .toList();

    autocompleteTarget.sort((x, y) => y.item3.compareTo(x.item3));
  }
}
