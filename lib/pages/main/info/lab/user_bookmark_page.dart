// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/pages/bookmark/group_modify.dart';
import 'package:violet/pages/main/info/lab/recent_user_record.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/settings/settings.dart';

class LabUserBookmarkPage extends StatefulWidget {
  @override
  _LabUserBookmarkPageState createState() => _LabUserBookmarkPageState();
}

class _LabUserBookmarkPageState extends State<LabUserBookmarkPage> {
  ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: FutureBuilder(
        future: Bookmark.getInstance().then((value) => value.getUser()),
        builder: (context, AsyncSnapshot<List<BookmarkUser>> snapshot) {
          if (!snapshot.hasData)
            return Container(
              child: Center(
                child: Text('Loading ...'),
              ),
            );
          return ListView.builder(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
              physics: BouncingScrollPhysics(),
              controller: _scrollController,
              itemCount: snapshot.data.length,
              itemBuilder: (BuildContext ctxt, int index) {
                return _buildItem(snapshot.data[index]);
              });
        },
      ),
    );
  }

  _buildItem(BookmarkUser data) {
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
            title: Text(data.title() ?? data.user().substring(0, 8),
                style: TextStyle(fontSize: 16.0)),
            subtitle: Text(data.subtitle() ?? ''),
            trailing: Text(data.datetime().split(' ')[0]),
            onTap: () {
              if (!Platform.isIOS) {
                Navigator.of(context).push(PageRouteBuilder(
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
                        LabUserRecentRecords(data.user())));
              } else {
                Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => LabUserRecentRecords(data.user())));
              }
            },
            onLongPress: () async {
              var rr = await showDialog(
                context: context,
                builder: (BuildContext context) => GroupModifyPage(
                    name: data.title() ?? data.user().substring(0, 8),
                    desc: data.subtitle()),
              );

              if (rr == null) return;

              if (rr[0] == 2) {
                await (await Bookmark.getInstance()).deleteUser(data);
                setState(() {});
              } else if (rr[0] == 1) {
                var nname = rr[1] as String;
                var ndesc = rr[2] as String;

                var rrt = Map<String, dynamic>.from(data.result);

                rrt['Title'] = nname;
                rrt['Subtitle'] = ndesc;

                await (await Bookmark.getInstance())
                    .modfiyUser(BookmarkUser(result: rrt));
                setState(() {});
              }
            },
          ),
        ),
      ),
    );
  }
}
