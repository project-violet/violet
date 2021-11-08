// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/bookmark/group_modify.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks.dart';
import 'package:violet/pages/main/info/lab/recent_user_record.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';

class LabBookmarkSpyPage extends StatefulWidget {
  @override
  _LabBookmarkSpyPageState createState() => _LabBookmarkSpyPageState();
}

class _LabBookmarkSpyPageState extends State<LabBookmarkSpyPage> {
  ScrollController _scrollController = ScrollController();

  static const String dev = 'aee70691afaa';

  String _latestAccessUserAppId = '';
  List<dynamic> bookmarks;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      bookmarks = await VioletServer.bookmarkLists();
      bookmarks.removeWhere((element) =>
          ((element as Map<String, dynamic>)['user'] as String)
              .startsWith(dev));

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: bookmarks == null
          ? Container(child: Center(child: Text('Loading ...')))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
              physics: BouncingScrollPhysics(),
              controller: _scrollController,
              itemCount: bookmarks.length,
              itemBuilder: (BuildContext ctxt, int index) {
                return _buildItem(bookmarks[index] as Map<String, dynamic>);
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
            title: Text(data['user'].substring(0, 8),
                style: TextStyle(fontSize: 16.0)),
            subtitle: Text(formatBytes(data['size'] as int, 2)),
            trailing: (_latestAccessUserAppId == data['user'] as String)
                ? Icon(
                    MdiIcons.starCircle,
                    color: Colors.green,
                  )
                : FutureBuilder(
                    future: Bookmark.getInstance().then((value) async {
                      return [
                        await value.isBookmarkUser(data['user'] as String),
                        await value.isHistoryUser(data['user'] as String)
                      ];
                    }),
                    builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                      if (!snapshot.hasData) return null;

                      if (snapshot.data[0] as bool)
                        return Icon(
                          MdiIcons.starCircleOutline,
                          color: Colors.yellow,
                        );

                      if (snapshot.data[1] as bool)
                        return Icon(
                          MdiIcons.rayStartVertexEnd,
                          color: Colors.grey,
                        );

                      return null;
                    },
                  ),
            onTap: () async {
              _latestAccessUserAppId = data['user'] as String;

              var bookmark = await Bookmark.getInstance();
              await bookmark.setHistoryUser(data['user'] as String);

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
                    pageBuilder: (_, __, ___) =>
                        LabBookmarkPage(userAppId: data['user'] as String)));
              } else {
                await Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) =>
                        LabBookmarkPage(userAppId: data['user'] as String)));
              }
              setState(() {});
            },
            onLongPress: () async {
              var bookmark = await Bookmark.getInstance();
              if (await bookmark.isBookmarkUser(data['user'] as String)) {
                await (await Bookmark.getInstance())
                    .unbookmarkUser(data['user'] as String);
                setState(() {});
              } else {
                await (await Bookmark.getInstance())
                    .bookmarkUser(data['user'] as String);
                setState(() {});
              }
            },
          ),
        ),
      ),
    );
  }
}
