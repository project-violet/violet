// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/community/anon.dart';

class LabRecentComments extends StatefulWidget {
  const LabRecentComments({super.key});

  @override
  State<LabRecentComments> createState() => _LabRecentCommentsState();
}

class _LabRecentCommentsState extends State<LabRecentComments> {
  List<(DateTime, String, String, String)> comments =
      <(DateTime, String, String, String)>[];

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      var tcomments =
          (await VioletCommunityAnonymous.getArtistCommentsRecent())['result']
              as List<dynamic>;
      comments = tcomments
          .map((e) => (
                DateTime.parse(e['TimeStamp']),
                e['UserAppId'] as String,
                e['Body'] as String,
                e['ArtistName'] as String
              ))
          .where((x) => x.$2 != 'test')
          .toList();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(0),
        itemBuilder: (BuildContext ctxt, int index) {
          var e = comments[index];
          return InkWell(
            onTap: () async {
              final group = e.$4.split(':').first;
              final name = e.$4.split(':').last;
              _navigate(ArtistInfoPage(
                type: ArtistTypeHelper.fromString(group)!,
                name: name,
              ));
            },
            splashColor: Colors.white,
            child: ListTile(
              title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Text(e.$4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(e.$1.toLocal()),
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ]),
              subtitle: Text(e.$3),
            ),
          );
        },
        itemCount: comments.length,
      ),
    );
  }

  _navigate(Widget page) {
    PlatformNavigator.navigateSlide(context, page);
  }
}
