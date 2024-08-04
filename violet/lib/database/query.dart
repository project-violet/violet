// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/database/database.dart';
import 'package:violet/settings/settings.dart';

class QueryResult {
  Map<String, dynamic> result;
  QueryResult({required this.result});

  int id() => result['Id'];
  title() => result['Title'] ?? '';
  ehash() => result['EHash'];
  type() => result['Type'];
  artists() => result['Artists'] ?? '';
  characters() => result['Characters'];
  groups() => result['Groups'];
  language() => result['Language'];
  series() => result['Series'];
  tags() => result['Tags'];
  uploader() => result['Uploader'];
  published() => result['Published'];
  files() => result['Files'];
  classname() => result['Class'];

  // For E/Ex Hentai
  publishedeh() => result['PublishedEH'];
  thumbnail() => result['Thumbnail'];
  url() => result['URL'];

  DateTime? getDateTime() {
    if (published() == null || published() == 0) {
      if (publishedeh() != null) return DateTime.parse(publishedeh());
      return null;
    }

    if (published() is! int && int.tryParse(published()) == null) {
      return DateTime.tryParse(
          '${(published() as String).replaceAll('+00:00', '')}Z');
    }

    const epochTicks = 621355968000000000;
    const ticksPerMillisecond = 10000;

    var ticksSinceEpoch = (published() as int) - epochTicks;
    var ms = ticksSinceEpoch ~/ ticksPerMillisecond;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
}

class QueryManager {
  String? queryString;
  List<QueryResult>? results;
  bool isPagination = false;
  int curPage = 0;
  int itemsPerPage = 500;

  static Future<QueryManager> query(String rawQuery) async {
    QueryManager qm = QueryManager();
    qm.queryString = rawQuery;
    qm.results = (await (await DataBaseManager.getInstance()).query(rawQuery))
        .map((e) => QueryResult(result: e))
        .toList();
    return qm;
  }

  static QueryManager queryPagination(String rawQuery) {
    QueryManager qm = QueryManager();
    qm.isPagination = true;
    qm.curPage = 0;
    qm.queryString = rawQuery;
    return qm;
  }

  Future<List<QueryResult>> next() async {
    curPage += 1;
    return (await (await DataBaseManager.getInstance()).query(
            '$queryString ORDER BY Id DESC LIMIT $itemsPerPage OFFSET ${itemsPerPage * (curPage - 1)}'))
        .map((e) => QueryResult(result: e))
        .toList();
  }

  static Future<List<QueryResult>> queryIds<T>(List<T> ids) async {
    var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
    queryRaw += 'Id IN (${ids.join(',')})';
    var qm = await QueryManager.query(
        queryRaw + (!Settings.searchPure ? ' AND ExistOnHitomi=1' : ''));

    var qr = <String, QueryResult>{};
    for (var element in qm.results!) {
      qr[element.id().toString()] = element;
    }

    var rr = ids
        .where((e) => qr.containsKey(e.toString()))
        .map((e) => qr[e.toString()]!)
        .toList();

    return rr;
  }
}
