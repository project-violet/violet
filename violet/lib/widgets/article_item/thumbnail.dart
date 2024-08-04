// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget_controller.dart';

class ThumbnailWidget extends StatelessWidget {
  late final ArticleListItemWidgetController c;
  final String getxId;

  ThumbnailWidget({
    super.key,
    required this.getxId,
  }) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    final result = Obx(
      () {
        final greyScale = c.isLatestRead.value &&
            c.imageCount.value - c.latestReadPage.value <= 2 &&
            !c.articleListItem.disableFilter &&
            Settings.showArticleProgress;

        return SizedBox(
          width: c.articleListItem.showDetail
              ? c.articleListItem.showUltra
                  ? 120 - c.pad.value
                  : 100 - c.pad.value / 6 * 5
              : null,
          child: c.thumbnail.value != ''
              ? Stack(
                  children: <Widget>[
                    ThumbnailImageWidget(
                      headers: c.headers,
                      thumbnail: c.thumbnail.value,
                      thumbnailTag: c.articleListItem.thumbnailTag,
                      showUltra: c.articleListItem.showDetail,
                      greyScale: greyScale,
                    ),
                    BookmarkIndicatorWidget(
                      getxId: getxId,
                      greyScale: greyScale,
                    ),
                    Obx(
                      () => ReadProgressOverlayWidget(
                        imageCount: c.imageCount.value,
                        latestReadPage: c.latestReadPage.value,
                        isLastestRead: c.isLatestRead.value,
                        greyScale: greyScale,
                      ),
                    ),
                    Obx(
                      () => PagesOverlayWidget(
                        imageCount: c.imageCount.value,
                        showDetail: c.articleListItem.showDetail,
                      ),
                    ),
                  ],
                )
              : !Settings.simpleItemWidgetLoadingIcon
                  ? const FlareActor(
                      'assets/flare/Loading2.flr',
                      alignment: Alignment.center,
                      fit: BoxFit.fitHeight,
                      animation: 'Alarm',
                    )
                  : Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          color: Settings.majorColor.withAlpha(150),
                        ),
                      ),
                    ),
        );
      },
    );

    if (c.articleListItem.showDetail) {
      return ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(3.0)),
        child: Material(child: result),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3.0),
        child: result,
      );
    }
  }
}

class ThumbnailImageWidget extends StatelessWidget {
  final String thumbnailTag;
  final String thumbnail;
  final Map<String, String> headers;
  final bool showUltra;
  final bool greyScale;

  // https://github.com/Baseflow/flutter_cached_network_image/issues/468
  final _rebuildValueNotifier = ValueNotifier('');

  ThumbnailImageWidget({
    super.key,
    required this.thumbnail,
    required this.thumbnailTag,
    required this.headers,
    required this.showUltra,
    required this.greyScale,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: thumbnailTag,
      child: ValueListenableBuilder<String>(
        valueListenable: _rebuildValueNotifier,
        builder: (context, value, child) {
          return CachedNetworkImage(
            key: value.isEmpty ? null : ValueKey(value),
            memCacheWidth: Settings.useLowPerf ? 300 : null,
            imageUrl: thumbnail,
            fit: BoxFit.cover,
            httpHeaders: headers,
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: !showUltra ? BoxFit.cover : BoxFit.contain,
                  colorFilter: greyScale
                      ? ColorFilter.mode(
                          Settings.themeWhat
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          BlendMode.saturation,
                        )
                      : null,
                ),
              ),
              child: Container(),
            ),
            errorWidget: (context, url, error) {
              Future.delayed(const Duration(milliseconds: 300)).then(
                  (value) => _rebuildValueNotifier.value = const Uuid().v1());
              return Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Settings.majorColor.withAlpha(150),
                  ),
                ),
              );
            },
            placeholder: (b, c) {
              if (!Settings.simpleItemWidgetLoadingIcon) {
                return const FlareActor(
                  'assets/flare/Loading2.flr',
                  alignment: Alignment.center,
                  fit: BoxFit.fitHeight,
                  animation: 'Alarm',
                );
              } else {
                return Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Settings.majorColor.withAlpha(150),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class BookmarkIndicatorWidget extends StatelessWidget {
  late final ArticleListItemWidgetController c;
  final bool greyScale;

  BookmarkIndicatorWidget({
    super.key,
    required String getxId,
    required this.greyScale,
  }) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: FractionalOffset.topLeft,
      child: Transform(
        transform: Matrix4.identity()..scale(0.9),
        child: SizedBox(
          width: 35,
          height: 35,
          child: Obx(
            () => !Settings.simpleItemWidgetLoadingIcon
                ? FlareActor(
                    'assets/flare/likeUtsua.flr',
                    animation: c.isBookmarked.value ? 'Like' : 'IdleUnlike',
                    controller: c.flareController,
                  )
                : Icon(
                    c.isBookmarked.value
                        ? MdiIcons.heart
                        : MdiIcons.heartOutline,
                    color: c.isBookmarked.value
                        ? !greyScale
                            ? const Color(0xFFE2264D)
                            : Settings.themeWhat
                                ? const Color(0xFF626262)
                                : const Color(0xFF636363)
                        : !Settings.themeWhat
                            ? Colors.black
                            : Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

class ReadProgressOverlayWidget extends StatelessWidget {
  final bool isLastestRead;
  final int latestReadPage;
  final int imageCount;
  final bool greyScale;

  const ReadProgressOverlayWidget({
    super.key,
    required this.isLastestRead,
    required this.latestReadPage,
    required this.imageCount,
    required this.greyScale,
  });

  @override
  Widget build(BuildContext context) {
    return !isLastestRead || !Settings.showArticleProgress
        ? Container()
        : Align(
            alignment: FractionalOffset.topRight,
            child: Container(
              margin: const EdgeInsets.all(4),
              width: 50,
              height: 5,
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      !greyScale ? Colors.red : const Color(0xFF777777)),
                  value: isLastestRead && imageCount - latestReadPage <= 2
                      ? 1.0
                      : latestReadPage / imageCount,
                  backgroundColor: !greyScale
                      ? Colors.grey.withAlpha(100)
                      : const Color(0xFF777777),
                ),
              ),
            ),
          );
  }
}

class PagesOverlayWidget extends StatelessWidget {
  final bool showDetail;
  final int imageCount;

  const PagesOverlayWidget({
    super.key,
    required this.showDetail,
    required this.imageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !showDetail,
      child: Align(
        alignment: FractionalOffset.bottomRight,
        child: Transform(
          transform: Matrix4.identity()..scale(0.9),
          child: Theme(
            data: ThemeData(
              useMaterial3: false,
              canvasColor: Colors.transparent,
            ),
            child: RawChip(
              labelPadding: const EdgeInsets.all(0.0),
              label: Text(
                '$imageCount Page',
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              elevation: 6.0,
              shadowColor: Colors.grey[60],
              padding: const EdgeInsets.all(6.0),
            ),
          ),
        ),
      ),
    );
  }
}
