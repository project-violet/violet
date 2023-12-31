// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/common/utils.dart';
import 'package:violet/pages/main/info/lab/search_comment_author.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class LabSearchComments extends StatefulWidget {
  const LabSearchComments({super.key});

  @override
  State<LabSearchComments> createState() => _LabSearchCommentsState();
}

class _LabSearchCommentsState extends State<LabSearchComments> {
  List<Tuple4<int, DateTime, String, String>> comments =
      <Tuple4<int, DateTime, String, String>>[];
  TextEditingController text = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      var tcomments =
          (await VioletServer.searchComment(text.text)) as List<dynamic>;
      comments = tcomments
          .map((e) => e as Tuple4<int, DateTime, String, String>)
          .toList();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(0),
              itemBuilder: (BuildContext ctxt, int index) {
                var e = comments[index];
                return InkWell(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    showArticleInfo(context, e.item1);
                  },
                  onLongPress: () async {
                    FocusScope.of(context).unfocus();
                    _navigate(LabSearchCommentsAuthor(e.item3));
                  },
                  splashColor: Colors.white,
                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Text('(${e.item1}) [${e.item3}]'),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                                DateFormat('yyyy-MM-dd HH:mm')
                                    .format(e.item2.toLocal()),
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(e.item4),
                  ),
                );
              },
              itemCount: comments.length,
            ),
          ),
          TextField(
            controller: text,
            // autofocus: true,
            onEditingComplete: () async {
              var tcomments = (await VioletServer.searchComment(text.text))
                  as List<dynamic>;
              comments = tcomments
                  .map((e) => e as Tuple4<int, DateTime, String, String>)
                  .toList();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  _navigate(Widget page) {
    PlatformNavigator.navigateSlide(context, page);
  }
}
