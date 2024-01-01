// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

class LDI {
  static List<Tuple2<int, double>>? ldi;

  static Future<void> init() async {
    String data;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      var file = File('/home/ubuntu/violet/assets/rank/ldi.json');
      data = await file.readAsString();
    } else {
      data = await rootBundle.loadString('assets/rank/ldi.json');
    }

    Map<String, dynamic> dataLdi = json.decode(data);
    ldi = dataLdi.entries
        .map((x) => Tuple2<int, double>(int.parse(x.key), x.value as double))
        .toList();
    ldi!.sort((x, y) => y.item2.compareTo(x.item2));
  }
}
