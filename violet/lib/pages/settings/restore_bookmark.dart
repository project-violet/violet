// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/log/log.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class RestoreBookmarkPage extends StatefulWidget {
  final dynamic source;
  final bool restoreWithRecord;

  const RestoreBookmarkPage({
    super.key,
    required this.source,
    required this.restoreWithRecord,
  });

  @override
  State<RestoreBookmarkPage> createState() => _RestoreBookmarkPageState();
}

class _RestoreBookmarkPageState extends State<RestoreBookmarkPage> {
  int total = 0;
  int progress = 0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      try {
        var articles = widget.source['article'] as List<dynamic>;
        var artists = widget.source['artist'] as List<dynamic>;
        var groups = widget.source['group'] as List<dynamic>;

        // 북마크 그룹 생성
        var groupInv = <int, int>{};

        total += articles.length + artists.length + groups.length;

        var bookmark = await Bookmark.getInstance();
        for (var group in groups) {
          var ref = BookmarkGroup(result: group);
          var gid = await bookmark.createGroup(ref.name(), ref.description(),
              Colors.black, DateTime.parse(ref.datetime()));
          groupInv[ref.id()] = gid;
          setState(() => progress++);
        }

        // 북마크 작품 처리
        var dir = await getApplicationDocumentsDirectory();
        var dbraw = await openDatabase('${dir.path}/user.db');
        await dbraw.transaction((txn) async {
          final batch = txn.batch();
          for (var article in articles) {
            var ref = BookmarkArticle(result: article);
            batch.insert(
                'BookmarkArticle',
                {
                  'Article': ref.article(),
                  'DateTime': ref.datetime(),
                  'GroupId': groupInv[ref.group()],
                },
                conflictAlgorithm: ConflictAlgorithm.fail);
            setState(() => progress++);
          }
          await batch.commit();
        });
        await dbraw.transaction((txn) async {
          final batch = txn.batch();
          for (var artist in artists) {
            var ref = BookmarkArtist(result: artist);
            batch.insert(
                'BookmarkArtist',
                {
                  'Artist': ref.artist(),
                  'IsGroup': ref.type(),
                  'DateTime': ref.datetime(),
                  'GroupId': groupInv[ref.group()],
                },
                conflictAlgorithm: ConflictAlgorithm.fail);
            setState(() => progress++);
          }
          await batch.commit();
        });
        if (widget.restoreWithRecord) {
          var records = widget.source['record'] as List<dynamic>;

          await dbraw.transaction((txn) async {
            final batch = txn.batch();
            for (var record in records) {
              var ref = ArticleReadLog(result: record);
              batch.insert(
                  'ArticleReadLog',
                  {
                    'Article': ref.articleId(),
                    'DateTimeStart': ref.datetimeStart(),
                    'DateTimeEnd': ref.datetimeEnd(),
                    'LastPage': ref.lastPage(),
                    'Type': ref.type(),
                  },
                  conflictAlgorithm: ConflictAlgorithm.fail);
              setState(() => progress++);
            }
            await batch.commit();
          });
        }
        await dbraw.close();
      } catch (e, st) {
        Logger.error('[Restore Bookmark] $e\n'
            '$st');
        showToast(
          level: ToastLevel.error,
          message: 'Bookmark Restoring Error!',
        );

        if (!mounted) return;
        Navigator.pop(context, false);
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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
                  ? Palette.darkThemeBackground
                  : Palette.lightThemeBackground,
              elevation: 100,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: (56 * 4 + 16).toDouble(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    // child: Column(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: <Widget>[
                    //     CircularProgressIndicator(),
                    //     Expanded(
                    //       child: Container(child: Text('초기화 중...')),
                    //     )
                    //   ],
                    // ),
                    child: Stack(
                      children: [
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                        const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 33),
                            child: Text(
                              '북마크 복원중...',
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Text(
                              '$progress/$total',
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
}
