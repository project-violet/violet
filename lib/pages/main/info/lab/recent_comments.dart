// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/community/anon.dart';

class LabRecentComments extends StatefulWidget {
  @override
  _LabRecentCommentsState createState() => _LabRecentCommentsState();
}

class _LabRecentCommentsState extends State<LabRecentComments> {
  List<Tuple4<DateTime, String, String, String>> comments =
      <Tuple4<DateTime, String, String, String>>[];

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100)).then((value) async {
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
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.all(0),
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
                    Text(e.item2.substring(0, 6)),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                            '${DateFormat('yyyy-MM-dd HH:mm').format(e.item1.toLocal())}',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ]),
              subtitle: Text('<${e.item4}>\n${e.item3}'),
            ),
          );
        },
        itemCount: comments.length,
      ),
    );
  }

  _navigate(Widget page) {
    if (!Platform.isIOS) {
      Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.ease;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        pageBuilder: (_, __, ___) => page,
      ));
    } else {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
    }
  }
}
