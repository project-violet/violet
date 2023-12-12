// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/hitomi/comments.dart';
import 'package:violet/component/hitomi/ldi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/act_log.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/artist_info/article_list_page.dart';
import 'package:violet/pages/main/info/lab/artist_search/artist_search.dart';
import 'package:violet/pages/main/info/lab/bookmark_spy.dart';
import 'package:violet/pages/main/info/lab/recent_comments.dart';
import 'package:violet/pages/main/info/lab/recent_record.dart';
import 'package:violet/pages/main/info/lab/recent_record_u.dart';
import 'package:violet/pages/main/info/lab/search_comment.dart';
import 'package:violet/pages/main/info/lab/search_message.dart';
import 'package:violet/pages/main/info/lab/setting.dart';
import 'package:violet/pages/main/info/lab/statistics.dart';
import 'package:violet/pages/main/info/lab/top_recent.dart';
import 'package:violet/pages/main/info/lab/user_bookmark_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/settings/log_page.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/server/wsalt.dart';
import 'package:violet/settings/path.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class LaboratoryPage extends StatefulWidget {
  const LaboratoryPage({super.key});

  @override
  State<LaboratoryPage> createState() => _LaboratoryPageState();
}

class _LaboratoryPageState extends State<LaboratoryPage> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Padding(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Container(height: 16),
              _buildTitle(),
              // Container(height: 30),
              _buildItem(
                const Icon(MdiIcons.meteor, size: 40, color: Colors.brown),
                '#001 Articles',
                'Likes and Dislikes Index (LDI) DESC',
                null,
                () async {
                  if (LDI.ldi == null) await LDI.init();

                  final rr = await QueryManager.queryIds(
                      LDI.ldi!.map((e) => e.item1).take(1500).toList());

                  _navigate(ArticleListPage(name: 'LDI DESC', cc: rr));
                },
              ),
              _buildItem(
                const Icon(MdiIcons.meteor, size: 40, color: Colors.brown),
                '#002 Articles',
                'Likes and Dislikes Index (LDI) ASC',
                null,
                () async {
                  if (LDI.ldi == null) await LDI.init();

                  final rr = await QueryManager.queryIds(LDI.ldi!.reversed
                      .map((e) => e.item1)
                      .take(1500)
                      .toList());

                  _navigate(ArticleListPage(name: 'LDI ASC', cc: rr));
                },
              ),
              _buildItem(
                const Icon(MdiIcons.binoculars, size: 40, color: Colors.grey),
                '#003 Articles',
                'User Read Count DESC',
                null,
                () async {
                  final userLog = await User.getInstance()
                      .then((value) => value.getUserLog());
                  final articleCount = <String, int>{};

                  for (var element in userLog) {
                    if (!articleCount.containsKey(element.articleId())) {
                      articleCount[element.articleId()] = 0;
                    }
                    articleCount[element.articleId()] =
                        articleCount[element.articleId()]! + 1;
                  }

                  final ll = articleCount.entries.toList();
                  ll.sort((x, y) => y.value.compareTo(x.value));

                  final rr = await QueryManager.queryIds(
                      ll.map((e) => e.key).take(1500).toList());

                  _navigate(
                      ArticleListPage(name: 'User Read Count DESC', cc: rr));
                },
              ),
              _buildItem(
                const Icon(MdiIcons.binoculars, size: 40, color: Colors.grey),
                '#004 Articles',
                'User Reverse Read Record',
                null,
                () async {
                  final userLog = await User.getInstance()
                      .then((value) => value.getUserLog());
                  final articleCount = <String, int>{};

                  for (var element in userLog) {
                    if (!articleCount.containsKey(element.articleId())) {
                      articleCount[element.articleId()] = 0;
                    }
                  }

                  final ll = articleCount.entries.toList();
                  ll.sort((x, y) => y.value.compareTo(x.value));

                  final qm = await QueryManager.queryIds(
                      ll.map((e) => e.key).take(1500).toList());

                  _navigate(
                      ArticleListPage(name: 'User Read Count DESC', cc: qm));
                },
              ),
              _buildItem(
                const Icon(MdiIcons.commentTextMultiple,
                    size: 40, color: Colors.red),
                '#005 Comments',
                'Recent Artist Comments',
                null,
                () async {
                  _navigate(const LabRecentComments());
                },
              ),
              _buildItem(
                const Icon(MdiIcons.accessPointNetwork,
                    size: 40, color: Colors.orange),
                '#006 Articles',
                'Real-Time User Article Record',
                null,
                () async {
                  _navigate(const LabRecentRecords());
                },
              ),
              _buildItem(
                const Icon(MdiIcons.accessPointNetwork,
                    size: 40, color: Colors.red),
                '#007 Articles',
                'Real-Time User Article Record Picking User',
                null,
                () async {
                  _navigate(const LabRecentRecordsU());
                },
              ),
              _buildItem(
                Icon(MdiIcons.incognito,
                    size: 40, color: Colors.brown.shade700),
                '#008 Bookmarks',
                'User Bookmark List',
                null,
                () async {
                  _navigate(const LabUserBookmarkPage());
                },
              ),
              _buildItem(
                Icon(MdiIcons.keyChainVariant,
                    size: 40, color: Colors.yellow.shade700),
                '#009 Unlock',
                'Unlock Master Mode',
                null,
                () async {
                  Widget yesButton = TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: Settings.majorColor),
                    child: Text(Translations.of(context).trans('ok')),
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                  );
                  Widget noButton = TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: Settings.majorColor),
                    child: Text(Translations.of(context).trans('cancel')),
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                  );
                  TextEditingController text = TextEditingController();
                  var dialog = await showDialog(
                    useRootNavigator: false,
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      title: const Text('Input Unlock Key'),
                      content: TextField(
                        controller: text,
                        autofocus: true,
                      ),
                      actions: [yesButton, noButton],
                    ),
                  );
                  if (dialog == true) {
                    if (getValid('${text.text}saltff') == '605f372') {
                      await showOkDialog(context, 'Successful!');

                      final prefs = await MultiPreferences.getInstance();
                      await prefs.setString('labmasterkey', text.text);
                    } else {
                      await showOkDialog(context, 'Fail!');
                    }
                  }
                  // await showOkDialog(
                  //   context,
                  //   'From now on, all features will be unlocked.' +
                  //       'All users can use all functions provided by violet.',
                  // );
                },
              ),
              _buildItem(
                const Icon(MdiIcons.speedometer, size: 40, color: Colors.red),
                '#010 Top Recent',
                'Top Recent',
                null,
                () async {
                  _navigate(const LabTopRecent());
                },
              ),
              _buildItem(
                const Icon(MdiIcons.commentSearch,
                    size: 40, color: Colors.grey),
                '#011 Search Comment',
                'Search ExHentai Comment',
                null,
                () async {
                  _navigate(const LabSearchComments());
                },
              ),
              _buildItem(
                const Icon(MdiIcons.commentFlash, size: 40, color: Colors.cyan),
                '#012 Articles',
                'Sort with ExHentai Comments Count',
                null,
                () async {
                  if (CommentsCount.counts == null) await CommentsCount.init();

                  final rr = await QueryManager.queryIds(CommentsCount.counts!
                      .map((e) => e.item1)
                      .take(1500)
                      .toList());

                  _navigate(ArticleListPage(name: 'Comment Counts', cc: rr));
                },
              ),
              _buildItem(
                const Icon(MdiIcons.commentFlash, size: 40, color: Colors.cyan),
                '#013 Images',
                'Message Search',
                null,
                () async {
                  _navigate(const LabSearchMessage());
                },
              ),
              _buildItem(
                Icon(MdiIcons.incognito,
                    size: 40, color: Colors.brown.shade700),
                '#014 Bookmark Spy',
                'User\'s Bookmark List',
                null,
                () async {
                  if (!await _checkMaterKey()) {
                    await showOkDialog(context, 'You cannot use this feature!');
                    return;
                  }
                  _navigate(const LabBookmarkSpyPage());
                },
              ),
              _buildItem(
                Icon(Icons.receipt, size: 40, color: Settings.majorColor),
                '#015 Log Message',
                'Log Message',
                null,
                () async {
                  _navigate(const LogPage());
                },
              ),
              _buildItem(
                Icon(MdiIcons.cog, size: 40, color: Settings.majorColor),
                '#016 Settings',
                'Lab Settings',
                null,
                () async {
                  _navigate(const LabSetting());
                },
              ),
              _buildItem(
                const Icon(MdiIcons.chartBar, size: 40, color: Colors.lime),
                '#017 Statistics',
                'Statistics',
                null,
                () async {
                  _navigate(const Statistics());
                },
              ),
              _buildItem(
                const Icon(MdiIcons.upload, size: 40, color: Colors.teal),
                '#018 Upload Test',
                'Function',
                null,
                () async {
                  if (!await _checkMaterKey()) {
                    await showOkDialog(context, 'You cannot use this feature!');
                    return;
                  }

                  final MultiPreferences prefs =
                      await MultiPreferences.getInstance();

                  var keys = (await prefs.getKeys())
                    !.where((String key) => 
                      key != 'lib_cached_image_data' &&
                      key != 'lib_cached_image_data');
                  var values_arr = [];
                  var values_itr;
                  for(var key in keys){
                    values_arr.add(MapEntry(key, await prefs.get(key).toString()));
                    values_itr = values_arr.iterator;
                  }
                  VioletServer.uploadString(
                      'prefs.json',
                      jsonEncode(Map.fromEntries(values_itr.toList(growable: false))));

                  final dir = await DefaultPathProvider.getDocumentsDirectory();
                  await VioletServer.uploadFile('${dir}/user.db');
                  await Future.delayed(const Duration(milliseconds: 500));
                  await VioletServer.uploadFile(ActLogger.logFile.path);
                },
              ),
              _buildItem(
                const Icon(MdiIcons.accountSearch,
                    size: 40, color: Colors.amber),
                '#019 Artist Search',
                'Custom Tag Group Relation Search',
                null,
                () async {
                  _navigate(const ArtistSearch());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkMaterKey() async {
    final prefs = await MultiPreferences.getInstance();
    var key = await prefs.getString('labmasterkey');
    if (key != null && getValid('${key}saltff') == '605f372') {
      return true;
    }
    return false;
  }

  _buildTitle() {
    return Container(
      margin: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: <Widget>[
            const Icon(MdiIcons.flask, size: 100, color: Color(0xFF73BE1E)),
            const Padding(
              padding: EdgeInsets.only(top: 12),
            ),
            Text(
              'Violet Laboratory',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 16.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _buildItem(image, title, subtitle, [warp, run]) {
    return Container(
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
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
            leading: image,
            title: Text(title, style: const TextStyle(fontSize: 16.0)),
            subtitle: Text(subtitle),
            onTap: () async {
              if (warp != null) {
                await _navigate(warp);
              } else {
                await run();
              }
            },
          ),
        ),
      ),
    );
  }

  _navigate(Widget page) {
    PlatformNavigator.navigateSlide(context, page);
  }
}
