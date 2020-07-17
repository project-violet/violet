// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/widgets/article_item/thumbnail_manager.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';

class SimpleInfoWidget extends StatelessWidget {
  final String heroKey;
  final String thumbnail;
  final Map<String, String> headers;
  final FlareControls _flareController = FlareControls();
  bool isBookmarked;
  final QueryResult queryResult;
  final String title;
  final String artist;
  static DateFormat _dateFormat = DateFormat(' yyyy/MM/dd HH:mm');

  SimpleInfoWidget({
    this.heroKey,
    this.thumbnail,
    this.headers,
    this.isBookmarked,
    this.queryResult,
    this.title,
    this.artist,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: <Widget>[
            _thumbnail(context),
            _bookmark(),
          ],
        ),
        Expanded(
          child: SizedBox(
            height: 4 * 50.0,
            width: 3 * 50.0,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: _simpleInfo(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(BuildContext context) {
    return Hero(
      tag: heroKey,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5.0),
          child: GestureDetector(
              onTap: () async {
                Navigator.of(context).push(PageRouteBuilder(
                  opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder: (BuildContext context,
                      Animation<double> animation,
                      Animation<double> secondaryAnimation,
                      Widget wi) {
                    return new FadeTransition(opacity: animation, child: wi);
                  },
                  pageBuilder: (_, __, ___) => ThumbnailViewPage(
                    size: null,
                    thumbnail: thumbnail,
                    headers: headers,
                    heroKey: heroKey,
                  ),
                ));
              },
              child: thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: thumbnail,
                      fit: BoxFit.cover,
                      httpHeaders: headers,
                      height: 4 * 50.0,
                      width: 3 * 50.0,
                    )
                  : SizedBox(
                      height: 4 * 50.0,
                      width: 3 * 50.0,
                      child: FlareActor(
                        "assets/flare/Loading2.flr",
                        alignment: Alignment.center,
                        fit: BoxFit.fitHeight,
                        animation: "Alarm",
                      ),
                    )),
        ),
      ),
    );
  }

  Widget _bookmark() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: GestureDetector(
        child: Transform(
          transform: new Matrix4.identity()..scale(1.0),
          child: SizedBox(
            width: 40,
            height: 40,
            child: FlareActor(
              'assets/flare/likeUtsua.flr',
              animation: isBookmarked ? "Like" : "IdleUnlike",
              controller: _flareController,
              // color: Colors.orange,
              // snapToEnd: true,
            ),
          ),
        ),
        onTap: () async {
          isBookmarked = !isBookmarked;
          if (isBookmarked)
            await (await Bookmark.getInstance()).bookmark(queryResult.id());
          else
            await (await Bookmark.getInstance()).unbookmark(queryResult.id());
          if (!isBookmarked)
            _flareController.play('Unlike');
          else {
            _flareController.play('Like');
          }
        },
      ),
    );
  }

  Widget _simpleInfo() {
    return Stack(children: <Widget>[
      _simpleInfoTextArtist(),
      Padding(
        padding: EdgeInsets.fromLTRB(0, 4 * 50.0 - 50, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _simpleInfoDateTime(),
            _simpleInfoPages(),
          ],
          // children: AnimationConfiguration.toStaggeredList(
          //   duration: const Duration(milliseconds: 900),
          //   childAnimationBuilder: (widget) => SlideAnimation(
          //     horizontalOffset: 50.0,
          //     child: FadeInAnimation(
          //       child: widget,
          //     ),
          //   ),
          //   children: <Widget>[
          //     _simpleInfoDateTime(),
          //     _simpleInfoPages(),
          //   ],
          // ),
        ),
      ),
    ]);
  }

  Widget _simpleInfoTextArtist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(title,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(artist),
      ],
      // children: AnimationConfiguration.toStaggeredList(
      //     duration: const Duration(milliseconds: 900),
      //     childAnimationBuilder: (widget) => SlideAnimation(
      //           horizontalOffset: 50.0,
      //           child: FadeInAnimation(
      //             child: widget,
      //           ),
      //         ),
      //     children: <Widget>[
      //       Text(title,
      //           maxLines: 5,
      //           overflow: TextOverflow.ellipsis,
      //           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      //       Text(artist),
      //     ]),
    );
  }

  Widget _simpleInfoDateTime() {
    return Row(
      children: <Widget>[
        Icon(
          Icons.date_range,
          size: 20,
        ),
        Text(
            queryResult.getDateTime() != null
                ? _dateFormat.format(queryResult.getDateTime())
                : '',
            style: TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _simpleInfoPages() {
    return Row(
      children: <Widget>[
        Icon(
          Icons.photo,
          size: 20,
        ),
        Text(
            ' ' +
                (thumbnail != null
                    ? ThumbnailManager.get(queryResult.id())
                            .item2
                            .length
                            .toString() +
                        ' Page'
                    : ''),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
