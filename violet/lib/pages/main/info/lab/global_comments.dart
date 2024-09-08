// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mdi/mdi.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/recent_user_record.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/settings/settings.dart';

class LabGlobalComments extends StatefulWidget {
  const LabGlobalComments({super.key});

  @override
  State<LabGlobalComments> createState() => _LabGlobalCommentsState();
}

class _LabGlobalCommentsState extends State<LabGlobalComments> {
  List<(int, DateTime, String, String, int?)> comments =
      <(int, DateTime, String, String, int?)>[];
  final ScrollController _controller = ScrollController();
  FocusNode myFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100))
        .then((value) async => await readComments());
  }

  TextEditingController text = TextEditingController();

  Future<void> readComments() async {
    var tcomments = (await VioletCommunityAnonymous.getArtistComments(
        'global_general'))['result'] as List<dynamic>;

    comments = tcomments
        .map((e) => (
              e['Id'] as int,
              DateTime.parse(e['TimeStamp']),
              e['UserAppId'] as String,
              e['Body'] as String,
              e['Parent'] as int?,
            ))
        .toList();

    if (comments.isNotEmpty) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var pureComments = comments.where((x) => x.$5 == null).toList();

    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _controller,
              padding: const EdgeInsets.only(top: 16.0),
              reverse: true,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return CommentUnit(
                  id: pureComments[index].$1,
                  author: pureComments[index].$3,
                  body: pureComments[index].$4,
                  dateTime: pureComments[index].$2,
                  reply: reply,
                  replies: comments
                      .where((x) =>
                          x.$5 != null && x.$5! == pureComments[index].$1)
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
            margin: const EdgeInsets.all(8.0),
            height: 36.0,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                  color: Settings.themeWhat
                      ? Colors.grey.shade800
                      : const Color(0xffe2e4e7),
                  borderRadius: const BorderRadius.all(Radius.circular(6.0))),
              child: Row(
                children: [
                  if (modReply)
                    IconButton(
                      padding: const EdgeInsets.only(right: 4.0),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Mdi.commentTextMultiple,
                        size: 15.0,
                        color: Settings.themeWhat
                            ? Colors.grey.shade600
                            : const Color(0xff3a4e66),
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
                      style:
                          const TextStyle(fontSize: 14.0, color: Colors.grey),
                      decoration: const InputDecoration.collapsed(
                          hintText: '500자까지 입력할 수 있습니다.'),
                      controller: text,
                      // onEditingComplete: () async {},
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Settings.themeWhat
                            ? Colors.grey.shade600
                            : const Color(0xff3a4e66),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 36),
                      ),
                      child: const Text(
                        '작성',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () async {
                        if (text.text.length < 5 || text.text.length > 500) {
                          await showOkDialog(context, '너무 짧아요!',
                              Translations.instance!.trans('comment'));
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

                        if (!context.mounted) return;
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
  int? replyParent;

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
  final ReplyCallback? reply;
  final bool isReply;
  final List<(int, DateTime, String, String, int?)> replies;

  static const String dev = '1918c652d3a9';

  const CommentUnit({
    super.key,
    required this.id,
    required this.author,
    required this.body,
    required this.dateTime,
    this.reply,
    required this.replies,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
            InkWell(
              onDoubleTap: () {
                if (!author.startsWith(dev)) {
                  PlatformNavigator.navigateSlide(
                      context, LabUserRecentRecords(author));
                }
              },
              onLongPress: !isReply
                  ? () {
                      reply!(id);
                    }
                  : null,
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
                                : const Color(0xff373a3c),
                            fontSize: 15.0,
                          ),
                        ),
                        Container(width: 4.0),
                        if (author.startsWith(dev))
                          const Icon(
                            MdiIcons.starCheckOutline,
                            size: 15.0,
                            color: Color(0xffffd700),
                          ),
                        if (author.startsWith(dev)) Container(width: 4.0),
                        if (author == Settings.userAppId)
                          const Icon(
                            MdiIcons.pencilOutline,
                            size: 15.0,
                            color: Color(0xffffa500),
                          )
                      ],
                    ),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Settings.themeWhat
                              ? Colors.grey.shade300
                              : const Color(0xff373a3c),
                          fontSize: 12.0,
                        ),
                        children: <TextSpan>[
                          TextSpan(text: body),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text:
                                DateFormat('yyyy.MM.dd HH:mm').format(dateTime),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Settings.themeWhat
                                  ? Colors.grey.shade500
                                  : const Color(0xff989dab),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ] +
          replies
              .map(
                (x) => CommentUnit(
                  id: x.$1,
                  dateTime: x.$2,
                  author: x.$3,
                  body: x.$4,
                  isReply: true,
                  replies: const [],
                ),
              )
              .toList(),
    );
  }
}
