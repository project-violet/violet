// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/main/info/lab/search_comment_author.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class LabSearchMessage extends StatefulWidget {
  @override
  _LabSearchMessageState createState() => _LabSearchMessageState();
}

class _LabSearchMessageState extends State<LabSearchMessage> {
  List<Tuple6<double, int, int, String, double, List<double>>> messages =
      <Tuple6<double, int, int, String, double, List<double>>>[];
  TextEditingController text = TextEditingController(text: '은근슬쩍');

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      var tmessages = (await VioletServer.searchMessage('contains', text.text))
          as List<dynamic>;
      messages = tmessages
          .map((e) => Tuple6<double, int, int, String, double, List<double>>(
              double.parse(e['MatchScore'] as String),
              e['Id'] as int,
              e['Page'] as int,
              e['Message'] as String,
              e['Correctness'] as double,
              (e['Rect'] as List<dynamic>)
                  .map((e) => double.parse(e.toString()))
                  .toList()))
          .toList();
      setState(() {});
    });
  }

  String selected = 'Contains';

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width - 16;
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(0),
              child: Column(
                children: messages.map(
                  (e) {
                    return FutureBuilder(
                      future: Future.delayed(Duration(milliseconds: 100))
                          .then((value) async {
                        var imgs = await HitomiManager.getImageList(
                            e.item2.toString());
                        return imgs.item1[e.item3];
                      }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return SizedBox(
                            height: 300,
                            child: Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          );
                        }
                        return InkWell(
                          // onTap: () async {},
                          onTap: () async {
                            // FocusScope.of(context).unfocus();
                            // _navigate(LabSearchCommentsAuthor(e.item3));
                            FocusScope.of(context).unfocus();
                            _showArticleInfo(e.item2);
                          },
                          splashColor: Colors.white,
                          // child: ListTile(
                          //   title: Row(
                          //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          //     children: <Widget>[
                          //       Text('(${e.item1}) [${e.item3}]'),
                          //       Expanded(
                          //         child: Align(
                          //           alignment: Alignment.centerRight,
                          //           child: Text(
                          //               '${DateFormat('yyyy-MM-dd HH:mm').format(e.item2.toLocal())}',
                          //               style: TextStyle(fontSize: 12)),
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          //   subtitle: Text(e.item4),
                          // ),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: snapshot.data as String,
                                    httpHeaders: {
                                      "Referer":
                                          'https://hitomi.la/reader/1234.html'
                                    },
                                  ),
                                  FutureBuilder(
                                    future: _calculateImageDimension(
                                        snapshot.data as String),
                                    builder: (context,
                                        AsyncSnapshot<Size> snapshot2) {
                                      if (!snapshot2.hasData)
                                        return Container();

                                      var brtx = e.item6[0];
                                      var brty = e.item6[1];
                                      var brbx = e.item6[2];
                                      var brby = e.item6[3];

                                      var w = snapshot2.data.width;
                                      var h = snapshot2.data.height;

                                      /*
                                  <---------- image --------->

                                  <----- screen ----->
                                  */

                                      // screen width : image width = x : boundary box width
                                      // x = screen width * boundary box width / image width

                                      var ratio = width / w;

                                      return Positioned(
                                        top: brty * ratio - 4,
                                        left: brtx * ratio - 4,
                                        child: SizedBox(
                                          width: (brbx - brtx) * ratio + 8,
                                          height: (brby - brty) * ratio + 8,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                width: 3,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );

                                      /*return Positioned(
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      width: 3,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                top: brty * ratio,
                                left: brtx * ratio,
                                right: (w - brbx) * ratio,
                                bottom: (h - brby) * ratio,
                                width: width,
                                height: h * ratio,
                              );*/
                                    },
                                  ),
                                ],
                              ),
                              ListTile(
                                title: Text("${e.item2} (${e.item3 + 1} Page)"),
                                subtitle: Text("Score: ${e.item1}"),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ).toList(),
              ),
            ),
          ),
          Row(
            children: [
              DropdownButton(
                items: ['Contains', 'Similar']
                    .map((e) => DropdownMenuItem(child: Text(e), value: e))
                    .toList(),
                value: selected,
                onChanged: (value) async {
                  if (value == selected) return;
                  messages = <
                      Tuple6<double, int, int, String, double, List<double>>>[];
                  setState(() {
                    selected = value;
                  });
                  var tmessages = (await VioletServer.searchMessage(
                      selected.toLowerCase(), text.text)) as List<dynamic>;
                  messages = tmessages
                      .map((e) => Tuple6<double, int, int, String, double,
                              List<double>>(
                          double.parse(e['MatchScore'] as String),
                          e['Id'] as int,
                          e['Page'] as int,
                          e['Message'] as String,
                          e['Correctness'] as double,
                          (e['Rect'] as List<dynamic>)
                              .map((e) => double.parse(e.toString()))
                              .toList()))
                      .toList();
                  setState(() {});
                },
              ),
              Expanded(
                child: TextField(
                  controller: text,
                  // autofocus: true,
                  onEditingComplete: () async {
                    messages = <
                        Tuple6<double, int, int, String, double,
                            List<double>>>[];
                    setState(() {});
                    var tmessages = (await VioletServer.searchMessage(
                        selected.toLowerCase(), text.text)) as List<dynamic>;
                    messages = tmessages
                        .map((e) => Tuple6<double, int, int, String, double,
                                List<double>>(
                            double.parse(e['MatchScore'] as String),
                            e['Id'] as int,
                            e['Page'] as int,
                            e['Message'] as String,
                            e['Correctness'] as double,
                            (e['Rect'] as List<dynamic>)
                                .map((e) => double.parse(e.toString()))
                                .toList()))
                        .toList();
                    setState(() {});
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.info_outline),
                color: Colors.grey,
                onPressed: () async {
                  await showOkDialog(
                      context, '대사를 검색해 작품을 찾아보세요!', '대사 검색기 (베타)');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Size> _calculateImageDimension(String url) {
    Completer<Size> completer = Completer();
    Image image = Image(
        image: CachedNetworkImageProvider(url,
            headers: {"Referer": 'https://hitomi.la/reader/1234.html'}));
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
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
              return Provider<ArticleInfo>.value(
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
            },
          );
        },
      );
    });
  }
}
