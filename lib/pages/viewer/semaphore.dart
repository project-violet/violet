// https://github.com/mezoni/semaphore/blob/master/lib/src/semaphore/semaphore.dart
// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:collection';

import 'package:tuple/tuple.dart';

class Semaphore {
  final int maxCount = 8;
  HashSet<int> has = HashSet<int>();
  HashSet<int> completed = HashSet<int>();

  int _currentCount = 0;

  final Queue<Tuple2<int, Completer>> _waitQueue =
      Queue<Tuple2<int, Completer>>();

  Future<int> acquire(int index) {
    var completer = Completer<int>();

    if (_currentCount + 1 <= maxCount || completed.contains(index)) {
      _currentCount++;
      completed.add(index);
      completer.complete(2);
    } else {
      has.add(index);

      if (has.add(index)) {
        var ww = _waitQueue.where((element) => element.item1 == index);
        return ww.first.item2.future;
      }

      _waitQueue.add(Tuple2<int, Completer>(index, completer));
    }

    return completer.future;
  }

  void adjust(int index) {
    if (_waitQueue.length == 0) return;
    var ww = _waitQueue.where((element) => element.item1 == index);
    if (ww == null || ww.length == 0) return;
    var aa = ww.first;

    _waitQueue.removeWhere((element) => element.item1 == index);
    _waitQueue.addFirst(aa);
  }

  void drop() {
    _waitQueue.clear();
  }

  void release() {
    _currentCount--;
    if (_waitQueue.isNotEmpty) {
      _currentCount++;
      final completer = _waitQueue.removeFirst();
      completed.add(completer.item1);
      completer.item2.complete();
    }
  }
}
