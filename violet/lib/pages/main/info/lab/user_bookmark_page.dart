// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/pages/bookmark/group_modify.dart';
import 'package:violet/pages/main/info/lab/recent_user_record.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class LabUserBookmarkPage extends StatefulWidget {
  const LabUserBookmarkPage({super.key});

  @override
  State<LabUserBookmarkPage> createState() => _LabUserBookmarkPageState();
}

class _LabUserBookmarkPageState extends State<LabUserBookmarkPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: FutureBuilder(
        future: Bookmark.getInstance().then((value) => value.getUser()),
        builder: (context, AsyncSnapshot<List<BookmarkUser>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: Text('Loading ...'),
            );
          }
          return ListView.builder(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              physics: const BouncingScrollPhysics(),
              controller: _scrollController,
              itemCount: snapshot.data!.length,
              itemBuilder: (BuildContext ctxt, int index) {
                return _buildItem(snapshot.data![index]);
              });
        },
      ),
    );
  }

  _buildItem(BookmarkUser data) {
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
          color: Settings.themeWhat
              ? Settings.themeBlack
                  ? Palette.blackThemeBackground
                  : Colors.black38
              : Colors.white,
          child: ListTile(
            title: Text(data.title() ?? data.user().substring(0, 8),
                style: const TextStyle(fontSize: 16.0)),
            subtitle: Text(data.subtitle() ?? ''),
            trailing: Text(data.datetime().split(' ')[0]),
            onTap: () {
              PlatformNavigator.navigateSlide(
                  context, LabUserRecentRecords(data.user()));
            },
            onLongPress: () async {
              var rr = await showDialog(
                context: context,
                builder: (BuildContext context) => GroupModifyPage(
                    name: data.title() ?? data.user().substring(0, 8),
                    desc: data.subtitle() ?? ''),
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
