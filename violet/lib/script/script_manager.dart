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
      'https://raw.githubusercontent.com/project-violet/scripts/main/hitomi_get_image_list_v3.js';
  static String _scriptCache;
  static JavascriptRuntime _runtime;
  static DateTime _latestUpdate;

  static Future<void> init() async {
    _scriptCache = (await http.get(_scriptUrl)).body;
    _latestUpdate = DateTime.now();
    _initRuntime();
  }

  static Future<bool> refresh() async {
    if (DateTime.now().difference(_latestUpdate).inMinutes < 10) {
      return false;
    }

    _latestUpdate = DateTime.now();

    var scriptTemp = _scriptCache;
    await init();

    if (_scriptCache != scriptTemp) {
      _initRuntime();
      ProviderManager.refresh();
      return true;
    }

    return false;
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
      _runtime.evaluate(galleryInfo.body);
      final jResult = _runtime.evaluate("hitomi_get_image_list()").stringResult;
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
  }
}
