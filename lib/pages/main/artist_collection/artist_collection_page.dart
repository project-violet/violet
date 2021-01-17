// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/artists.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/main/artist_collection/artist_list_page.dart';
import 'package:violet/settings/settings.dart';

class ArtistCollectionPage extends StatefulWidget {
  @override
  _ArtistCollectionPageState createState() => _ArtistCollectionPageState();
}

class _ArtistCollectionPageState extends State<ArtistCollectionPage> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Card(
              elevation: 5,
              color:
                  Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
              child: SizedBox(
                width: width - 16,
                height: height -
                    16 -
                    (mediaQuery.padding + mediaQuery.viewInsets).bottom,
                child: Container(
                  child: ListView.builder(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: Artists.collection.entries
                        .where((element) => element.value.length > 0)
                        .length,
                    itemBuilder: (context, index) {
                      var item = Artists.collection.entries
                          .where((element) => element.value.length > 0)
                          .elementAt(index);
                      var name = item.key['default'];

                      if (item.key.containsKey(Translations.of(context)
                          .dbLanguageCode
                          .split('_')[0])) {
                        name = item.key[Translations.of(context)
                            .dbLanguageCode
                            .split('_')[0]];
                      }

                      var artists = (item.value as List<String>).join(', ');

                      // https://imgur.com/a/dA2j0Za
                      var images = [
                        'https://i.imgur.com/38RAOYs.png', // 쾌락천
                        'https://i.imgur.com/bXmRk4l.png', // 제로스
                        'https://i.imgur.com/wk91Vmh.png', // 순애
                        'https://i.imgur.com/iSmmAjn.png', // 로리
                        'https://i.imgur.com/GIXr2Ob.png', // 오네쇼타
                        'https://i.imgur.com/I7Yugph.png', // 펨돔
                        'https://i.imgur.com/7J0Xhhn.png', // 최면
                        'https://i.imgur.com/5XQdp6p.png', // 네토라레
                        'https://i.imgur.com/FLmTDzJ.png', // 노출증
                        'https://i.imgur.com/RaFulcc.png', // 하렘
                        'https://i.imgur.com/f8akDVD.png', // 유리
                        'https://i.imgur.com/t9wGNBY.png', // 밀프
                        'https://i.imgur.com/WCfm2in.png', // ㅇㅅㅇ
                        'https://i.imgur.com/I3YMltZ.png', // 게이
                        'https://i.imgur.com/wYIS5qC.png', // 야오이
                        'https://i.imgur.com/zcniemz.png', // 후타나리
                        'https://i.imgur.com/YHhu46pg.jpg', // 씨지
                      ];

                      return Card(
                        elevation: 8.0,
                        child: InkWell(
                          customBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 0.0, horizontal: 16.0),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage:
                                  CachedNetworkImageProvider(images[index]),
                            ),
                            title: Text(name, style: TextStyle(fontSize: 16.0)),
                            subtitle: Text(
                              artists,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onTap: () {
                            if (!Platform.isIOS) {
                              Navigator.of(context).push(PageRouteBuilder(
                                opaque: false,
                                transitionDuration: Duration(milliseconds: 500),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  var begin = Offset(0.0, 1.0);
                                  var end = Offset.zero;
                                  var curve = Curves.ease;

                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));

                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                pageBuilder: (_, __, ___) => ArtistListPage(
                                  aritsts: item.value,
                                ),
                              ));
                            } else {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => ArtistListPage(
                                    aritsts: item.value,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
