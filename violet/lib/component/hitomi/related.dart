// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

class Related {
  static late Map<int, List<int>> related;

  static Future<void> init() async {
    String data;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final file = File('/home/ubuntu/violet/assets/rank/related.json');
      data = await file.readAsString();
    } else {
      data = await rootBundle.loadString('assets/rank/related.json');
    }

    Future<Map<int, List<int>>> decodeJsonData() async {
      final related = <int, List<int>>{};

      json.decode(
        data,
        reviver: (key, value) {
          if (key == null) {
            return value;
          }

          if (key is String) {
            related[int.parse(key)] = (value as List<dynamic>).cast();
            return null;
          } else {
            return value;
          }
        },
      );

      return related;
    }

    related = await Isolate.run(decodeJsonData);
  }

  static bool existsRelated(int articleId) {
    return related.containsKey(articleId);
  }

  static List<int> getRelated(int articleId) {
    return related[articleId]!;
  }
}
