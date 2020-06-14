// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

// Implementation of distance functions that satisfy triangle inequality.

import 'dart:math';

class Distance {
  static int hammingDistance<T extends num>(List<T> l1, List<T> l2) {
    if (l1.length != l2.length) return -1;

    int result = 0;
    for (int i = 0; i < l1.length; i++) if (l1[i] != l2[i]) result++;

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
    var v0 = List<int>((y + 1) << 1);

    for (i = 0; i < y + 1; i++) v0[i] = i;
    for (i = 0; i < x; i++) {
      v0[y + 1] = i + 1;
      for (j = 0; j < y; j++)
        v0[y + j + 2] = min(min(v0[y + j + 1], v0[j + 1]) + 1,
            v0[j] + ((l1[i] == l2[j]) ? 0 : 1));
      for (j = 0; j < y + 1; j++) v0[j] = v0[y + j + 1];
    }

    return v0[y + y + 1];
  }
  
  static int levenshteinDistanceComparable<T extends Comparable<T>>(List<T> l1, List<T> l2) {
    int x = l1.length;
    int y = l2.length;
    int i, j;

    if (x == 0) return x;
    if (y == 0) return y;
    var v0 = List<int>((y + 1) << 1);

    for (i = 0; i < y + 1; i++) v0[i] = i;
    for (i = 0; i < x; i++) {
      v0[y + 1] = i + 1;
      for (j = 0; j < y; j++)
        v0[y + j + 2] = min(min(v0[y + j + 1], v0[j + 1]) + 1,
            v0[j] + ((l1[i] == l2[j]) ? 0 : 1));
      for (j = 0; j < y + 1; j++) v0[j] = v0[y + j + 1];
    }

    return v0[y + y + 1];
  }
}
