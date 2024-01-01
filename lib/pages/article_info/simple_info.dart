// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';

class SimpleInfoWidget extends StatelessWidget {
  final FlareControls _flareController = FlareControls();
  static final DateFormat _dateFormat = DateFormat(' yyyy/MM/dd HH:mm');

  SimpleInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<ArticleInfo>(context);
    return Row(
      children: [
        Stack(
          children: <Widget>[
            _thumbnail(context, data),
            _bookmark(data),
          ],
        ),
        Expanded(
          child: SizedBox(
            height: 4 * 50.0,
            width: 3 * 50.0,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _simpleInfo(data),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(BuildContext context, ArticleInfo data) {
    return Hero(
      tag: data.heroKey,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3.0),
          child: GestureDetector(
            onTap: () => _thumbnailTapped(context, data),
            child: _thumbnailImage(data),
          ),
        ),
      ),
    );
  }

  void _thumbnailTapped(BuildContext context, ArticleInfo data) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget wi) {
        return FadeTransition(opacity: animation, child: wi);
      },
      pageBuilder: (_, __, ___) => ThumbnailViewPage(
        thumbnail: data.thumbnail,
        headers: data.headers,
        heroKey: data.heroKey,
        showUltra: false,
      ),
    ));
  }

  Widget _thumbnailImage(ArticleInfo data) {
    return data.thumbnail != null
        ? CachedNetworkImage(
            imageUrl: data.thumbnail ?? '',
            fit: BoxFit.cover,
            httpHeaders: data.headers,
            height: 4 * 50.0,
            width: 3 * 50.0,
          )
        : SizedBox(
            height: 4 * 50.0,
            width: 3 * 50.0,
            child: !Settings.simpleItemWidgetLoadingIcon
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
  }

  Widget _bookmark(ArticleInfo data) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        child: Transform(
          transform: Matrix4.identity()..scale(1.0),
          child: SizedBox(
            width: 40,
            height: 40,
            child: FlareActor(
              'assets/flare/likeUtsua.flr',
              animation: data.isBookmarked ? 'Like' : 'IdleUnlike',
              controller: _flareController,
            ),
          ),
        ),
        onTap: () async {
          await data.setIsBookmarked(!data.isBookmarked);
          if (!data.isBookmarked) {
            _flareController.play('Unlike');
          } else {
            _flareController.play('Like');
          }
        },
      ),
    );
  }

  Widget _simpleInfo(ArticleInfo data) {
    return Stack(children: <Widget>[
      _simpleInfoTextArtist(data),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 4 * 50.0 - 50, 0, 0),
        child: Theme(
          data: ThemeData(
              iconTheme: IconThemeData(
                  color: !Settings.themeWhat ? Colors.black : Colors.white)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _simpleInfoDateTime(data),
              _simpleInfoPages(data),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _simpleInfoTextArtist(ArticleInfo data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(data.title,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(data.artist),
      ],
    );
  }

  Widget _simpleInfoDateTime(ArticleInfo data) {
    return Row(
      children: <Widget>[
        const Icon(
          Icons.date_range,
          size: 20,
        ),
        Text(
            data.queryResult.getDateTime() != null
                ? _dateFormat.format(data.queryResult.getDateTime()!.toLocal())
                : '',
            style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _simpleInfoPages(ArticleInfo data) {
    final id = data.queryResult.id();

    return Row(
      children: <Widget>[
        const Icon(
          Icons.photo,
          size: 20,
        ),
        Text(
            ' ${data.thumbnail != null ? '${ProviderManager.isExists(id) ? ProviderManager.getIgnoreDirty(id).length() : '?'} Page' : ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
