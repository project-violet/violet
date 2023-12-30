// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/pages/main/info/lab/bookmark/bookmarks.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/v1/violet.dart';
import 'package:violet/settings/settings.dart';

class LabBookmarkSpyPage extends StatefulWidget {
  const LabBookmarkSpyPage({super.key});

  @override
  State<LabBookmarkSpyPage> createState() => _LabBookmarkSpyPageState();
}

class _LabBookmarkSpyPageState extends State<LabBookmarkSpyPage> {
  final ScrollController _scrollController = ScrollController();

  static const String dev = '1918c652d3a9';

  String _latestAccessUserAppId = '';
  List<dynamic>? bookmarks;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      bookmarks = await VioletServer.bookmarkLists();
      bookmarks!.removeWhere((element) =>
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
          ? const Center(child: Text('Loading ...'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              physics: const BouncingScrollPhysics(),
              controller: _scrollController,
              itemCount: bookmarks!.length,
              itemBuilder: (BuildContext ctxt, int index) {
                return _buildItem(bookmarks![index] as Map<String, dynamic>);
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
            title: Text(data['user'].substring(0, 8),
                style: const TextStyle(fontSize: 16.0)),
            subtitle: Text(formatBytes(data['size'] as int, 2)),
            trailing: (_latestAccessUserAppId == data['user'] as String)
                ? const Icon(
                    MdiIcons.starCircle,
                    color: Colors.green,
                  )
                : FutureBuilder(
                    future: Bookmark.getInstance().then((value) async {
                      return Tuple2(
                          await value.isBookmarkUser(data['user'] as String),
                          await value.isHistoryUser(data['user'] as String));
                    }),
                    builder:
                        (context, AsyncSnapshot<Tuple2<bool, bool>> snapshot) {
                      if (!snapshot.hasData) return const SizedBox();

                      if (snapshot.data!.item1) {
                        return const Icon(
                          MdiIcons.starCircleOutline,
                          color: Colors.yellow,
                        );
                      }

                      if (snapshot.data!.item2) {
                        return const Icon(
                          MdiIcons.rayStartVertexEnd,
                          color: Colors.grey,
                        );
                      }

                      return const SizedBox();
                    },
                  ),
            onTap: () async {
              _latestAccessUserAppId = data['user'] as String;

              var bookmark = await Bookmark.getInstance();
              await bookmark.setHistoryUser(data['user'] as String);

              await PlatformNavigator.navigateSlide(
                  context, LabBookmarkPage(userAppId: data['user'] as String));

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
