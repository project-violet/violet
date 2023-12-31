// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/v1/community/anon.dart';

class LabRecentComments extends StatefulWidget {
  const LabRecentComments({super.key});

  @override
  State<LabRecentComments> createState() => _LabRecentCommentsState();
}

class _LabRecentCommentsState extends State<LabRecentComments> {
  List<Tuple4<DateTime, String, String, String>> comments =
      <Tuple4<DateTime, String, String, String>>[];

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      var tcomments =
          (await VioletCommunityAnonymous.getArtistCommentsRecent())['result']
              as List<dynamic>;
      comments = tcomments
          .map((e) => Tuple4<DateTime, String, String, String>(
              DateTime.parse(e['TimeStamp']),
              e['UserAppId'],
              e['Body'],
              e['ArtistName']))
          .where((x) => x.item2 != 'test')
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
              var group = e.item4.split(':').first;
              var name = e.item4.split(':').last;
              _navigate(ArtistInfoPage(
                isGroup: group == 'groups' || group == 'group',
                isUploader: group == 'uploader',
                isCharacter: group == 'character',
                isSeries: group == 'series',
                artist: name,
              ));
            },
            splashColor: Colors.white,
            child: ListTile(
              title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Text(e.item4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(e.item1.toLocal()),
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ]),
              subtitle: Text(e.item3),
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
