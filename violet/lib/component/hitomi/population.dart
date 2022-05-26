// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/download.dart';

class Population {
  static late Map<int, int> population;

  static Future<void> init() async {
    String data;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      var file = File('/home/ubuntu/violet/assets/rank/population.json');
      data = await file.readAsString();
    } else
      data = await rootBundle.loadString('assets/rank/population.json');

    List<dynamic> dataPopulation = json.decode(data);
    population = Map<int, int>();

    for (int i = 0; i < dataPopulation.length; i++) {
      population[dataPopulation[i] as int] = i;
    }
  }

  static void sortByPopulation(List<QueryResult> qr) {
    qr.sort((x, y) => compare(x, y));
  }

  static void sortByPopulationDownloadItem(List<DownloadItemModel> qr) {
    qr.sort((x, y) => compareDownloadItem(x, y));
  }

  static int compare(QueryResult a, QueryResult b) {
    // newest article always displayed on the bottom
    if (!population.containsKey(a.id())) {
      // a == b
      if (!population.containsKey(b.id())) return 0;
      // a > b
      return 1;
    }
    // a < b
    if (!population.containsKey(b.id())) return -1;

    return population[a.id()]!.compareTo(population[b.id()]!);
  }

  static int compareDownloadItem(DownloadItemModel a, DownloadItemModel b) {
    // newest article always displayed on the bottom
    if (!population.containsKey(a.id())) {
      // a == b
      if (!population.containsKey(b.id())) return 0;
      // a > b
      return 1;
    }
    // a < b
    if (!population.containsKey(b.id())) return -1;

    return population[a.id()]!.compareTo(population[b.id()]!);
  }
}
