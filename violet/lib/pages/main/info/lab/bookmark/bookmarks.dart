// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks_article_list.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks_records.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class LabBookmarkPage extends StatefulWidget {
  final String userAppId;
  final String? version;

  const LabBookmarkPage({
    super.key,
    required this.userAppId,
    this.version,
  });

  @override
  State<LabBookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<LabBookmarkPage> {
  late List<BookmarkArticle> articles;
  late List<BookmarkArtist> artists;
  late List<BookmarkGroup> groups;
  late List<dynamic> records;

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: FutureBuilder(
        // future: Bookmark.getInstance().then((value) => value.getGroup()),
        future: widget.version == null
            ? VioletServer.restoreBookmark(widget.userAppId)
            : VioletServer.resotreBookmarkWithVersion(
                widget.userAppId,
                widget.version!,
              ),
        builder: (context, AsyncSnapshot<dynamic> snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: Text('Loading ...'),
            );
          }

          if (snapshot.data == null) {
            return const Center(
              child: Text('Error Occured!'),
            );
          }

          articles = (snapshot.data['article'] as List<dynamic>)
              .map((x) => BookmarkArticle(result: x))
              .toList();
          artists = (snapshot.data['artist'] as List<dynamic>)
              .map((x) => BookmarkArtist(result: x))
              .toList();
          groups = (snapshot.data['group'] as List<dynamic>)
              .map((x) => BookmarkGroup(result: x))
              .toList();
          records = snapshot.data['record'] as List<dynamic>;

          ScrollController scrollController = ScrollController();

          return ListView.builder(
              padding: EdgeInsets.fromLTRB(4, statusBarHeight + 16, 4, 8),
              physics: const BouncingScrollPhysics(),
              controller: scrollController,
              itemCount: groups.length + 1,
              itemBuilder: (BuildContext ctxt, int index) {
                return _buildItem(index, index == 0 ? null : groups[index - 1]);
              });
        },
      ),
    );
  }

  _buildItem(int index, BookmarkGroup? data) {
    index -= 1;

    String name;
    String desc;
    String date = '';
    int id;

    if (index == -1) {
      name = Translations.of(context).trans('readrecord');
      desc = Translations.of(context).trans('readrecorddesc');
      id = -1;
    } else {
      name = data!.name();
      desc = data.description();
      date = data.datetime().split(' ')[0];
      id = data.id();
    }

    if (name == 'violet_default') {
      name = Translations.of(context).trans('unclassified');
      desc = Translations.of(context).trans('unclassifieddesc');
    }

    return Container(
      key: Key('lab_bookmark_group_$id'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Settings.themeWhat ? Colors.black26 : Colors.white,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8)),
          boxShadow: [
            BoxShadow(
              color: Settings.themeWhat
                  ? Colors.black26
                  : Colors.grey.withOpacity(0.1),
              spreadRadius: Settings.themeWhat ? 0 : 5,
              blurRadius: 7,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Material(
            color: Settings.themeWhat
                ? Settings.themeBlack
                    ? Palette.blackThemeBackground
                    : Colors.black38
                : Colors.white,
            child: ListTile(
              onTap: () {
                PlatformNavigator.navigateSlide(
                    context,
                    id == -1
                        ? LabRecordViewPage(records: records)
                        : LabGroupArticleListPage(
                            articles: articles,
                            artists: artists,
                            groupId: id,
                            name: name,
                          ));
              },
              onLongPress: () async {
                if (index == -1) return;

                var yn = await showYesNoDialog(
                    context, '이 북마크 그룹을 끌어올까요?', 'Bookmark Spy');
                if (yn) {
                  // 북마크 그룹 생성
                  var groupName =
                      '${widget.userAppId.substring(0, 8)}-${data!.name()}';

                  var bookmark = await Bookmark.getInstance();
                  var gid = await bookmark.createGroup(
                      groupName,
                      data.description(),
                      Colors.black,
                      DateTime.parse(data.datetime()));

                  var dir = await getApplicationDocumentsDirectory();
                  var dbraw = await openDatabase('${dir.path}/user.db');
                  await dbraw.transaction((txn) async {
                    final batch = txn.batch();
                    for (var article in articles) {
                      if (article.group() != data.id()) continue;
                      var ref = article;
                      batch.insert(
                          'BookmarkArticle',
                          {
                            'Article': ref.article(),
                            'DateTime': ref.datetime(),
                            'GroupId': gid,
                          },
                          conflictAlgorithm: ConflictAlgorithm.fail);
                    }
                    await batch.commit();
                  });
                  await dbraw.transaction((txn) async {
                    final batch = txn.batch();
                    for (var artist in artists) {
                      if (artist.group() != data.id()) continue;
                      var ref = artist;
                      batch.insert(
                          'BookmarkArtist',
                          {
                            'Artist': ref.artist(),
                            'IsGroup': ref.type(),
                            'DateTime': ref.datetime(),
                            'GroupId': gid,
                          },
                          conflictAlgorithm: ConflictAlgorithm.fail);
                    }
                    await batch.commit();
                  });
                  await dbraw.close();

                  if (!mounted) return;
                  await showOkDialog(
                      context, '북마크 그룹을 성공적으로 끌어왔습니다!', 'Bookmark Spy');
                }
              },
              title: Text(name, style: const TextStyle(fontSize: 16.0)),
              subtitle: Text(desc),
              trailing: Text(date),
            ),
          ),
        ),
      ),
    );
  }
}
