// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/artists.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/main/artist_collection/artist_list_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';

class ArtistCollectionPage extends StatefulWidget {
  const ArtistCollectionPage({super.key});

  @override
  State<ArtistCollectionPage> createState() => _ArtistCollectionPageState();
}

class _ArtistCollectionPageState extends State<ArtistCollectionPage> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: Artists.collection.entries
            .where((element) => element.value.length > 0)
            .length,
        itemBuilder: (context, index) {
          final item = Artists.collection.entries
              .where((element) => element.value.length > 0)
              .elementAt(index);
          var name = item.key['default'];

          if (item.key.containsKey(
              Translations.instance!.dbLanguageCode.split('_')[0])) {
            name =
                item.key[Translations.instance!.dbLanguageCode.split('_')[0]];
          }

          final artists =
              (item.value as List<String>).map((e) => e.trim()).join(', ');

          // https://imgur.com/a/dA2j0Za
          const images = [
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
            'https://i.imgur.com/XUcQAQl.png', // 페페
          ];

          return Card(
            elevation: 8.0,
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: CachedNetworkImageProvider(images[index]),
                ),
                title: Text(name, style: const TextStyle(fontSize: 16.0)),
                subtitle: Text(
                  artists,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onTap: () {
                PlatformNavigator.navigateSlide(
                  context,
                  ArtistListPage(
                    artists: (item.value as List<String>)
                        .map((e) => e.trim())
                        .toList(),
                    isLast: index ==
                        Artists.collection.entries
                                .where((element) => element.value.length > 0)
                                .length -
                            1,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
