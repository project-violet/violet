// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

// https://github.com/mezoni/semaphore/blob/master/lib/src/semaphore/semaphore.dart
class Semaphore {
  final int maxCount;

  int _currentCount = 0;

  Semaphore({
    @required this.maxCount,
  });

  final Queue<Completer> _waitQueue = Queue<Completer>();

  Future<int> acquire(int index) {
    var completer = Completer<int>();

    if (_currentCount + 1 <= maxCount) {
      _currentCount++;
      completer.complete();
    } else {
      _waitQueue.add(completer);
    }

    return completer.future;
  }

  void drop() {
    _waitQueue.clear();
  }

  Future<void> release() async {
    _currentCount--;
    if (_waitQueue.isNotEmpty) {
      _currentCount++;
      final completer = _waitQueue.removeFirst();
      completer.complete();
    }
  }
}
