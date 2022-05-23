// This source code is a part of Project Violet.
// Copyright (C) 2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

class ViewerReport {
  final int id;
  final int pages;
  final DateTime startsTime;

  ViewerReport({
    required this.id,
    required this.pages,
    required this.startsTime,
  });

  int? _lastPage;
  set lastPage(int value) => _lastPage = value;
  DateTime? _endsTime;
  set endsTime(DateTime value) => _endsTime = value;
  int? _validSeconds;
  set validSeconds(int value) => _validSeconds = value;
  List<int>? _msPerPages;
  set msPerPages(List<int> value) => _msPerPages = value; // unit of 100ms

  dynamic submission() {
    return {
      'id': id,
      'pages': pages,
      'startsTime': startsTime.toUtc().millisecondsSinceEpoch,
      'endsTime': _endsTime?.toUtc().millisecondsSinceEpoch,
      'lastPage': _lastPage,
      'validSeconds': _validSeconds,
      'msPerPages': jsonEncode(_msPerPages),
    };
  }
}
