// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:collection/collection.dart';
import 'package:kdtree/kdtree.dart';
import 'package:violet/algorithm/disjointset.dart';
import 'package:violet/algorithm/distance.dart';

class Idata {
  String title;
  int index;

  Idata({required this.title, required this.index});

  int compareTo(Idata id) {
    return title.compareTo(id.title);
  }

  bool operator <(Idata id) {
    return title.compareTo(id.title) < 0;
  }

  @override
  String toString() {
    return title;
  }
}

// I want to cluster those things with only a difference of one or two.
// Therefore, I don't use a clustering algorithm with a fixed number of kmc or em.
class HitomiTitleCluster {
  static int _distance(dynamic a, dynamic b) {
    var astr = (a['t'].title as String).trim().replaceAll('(decensored)', '');
    var bstr = (b['t'].title as String).trim().replaceAll('(decensored)', '');

    // If there is an original title, it is written in front of '|'.

    // Compare similarity word by word. (DO NOT DELETE THIS SHIT.)
    // var abb = astr.split('|')[0].split(' ');
    // var bbb = bstr.split('|')[0].split(' ');

    // return Distance.levenshteinDistanceComparable(abb.toList(), bbb.toList());

    astr = astr.split('|')[0];
    bstr = bstr.split('|')[0];

    return Distance.levenshteinDistance(
        astr.runes.toList(), bstr.runes.toList());
  }

  // This function compares and clusters the similarity of titles.
  static List<List<int>> doClustering(List<String> titles) {
    var ctitles = <Map<String, Idata>>[];

    for (int i = 0; i < titles.length; i++) {
      var mm = <String, Idata>{};
      mm['t'] = Idata(title: titles[i], index: i);
      ctitles.add(mm);
    }

    var tree = KDTree(ctitles, _distance, ['t']);
    var maxnode = titles.length;

    if (maxnode > 100) maxnode = 100;

    var groups = <List<int>>[];
    for (var element in ctitles) {
      var near = tree.nearest(element, maxnode, 8);

      var rr = <int>[];
      for (var element in near) {
        rr.add(element[0]['t'].index);
      }

      rr.sort();
      groups.add(rr);
    }

    // Group By Same Lists
    var gg = groupBy(groups, (group) => group.join(','));
    var ds = DisjointSet(titles.length);

    // Join groups
    gg.forEach((key, value) {
      for (var element in value[0]) {
        if (value[0][0] == element) continue;
        ds.union(value[0][0], element);
      }
    });

    var join = <int, List<int>>{};
    for (int i = 0; i < titles.length; i++) {
      var v = ds.find(i);
      if (!join.containsKey(v)) join[v] = <int>[];
      join[v]!.add(i);
    }

    var result = join.values.toList();

    // result.forEach((element) {
    //   print('------------');
    //   element.forEach((element) {
    //     print(titles[element]);
    //   });
    // });

    return result;
  }
}
