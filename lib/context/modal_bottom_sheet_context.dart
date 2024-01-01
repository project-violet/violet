// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

class ModalBottomSheetContext {
  static int _count = 0;

  static int getCount() => _count;

  static int up() => _count++;
  static int down() => _count--;
}
