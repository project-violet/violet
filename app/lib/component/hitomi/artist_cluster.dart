// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'package:kdtree/kdtree.dart';
import 'package:violet/algorithm/distance.dart';

class Idata {
  String title;
  int index;

  Idata({this.title, this.index});

  int compareTo(Idata id) {
    return title.compareTo(id.title);
  }

  bool operator <(Idata id) {
    return title.compareTo(id.title) < 0;
  }

  String toString() {
    return title;
  }
}

// I want to cluster those things with only a difference of one or two.
// Therefore, I don't use a clustering algorithm with a fixed number of kmc or em.
class HitomiArtistCluster {
  static int _distance(dynamic a, dynamic b) {
    return Distance.levenshteinDistance(
        a['t'].title.runes.toList(), b['t'].title.runes.toList());
  }

  // This function compares and clusters the similarity of titles.
  static List<List<int>> doClustering(List<String> titles) {
    var ctitles = List<Map<String, Idata>>();

    for (int i = 0; i < titles.length; i++) {
      var mm = Map<String, Idata>();
      mm['t'] = Idata(title: titles[i], index: i);
      ctitles.add(mm);
    }

    var tree = KDTree(ctitles, _distance, ['t']);
    var maxnode = titles.length;

    if (maxnode > 20) maxnode = 20;

    ctitles.forEach((element) {
      var near = tree.nearest(element, maxnode, 10);

      print('============================');
      print(element);
      print(near);
    });

    return null;
  }
}
