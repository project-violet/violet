// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

// TODO: expand using optional arguments
Future showArticleInfo(BuildContext context, int id) async {
  final height = MediaQuery.of(context).size.height;

  final search = await HentaiManager.idSearch(id.toString());
  if (search.results.length != 1) return;

  final qr = search.results.first;

  HentaiManager.getImageProvider(qr).then((value) async {
    final thumbnail = await value.getThumbnailUrl();
    final headers = await value.getHeader(0);
    ProviderManager.insert(qr.id(), value);

    final isBookmarked =
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
