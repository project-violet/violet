// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

class LDI {
  static List<Tuple2<int, double>> ldi;

  static Future<void> init() async {
    final data = await rootBundle.loadString('assets/rank/ldi.json');

    Map<int, dynamic> _ldi = json.decode(data);
    ldi = _ldi.entries.map((x) => Tuple2<int, double>(x.key, x.value));
    ldi.sort((x, y) => y.item2.compareTo(x.item2));
  }
}
