// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:get/get.dart';

class TagGroupModifyController extends GetxController {
  late final RxMap<String, int> items;

  TagGroupModifyController(Map<String, int> items) {
    this.items = items.obs;
  }

  bool _mustSorted = false;
  List<MapEntry<String, int>>? _cached;

  MapEntry<String, int> getItem(int index) {
    if (_mustSorted || _cached == null) {
      _mustSorted = true;
      _cached = items.entries.toList();
      _cached!.sort((a, b) => b.value.compareTo(a.value));
    }

    return _cached![index];
  }

  /// if tag already exists return false
  bool addItem(String tag, int initialCount) {
    if (items.containsKey(tag)) return false;
    items[tag] = initialCount;
    _mustSorted = true;
    return true;
  }

  addItems(List<String> tags) {
    items.addAll({for (var tag in tags) tag: 1});
    _mustSorted = true;
  }

  removeItem(String tag) {
    if (items.containsKey(tag)) {
      items.remove(tag);
      _mustSorted = true;
    }
  }

  modifyItem(String tag, int count) {
    items[tag] = count;
    _mustSorted = true;
  }

  removeAll() {
    items.clear();
    _mustSorted = true;
  }
}
