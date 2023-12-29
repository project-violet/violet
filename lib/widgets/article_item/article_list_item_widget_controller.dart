// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:intl/intl.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';

class ArticleListItemWidgetController extends GetxController {
  final ArticleListItem articleListItem;

  var disposed = false;

  var isBookmarked = false.obs;

  var isLatestRead = false.obs;
  var latestReadPage = 0.obs;

  late String artist;
  late String title;
  late String dateTime;
  RxString thumbnail = ''.obs;
  RxInt imageCount = 0.obs;
  RxMap<String, String> headers = RxMap();

  late double thisWidth;
  RxDouble thisHeight = double.nan.obs;

  var pad = 0.0.obs;
  var scale = 1.0.obs;
  bool onScaling = false;

  FlareControls? flareController;

  GlobalKey bodyKey = GlobalKey();

  ArticleListItemWidgetController(
    this.articleListItem,
  ) {
    if (!Settings.simpleItemWidgetLoadingIcon) {
      flareController = FlareControls();
    }

    setSize();
    checkIsBookmarked();
    checkLastRead();
    initTexts();
    setProvider();
  }

  setSize() {
    if (articleListItem.showDetail) {
      thisWidth = articleListItem.width - 16;
      if (!articleListItem.showUltra) {
        thisHeight.value = 130.0;
      } else {
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          if (bodyKey.currentContext != null && !disposed) {
            thisHeight.value = bodyKey.currentContext!.size!.height;
          }
        });
      }
    } else {
      thisWidth =
          articleListItem.width - (articleListItem.addBottomPadding ? 100 : 0);
      if (articleListItem.addBottomPadding) {
        thisHeight.value = 500.0;
      } else {
        thisHeight.value = articleListItem.width * 4 / 3;
      }
    }
  }

  checkIsBookmarked() {
    Bookmark.getInstance().then((value) async {
      isBookmarked.value =
          await value.isBookmark(articleListItem.queryResult.id());
    });
  }

  checkLastRead() {
    User.getInstance().then((value) => value.getUserLog().then((value) async {
          var x = value.where((e) =>
              e.articleId() == articleListItem.queryResult.id().toString() &&
              e.lastPage() != null &&
              e.lastPage()! > 1 &&
              DateTime.parse(e.datetimeStart())
                      .difference(DateTime.now())
                      .inDays <
                  31);
          if (x.isEmpty) return;
          isLatestRead.value = true;
          latestReadPage.value = x.first.lastPage()!;
        }));
  }

  initTexts() {
    artist = (articleListItem.queryResult.artists() as String)
        .split('|')
        .where((x) => x.isNotEmpty)
        .join(',');

    if (artist == 'N/A') {
      var group = articleListItem.queryResult.groups() != null
          ? articleListItem.queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    title = HtmlUnescape().convert(articleListItem.queryResult.title());
    dateTime = articleListItem.queryResult.getDateTime() != null
        ? DateFormat('yyyy/MM/dd HH:mm')
            .format(articleListItem.queryResult.getDateTime()!.toLocal())
        : '';
  }

  setProvider() async {
    VioletImageProvider? provider;

    if (!ProviderManager.isExists(articleListItem.queryResult.id())) {
      try {
        provider =
            await HentaiManager.getImageProvider(articleListItem.queryResult);
      } catch(e,st){
        if(e == 'Loading'){
          // Logger.warning('loading');
        } else {
          Logger.error('[setProvider] $e\n'
            '$st');
        }
      }
      if(provider != null) ProviderManager.insert(articleListItem.queryResult.id(), provider);
    } else {
      provider = await ProviderManager.get(articleListItem.queryResult.id());
    }
    if(provider != null){
      thumbnail.value = await provider.getThumbnailUrl();
      headers.value = await provider.getHeader(0);
      imageCount.value = provider.length();
    }
  }
}
