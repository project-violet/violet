// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

extension ChunkListExtension<T> on List<T> {
  Iterable<(int, List<T>)> chunk(int size) sync* {
    for (int i = 0; i < length; i += size) {
      yield (i ~/ size, sublist(i, i + size < length ? i + size : length));
    }
  }
}
