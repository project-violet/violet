// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';

bool alreadyInit = false;
void setLocalMessages() {
  if (alreadyInit) return;
  alreadyInit = true;
  timeago.setLocaleMessages('ko', timeago.KoMessages());
  timeago.setLocaleMessages('de', timeago.DeMessages());
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('ja', timeago.JaMessages());
  timeago.setLocaleMessages('id', timeago.IdMessages());
  timeago.setLocaleMessages('zh', timeago.ZhMessages());
  timeago.setLocaleMessages('it', timeago.ItMessages());
  timeago.setLocaleMessages('fa', timeago.FaMessages());
  timeago.setLocaleMessages('ru', timeago.RuMessages());
  timeago.setLocaleMessages('tr', timeago.TrMessages());
  timeago.setLocaleMessages('pl', timeago.PlMessages());
  timeago.setLocaleMessages('zh', timeago.ZhMessages());
}

class BookmarkVersionSelectPage extends StatefulWidget {
  final String userAppId;
  final List<dynamic> versions;

  const BookmarkVersionSelectPage({
    super.key,
    required this.userAppId,
    required this.versions,
  });

  @override
  State<BookmarkVersionSelectPage> createState() =>
      _BookmarkVersionSelectPageState();
}

class _BookmarkVersionSelectPageState extends State<BookmarkVersionSelectPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    setLocalMessages();
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        physics: const BouncingScrollPhysics(),
        controller: _scrollController,
        itemCount: widget.versions.length,
        itemBuilder: (BuildContext ctxt, int index) {
          return _buildItem(widget.versions[index] as Map<String, dynamic>);
        },
      ),
    );
  }

  static String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  _buildItem(Map<String, dynamic> data) {
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Material(
          color: Settings.themeWhat ? Colors.black38 : Colors.white,
          child: ListTile(
            title: Text(
                timeago.format(DateTime.parse(data['dt']).toLocal(),
                    locale: Translations.of(context).locale.languageCode),
                style: const TextStyle(fontSize: 16.0)),
            subtitle: Text(formatBytes(data['size'] as int, 2)),
            onTap: () async {
              await PlatformNavigator.navigateSlide(
                  context,
                  LabBookmarkPage(
                    userAppId: widget.userAppId,
                    version: data['vid'] as String,
                  ));

              if (!mounted) return;
              if (await showYesNoDialog(context, '이 북마크 버전을 선택할까요?')) {
                if (!mounted) return;
                Navigator.pop(context, data['vid']);
              }
            },
          ),
        ),
      ),
    );
  }
}
