// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/component/eh/eh_bookmark.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/toast.dart';
import 'package:timeago/timeago.dart' as timeago;

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

  BookmarkVersionSelectPage({this.userAppId, this.versions});

  @override
  _BookmarkVersionSelectPageState createState() =>
      _BookmarkVersionSelectPageState();
}

class _BookmarkVersionSelectPageState extends State<BookmarkVersionSelectPage> {
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setLocalMessages();
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
        physics: BouncingScrollPhysics(),
        controller: _scrollController,
        itemCount: widget.versions.length,
        itemBuilder: (BuildContext ctxt, int index) {
          return _buildItem(widget.versions[index] as Map<String, dynamic>);
        },
      ),
    );
  }

  static String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) +
        ' ' +
        suffixes[i];
  }

  _buildItem(Map<String, dynamic> data) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Settings.themeWhat ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.only(
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
            offset: Offset(0, 3),
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
                style: TextStyle(fontSize: 16.0)),
            subtitle: Text(formatBytes(data['size'] as int, 2)),
            onTap: () async {
              if (!Platform.isIOS) {
                await Navigator.of(context).push(PageRouteBuilder(
                    opaque: false,
                    transitionDuration: Duration(milliseconds: 500),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      var begin = Offset(0.0, 1.0);
                      var end = Offset.zero;
                      var curve = Curves.ease;

                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                    pageBuilder: (_, __, ___) => LabBookmarkPage(
                          userAppId: widget.userAppId,
                          version: data['vid'] as String,
                        )));
              } else {
                await Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => LabBookmarkPage(
                          userAppId: widget.userAppId,
                          version: data['vid'] as String,
                        )));
              }

              if (await showYesNoDialog(context, '이 북마크 버전을 선택할까요?')) {
                Navigator.pop(context, data['vid']);
              }
            },
          ),
        ),
      ),
    );
  }
}