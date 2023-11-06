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
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class LabSearchCommentsAuthor extends StatefulWidget {
  final String author;

  const LabSearchCommentsAuthor(this.author, {super.key});

  @override
  State<LabSearchCommentsAuthor> createState() =>
      _LabSearchCommentsAuthorState();
}

class _LabSearchCommentsAuthorState extends State<LabSearchCommentsAuthor> {
  List<Tuple4<int, DateTime, String, String>> comments =
      <Tuple4<int, DateTime, String, String>>[];

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      var tcomments = (await VioletServer.searchCommentAuthor(widget.author))
          as List<dynamic>;
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
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(0),
        itemBuilder: (BuildContext ctxt, int index) {
          var e = comments[index];
          return InkWell(
            onTap: () async {
              FocusScope.of(context).unfocus();
              _showArticleInfo(e.item1);
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
    );
  }

  // _navigate(Widget page) {
  //   if (!Platform.isIOS) {
  //     Navigator.of(context).push(PageRouteBuilder(
  //       transitionDuration: Duration(milliseconds: 500),
  //       transitionsBuilder: (context, animation, secondaryAnimation, child) {
  //         var begin = Offset(0.0, 1.0);
  //         var end = Offset.zero;
  //         var curve = Curves.ease;

  //         var tween =
  //             Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

  //         return SlideTransition(
  //           position: animation.drive(tween),
  //           child: child,
  //         );
  //       },
  //       pageBuilder: (_, __, ___) => page,
  //     ));
  //   } else {
  //     Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
  //   }
  // }

  void _showArticleInfo(int id) async {
    final height = MediaQuery.of(context).size.height;

    final search = await HentaiManager.idSearch(id.toString());
    if (search.results.length != 1) return;

    final qr = search.results.first;

    HentaiManager.getImageProvider(qr).then((value) async {
      var thumbnail = await value.getThumbnailUrl();
      var headers = await value.getHeader(0);
      ProviderManager.insert(qr.id(), value);

      var isBookmarked =
          await (await Bookmark.getInstance()).isBookmark(qr.id());

      Provider<ArticleInfo>? cache;
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
              cache ??= Provider<ArticleInfo>.value(
                value: ArticleInfo.fromArticleInfo(
                  queryResult: qr,
                  thumbnail: thumbnail,
                  headers: headers,
                  heroKey: 'zxcvzxcvzxcv',
                  isBookmarked: isBookmarked,
                  controller: controller,
                ),
                child: const ArticleInfoPage(
                  key: ObjectKey('asdfasdf'),
                ),
              );
              return cache!;
            },
          );
        },
      );
    });
  }
}
