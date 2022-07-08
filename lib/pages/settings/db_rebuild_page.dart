// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/settings/settings.dart';

class DBRebuildPage extends StatefulWidget {
  const DBRebuildPage({Key? key}) : super(key: key);

  @override
  State<DBRebuildPage> createState() => _DBRebuildPagePageState();
}

class _DBRebuildPagePageState extends State<DBRebuildPage> {
  String baseString = '';

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      await indexing();

      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(1)),
          boxShadow: [
            BoxShadow(
              color: Settings.themeWhat
                  ? Colors.black.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 1,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Card(
              color: Settings.themeWhat
                  ? const Color(0xFF353535)
                  : Colors.grey.shade100,
              elevation: 100,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: (56 * 4 + 16).toDouble(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Stack(
                      children: const [
                        Center(
                          child: CircularProgressIndicator(),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 33),
                            child: Text(
                              'Processing...',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void insert(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr is! String) return;
    if (qr.isEmpty) return;

    for (var tag in (qr).split('|')) {
      if (tag.isEmpty) continue;

      if (!map.containsKey(tag)) map[tag] = 0;
      map[tag] = map[tag]! + 1;
    }
  }

  void insertSingle(Map<String, int> map, dynamic qr) {
    if (qr == null) return;
    if (qr is! String) return;
    if (qr.isEmpty) return;

    if (!map.containsKey(qr)) map[qr] = 0;
    map[qr] = map[qr]! + 1;
  }

  Future indexing() async {
    var sql = HitomiManager.translate2query(
        '${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}');

    await (await DataBaseManager.getInstance()).delete('HitomiColumnModel',
        'NOT (${sql.substring(sql.indexOf('WHERE') + 6)})', []);
  }
}
