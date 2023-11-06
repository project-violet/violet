// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/component/hitomi/population.dart';
import 'package:violet/database/query.dart';

class FilterController {
  var isOr = false;
  var isSearch = false;
  var isPopulationSort = false;
  String heroKey;

  var tagStates = <String, bool>{};
  var groupStates = <String, bool>{};

  FilterController({this.heroKey = 'searchtype'});

  List<QueryResult> applyFilter(List<QueryResult> queryResult) {
    final result = <QueryResult>[];

    for (var element in queryResult) {
      // key := <group>:<name>
      var succ = !isOr;
      tagStates.forEach((key, value) {
        if (!value) return;

        // Check match just only one
        if (succ == isOr) return;

        // Get db column name from group
        final split = key.split('|');
        final dbColumn = prefix2Tag(split[0]);

        // There is no matched db column name
        if (element.result[dbColumn] == null && !isOr) {
          succ = false;
          return;
        }

        // If Single Tag
        if (!isSingleTag(split[0])) {
          var tag = split[1];
          if (['female', 'male'].contains(split[0])) {
            tag = '${split[0]}:${split[1]}';
          }
          if ((element.result[dbColumn] as String).contains('|$tag|') == isOr) {
            succ = isOr;
          }
        }

        // If Multitag
        else if ((element.result[dbColumn] as String == split[1]) == isOr) {
          succ = isOr;
        }
      });
      if (succ) result.add(element);
    }

    if (isPopulationSort) {
      Population.sortByPopulation(result);
    }

    return result;
  }

  static String prefix2Tag(String prefix) {
    switch (prefix) {
      case 'artist':
        return 'Artists';
      case 'group':
        return 'Groups';
      case 'language':
        return 'Language';
      case 'character':
        return 'Characters';
      case 'series':
        return 'Series';
      case 'class':
        return 'Class';
      case 'type':
        return 'Type';
      case 'uploader':
        return 'Uploader';
      case 'tag':
      case 'female':
      case 'male':
        return 'Tags';
    }
    return '';
  }

  static bool isSingleTag(String prefix) {
    switch (prefix) {
      case 'language':
      case 'class':
      case 'type':
      case 'uploader':
        return true;
      case 'artist':
      case 'group':
      case 'character':
      case 'tag':
      case 'female':
      case 'male':
      case 'series':
      default:
        return false;
    }
  }
}
