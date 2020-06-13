// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

// Forrest based on union-find data structure.
class DisjointSet {
  // Disjoint Set Array
  List<int> array;

  DisjointSet(int N) {
    array = List<int>(N);

    for (int i = 0; i < N; i++) array[i] = i;
  }

  int find(int x) {
    if (array[x] == x) return x;
    return array[x] = find(array[x]);
  }

  void union(int a, int b) {
    int aa = find(a);
    int bb = find(b);

    if (aa == bb) return;

    if (aa > bb) {
      int tt = aa;
      aa = bb;
      bb = tt;
    }

    array[bb] = aa;
  }
}
