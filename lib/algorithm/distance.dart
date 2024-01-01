// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// Implementation of distance functions that satisfy triangle inequality.

import 'dart:math';

class Distance {
  static int hammingDistance<T extends num>(List<T> l1, List<T> l2) {
    if (l1.length != l2.length) return -1;

    int result = 0;
    for (int i = 0; i < l1.length; i++) {
      if (l1[i] != l2[i]) result++;
    }

    return result;
  }

  // Why is fuck num not a comparable<t> interface?
  // Why fuck I have to make two identical functions?
  static int levenshteinDistance<T extends num>(List<T> l1, List<T> l2) {
    int x = l1.length;
    int y = l2.length;
    int i, j;

    if (x == 0) return x;
    if (y == 0) return y;
    var v0 = List.filled((y + 1) << 1, 0);

    for (i = 0; i < y + 1; i++) {
      v0[i] = i;
    }
    for (i = 0; i < x; i++) {
      v0[y + 1] = i + 1;
      for (j = 0; j < y; j++) {
        v0[y + j + 2] = min(min(v0[y + j + 1], v0[j + 1]) + 1,
            v0[j] + ((l1[i] == l2[j]) ? 0 : 1));
      }
      for (j = 0; j < y + 1; j++) {
        v0[j] = v0[y + j + 1];
      }
    }

    return v0[y + y + 1];
  }

  static int levenshteinDistanceComparable<T extends Comparable<T>>(
      List<T> l1, List<T> l2) {
    int x = l1.length;
    int y = l2.length;
    int i, j;

    if (x == 0) return x;
    if (y == 0) return y;
    var v0 = List.filled((y + 1) << 1, 0);

    for (i = 0; i < y + 1; i++) {
      v0[i] = i;
    }
    for (i = 0; i < x; i++) {
      v0[y + 1] = i + 1;
      for (j = 0; j < y; j++) {
        v0[y + j + 2] = min(min(v0[y + j + 1], v0[j + 1]) + 1,
            v0[j] + ((l1[i] == l2[j]) ? 0 : 1));
      }
      for (j = 0; j < y + 1; j++) {
        v0[j] = v0[y + j + 1];
      }
    }

    return v0[y + y + 1];
  }

  static int levenshteinDistanceString(String s1, String s2) {
    final l1 = s1.runes.map((rune) => rune.toString()).toList();
    final l2 = s2.runes.map((rune) => rune.toString()).toList();
    return levenshteinDistanceComparable(l1, l2);
  }

  static List<int> levenshteinDistanceRoute<T extends num>(
      List<T> l1, List<T> l2) {
    List<List<int>> dist = List.generate(
        l1.length + 1, (i) => List.filled(l2.length + 1, 0),
        growable: false);

    for (int i = 0; i <= l1.length; i++) {
      dist[i][0] = i;
    }
    for (int j = 0; j <= l2.length; j++) {
      dist[0][j] = j;
    }

    for (int j = 1; j <= l2.length; j++) {
      for (int i = 1; i <= l1.length; i++) {
        if (l1[i - 1] == l2[j - 1]) {
          dist[i][j] = dist[i - 1][j - 1];
        } else {
          dist[i][j] = min(dist[i - 1][j - 1] + 1,
              min(dist[i][j - 1] + 1, dist[i - 1][j] + 1));
        }
      }
    }

    List<int> route = List.filled(l1.length + 1, 0);
    int fz = dist[l1.length][l2.length];
    for (int i = l1.length, j = l2.length; i >= 0 && j >= 0;) {
      int lu = 987654321;
      int u = 987654321;
      int l = 987654321;
      if (i - 1 >= 0 && j - 1 >= 0) lu = dist[i - 1][j - 1];
      if (i - 1 >= 0) u = dist[i - 1][j];
      if (j - 1 >= 0) l = dist[i][j - 1];
      int mm = min(lu, min(l, u));
      if (mm == fz) route[i] = 1;
      if (mm == lu) {
        i--;
        j--;
      } else if (mm == u) {
        i--;
      } else {
        j--;
      }
      fz = mm;
    }
    return route;
  }

  // dynamic must be double, int
  static double cosineDistance(
      Map<String, dynamic> l1, Map<String, dynamic> l2) {
    double xx = 0;
    double yy = 0;

    l1.forEach((x, y) => xx += y * y);
    l2.forEach((x, y) => yy += y * y);

    if (xx == 0 || yy == 0) return 0;

    xx = sqrt(xx);
    yy = sqrt(yy);

    double dist = 0.0;

    l1.forEach((key, value) {
      if (l2.containsKey(key)) dist += value * l2[key];
    });

    return dist / (xx * yy) * 100;
  }
}
