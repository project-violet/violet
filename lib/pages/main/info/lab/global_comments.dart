// This source code is a part of Project Violet.
// Copyright (C) 2020-2021. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mdi/mdi.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/recent_user_record.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/settings/settings.dart';

class LabGlobalComments extends StatefulWidget {
  @override
  _LabGlobalCommentsState createState() => _LabGlobalCommentsState();
}

class _LabGlobalCommentsState extends State<LabGlobalComments> {
  List<Tuple5<int, DateTime, String, String, int>> comments =
      <Tuple5<int, DateTime, String, String, int>>[];
  ScrollController _controller = ScrollController();
  FocusNode myFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100))
        .then((value) async => await readComments());
  }

  TextEditingController text = TextEditingController();

  Future<void> readComments() async {
    var tcomments = (await VioletCommunityAnonymous.getArtistComments(
        'global_general'))['result'] as List<dynamic>;

    comments = tcomments
        .map((e) => Tuple5<int, DateTime, String, String, int>(
            e['Id'],
            DateTime.parse(e['TimeStamp']),
            e['UserAppId'],
            e['Body'],
            e['Parent']))
        .toList();

    if (comments.length > 0) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var pureComments = comments.where((x) => x.item5 == null).toList();

    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _controller,
              padding: EdgeInsets.only(top: 16.0),
              reverse: true,
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return CommentUnit(
                  id: pureComments[index].item1,
                  author: pureComments[index].item3,
                  body: pureComments[index].item4,
                  dateTime: pureComments[index].item2,
                  reply: reply,
                  replies: comments
                      .where((x) =>
                          x.item5 != null &&
                          x.item5 == pureComments[index].item1)
                      .toList()
                      .reversed
                      .toList(),
                );
              },
              separatorBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    // top: 16.0,
                  ),
                  width: double.infinity,
                  height: 1.0,
                  color: Settings.themeWhat
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                );
              },
              itemCount: pureComments.length,
            ),
          ),
          Container(
            margin: EdgeInsets.all(8.0),
            height: 36.0,
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              decoration: new BoxDecoration(
                  color: Settings.themeWhat
                      ? Colors.grey.shade800
                      : Color(0xffe2e4e7),
                  borderRadius:
                      new BorderRadius.all(const Radius.circular(6.0))),
              child: Row(
                children: [
                  if (modReply)
                    IconButton(
                      padding: EdgeInsets.only(right: 4.0),
                      constraints: BoxConstraints(),
                      icon: Icon(
                        Mdi.commentTextMultiple,
                        size: 15.0,
                        color: Settings.themeWhat
                            ? Colors.grey.shade600
                            : Color(0xff3a4e66),
                      ),
                      onPressed: () async {
                        replyParent = null;
                        modReply = false;
                        setState(() {});
                      },
                    ),
                  Expanded(
                    child: TextField(
                      focusNode: myFocusNode,
                      style: TextStyle(fontSize: 14.0, color: Colors.grey),
                      decoration: new InputDecoration.collapsed(
                          hintText: '500자까지 입력할 수 있습니다.'),
                      controller: text,
                      // onEditingComplete: () async {},
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        primary: Settings.themeWhat
                            ? Colors.grey.shade600
                            : Color(0xff3a4e66),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 36),
                      ),
                      child: Text(
                        '작성',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () async {
                        if (text.text.length < 5 || text.text.length > 500) {
                          await showOkDialog(context, '너무 짧아요!',
                              Translations.of(context).trans('comment'));
                          return;
                        }
                        if (!modReply) {
                          await VioletCommunityAnonymous.postArtistComment(
                              null, 'global_general', text.text);
                        } else {
                          await VioletCommunityAnonymous.postArtistComment(
                              replyParent, 'global_general', text.text);
                          replyParent = null;
                          modReply = false;
                        }
                        text.text = '';
                        FocusScope.of(context).unfocus();
                        setState(() {});
                        await readComments();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool modReply = false;
  int replyParent;

  Future<void> reply(int id) async {
    replyParent = id;
    modReply = true;
    myFocusNode.requestFocus();
    setState(() {});
  }
}

typedef ReplyCallback = Future Function(int);

class CommentUnit extends StatelessWidget {
  final String author;
  final String body;
  final DateTime dateTime;
  final int id;
  final ReplyCallback reply;
  final bool isReply;
  final List<Tuple5<int, DateTime, String, String, int>> replies;

  static const String dev = 'aee70691afaa';

  const CommentUnit({
    this.id,
    this.author,
    this.body,
    this.dateTime,
    this.reply,
    this.replies,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
            InkWell(
              child: Padding(
                padding: isReply
                    ? const EdgeInsets.only(
                        right: 24.0, top: 12.0, bottom: 12.0, left: 48)
                    : const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          author.substring(0, 7),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Settings.themeWhat
                                ? Colors.grey.shade300
                                : Color(0xff373a3c),
                            fontSize: 15.0,
                          ),
                        ),
                        Container(width: 4.0),
                        if (author.startsWith(dev))
                          Icon(
                            MdiIcons.starCheckOutline,
                            size: 15.0,
                            color: const Color(0xffffd700),
                          ),
                        if (author.startsWith(dev)) Container(width: 4.0),
                        if (author == Settings.userAppId)
                          Icon(
                            MdiIcons.pencilOutline,
                            size: 15.0,
                            color: const Color(0xffffa500),
                          )
                      ],
                    ),
                    RichText(
                      text: new TextSpan(
                        style: TextStyle(
                          color: Settings.themeWhat
                              ? Colors.grey.shade300
                              : Color(0xff373a3c),
                          fontSize: 12.0,
                        ),
                        children: <TextSpan>[
                          new TextSpan(text: body),
                          new TextSpan(text: ' '),
                          new TextSpan(
                            text:
                                '${DateFormat('yyyy.MM.dd HH:mm').format(dateTime)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Settings.themeWhat
                                  ? Colors.grey.shade500
                                  : Color(0xff989dab),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              onDoubleTap: () {
                if (!author.startsWith(dev))
                  _navigate(context, LabUserRecentRecords(author));
              },
              onLongPress: !isReply
                  ? () {
                      reply(id);
                    }
                  : null,
            )
          ] +
          replies
              .map(
                (x) => CommentUnit(
                  id: x.item1,
                  dateTime: x.item2,
                  author: x.item3,
                  body: x.item4,
                  isReply: true,
                  replies: [],
                ),
              )
              .toList(),
    );
  }

  _navigate(context, Widget page) {
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
