// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class ScriptManager {
  static const String _scriptUrl =
      'https://raw.githubusercontent.com/project-violet/scripts/main/hitomi_get_image_list_v2.js';
  static String _scriptCache;
  static JavascriptRuntime _runtime;

  static Future<void> init() async {
    _scriptCache = (await http.get(_scriptUrl)).body;
    _initRuntime();
  }

  static Future<void> refresh() async {
    var scriptTemp = _scriptCache;
    await init();

    if (_scriptCache != scriptTemp) {
      _initRuntime();
      ProviderManager.refresh();
    }
  }

  static void _initRuntime() {
    _runtime = getJavascriptRuntime();
    _runtime.evaluate(_scriptCache);
  }

  static Future<Tuple3<List<String>, List<String>, List<String>>>
      runHitomiGetImageList(int id) async {
    if (_scriptCache == null) return null;
    try {
      var downloadUrl =
          _runtime.evaluate("create_download_url('$id')").stringResult;
      var galleryInfo = await http.get(downloadUrl);
      final jResult = _runtime
          .evaluate(
              "hitomi_get_image_list('$id', \"${galleryInfo.body.replaceAll('"', '\\"')}\")")
          .stringResult;
      final jResultObject = jsonDecode(jResult);

      if (jResultObject is Map<dynamic, dynamic>) {
        return Tuple3<List<String>, List<String>, List<String>>(
            (jResultObject["result"] as List<dynamic>)
                .map((e) => e as String)
                .toList(),
            (jResultObject["btresult"] as List<dynamic>)
                .map((e) => e as String)
                .toList(),
            (jResultObject["stresult"] as List<dynamic>)
                .map((e) => e as String)
                .toList());
      } else {
        Logger.error(
            '[script-HitomiGetImageList] E: JSError\nId: $id\nMessage: ' +
                jResult.toString());
        return null;
      }
    } catch (e, st) {
      Logger.error('[script-HitomiGetImageList] E: ' +
          e.toString() +
          '\nId: $id\n' +
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
