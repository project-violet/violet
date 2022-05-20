// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

class CommentsCount {
  static List<Tuple2<int, int>> counts;

  static Future<void> init() async {
    String data;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      var file = File('/home/ubuntu/violet/assets/rank/comments.json');
      data = await file.readAsString();
    } else {
      data = await rootBundle.loadString('assets/rank/comments.json');
    }

    Map<String, dynamic> countsInfo = json.decode(data);
    counts = countsInfo.entries
        .map((x) => Tuple2<int, int>(int.parse(x.key), x.value as int))
        .toList();
    counts.sort((x, y) => y.item2.compareTo(x.item2));
  }
}
