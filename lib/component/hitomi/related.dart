// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class Related {
  static late Map<int, List<int>> related;

  static Future<void> init() async {
    String data;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      var file = File('/home/ubuntu/violet/assets/rank/related.json');
      data = await file.readAsString();
    } else {
      data = await rootBundle.loadString('assets/rank/related.json');
    }

    Map<String, dynamic> dataMap = json.decode(data);

    related = <int, List<int>>{};

    dataMap.entries.forEach((element) {
      related[int.parse(element.key)] =
          (element.value as List<dynamic>).map((e) => e as int).toList();
    });
  }

  static bool existsRelated(int articleId) {
    return related.containsKey(articleId);
  }

  static List<int> getRelated(int articleId) {
    return related[articleId]!;
  }
}
