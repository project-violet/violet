// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/main/info/lab/search_comment_author.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class LabSearchComments extends StatefulWidget {
  @override
  _LabSearchCommentsState createState() => _LabSearchCommentsState();
}

class _LabSearchCommentsState extends State<LabSearchComments> {
  List<Tuple4<int, DateTime, String, String>> comments =
      <Tuple4<int, DateTime, String, String>>[];
  TextEditingController text = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100)).then((value) async {
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
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(0),
              itemBuilder: (BuildContext ctxt, int index) {
                var e = comments[index];
                return InkWell(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    _showArticleInfo(e.item1);
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
                                '${DateFormat('yyyy-MM-dd HH:mm').format(e.item2.toLocal())}',
                                style: TextStyle(fontSize: 12)),
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
          Row(
            children: [
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
        ],
      ),
    );
  }

  _navigate(Widget page) {
    PlatformNavigator.navigateSlide(context, page);
  }

  void _showArticleInfo(int id) async {
    final height = MediaQuery.of(context).size.height;

    final search = await HentaiManager.idSearch(id.toString());
    if (search.item1.length != 1) return;

    final qr = search.item1[0];

    HentaiManager.getImageProvider(qr).then((value) async {
      var thumbnail = await value.getThumbnailUrl();
      var headers = await value.getHeader(0);
      ProviderManager.insert(qr.id(), value);

      var isBookmarked =
          await (await Bookmark.getInstance()).isBookmark(qr.id());

      var cache;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) {
          return DraggableScrollableSheet(
            initialChildSize: 400 / height,
            minChildSize: 400 / height,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) {
              if (cache == null) {
                cache = Provider<ArticleInfo>.value(
                  child: ArticleInfoPage(
                    key: ObjectKey('asdfasdf'),
                  ),
                  value: ArticleInfo.fromArticleInfo(
                    queryResult: qr,
                    thumbnail: thumbnail,
                    headers: headers,
                    heroKey: 'zxcvzxcvzxcv',
                    isBookmarked: isBookmarked,
                    controller: controller,
                  ),
                );
              }
              return cache;
            },
          );
        },
      );
    });
  }
}
