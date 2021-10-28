// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter_js/flutter_js.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;

class ScriptManager {
  static Map<String, String> _caches;

  static Map<String, String> _codeUrls = {
    'hitomi_get_image_list':
        'https://raw.githubusercontent.com/project-violet/scripts/main/hitomi_get_image_list.js',
  };

  static Future<void> init() async {
    _caches = Map<String, String>();

    for (var kv in _codeUrls.entries) {
      var code = await http.get(kv.value);
      _caches[kv.key] = code.body;
    }
  }

  static Future<Tuple3<List<String>, List<String>, List<String>>>
      runHitomiGetImageList(int id) async {
    if (_caches == null) return null;
    try {
      JavascriptRuntime flutterJs;
      flutterJs = getJavascriptRuntime();
      flutterJs.evaluate(_caches['hitomi_get_image_list']);
      var downloadUrl =
          flutterJs.evaluate("create_download_url('$id')").rawResult as String;
      var galleryInfo = await http.get(downloadUrl);
      final jResult = flutterJs
          .evaluate(
              "hitomi_get_image_list('$id', \"${galleryInfo.body.replaceAll('"', '\\"')}\")")
          .rawResult as Map<dynamic, dynamic>;

      return Tuple3<List<String>, List<String>, List<String>>(
          (jResult["result"] as List<dynamic>).map((e) => e as String).toList(),
          (jResult["btresult"] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
          (jResult["stresult"] as List<dynamic>)
              .map((e) => e as String)
              .toList());
    } catch (e, st) {
      Logger.error('[script-HitomiGetImageList] E: ' +
          e.toString() +
          '\n' +
          st.toString());
      return null;
    }

    //jResult.

    /*var isolate = ScriptIsolate(_caches['hitomi_get_image_list']);
    var isRelease = false;

    try {
      await isolate.runScript({
        '\$id': RunVariable.fromInt(id),
        '\$result': RunVariable(isReady: false),
      });
      isRelease = true;
      if (isolate.getValue('\$result').isReady) {
        var map = isolate.getValue('\$result').toMap();

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
    return null;*/
  }
}
