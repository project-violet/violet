// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:tuple/tuple.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/script/script_runner.dart';

class ScriptManager {
  static Map<String, ScriptRunner> _caches;

  static Map<String, String> _codeUrls = {
    'hitomi_get_image_list':
        'https://raw.githubusercontent.com/project-violet/scripts/main/hitomi_get_image_list.py',
  };

  static Future<void> init() async {
    _caches = Map<String, ScriptRunner>();

    for (var kv in _codeUrls.entries) {
      var code = await http.get(kv.value);
      _caches[kv.key] = ScriptRunner(code.body);
    }
  }

  static Future<Tuple3<List<String>, List<String>, List<String>>>
      runHitomiGetImageList(int id) async {
    if (_caches == null) return null;

    try {
      await _caches['hitomi_get_image_list'].runScript({
        '\$id': RunVariable.fromInt(id),
        '\$result': RunVariable(isReady: false),
      });
      if (_caches['hitomi_get_image_list'].getValue('\$result').isReady) {
        var map = _caches['hitomi_get_image_list'].getValue('\$result').toMap();

        return Tuple3<List<String>, List<String>, List<String>>(
            (map['result'] as List<dynamic>).map((e) => e as String).toList(),
            (map['btresult'] as List<dynamic>).map((e) => e as String).toList(),
            (map['stresult'] as List<dynamic>)
                .map((e) => e as String)
                .toList());
      }
    } catch (e, st) {
      Logger.error('[script-HitomiGetImageList] E: ' +
          e.toString() +
          '\n' +
          st.toString());
    }
    return null;
  }
}
