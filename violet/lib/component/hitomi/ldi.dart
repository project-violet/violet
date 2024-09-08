// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';

class LDI {
  static List<(int, double)>? ldi;

  static Future<void> init() async {
    String data;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final file = File(join(Directory.current.path, 'assets/rank/ldi.json'));
      data = await file.readAsString();
    } else {
      data = await rootBundle.loadString('assets/rank/ldi.json');
    }

    Map<String, dynamic> dataLdi = json.decode(data);
    ldi = dataLdi.entries
        .map((x) => (int.parse(x.key), x.value as double))
        .toList();
    ldi!.sort((x, y) => y.$2.compareTo(x.$2));
  }
}
