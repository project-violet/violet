// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

// Forrest based union-find data structure.
class DisjointSet {
  // Disjoint Set Array
  late List<int> array;

  DisjointSet(int n) {
    array = Iterable.generate(n, (i) => i).toList();
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

// Linked List based union-find data structure.
class UnionFind {}
