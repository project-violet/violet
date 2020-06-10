// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database.dart';
import 'package:violet/pages/viewer_page.dart';

class ThumbnailManager {
  static HashMap<int, List<String>> _ids = HashMap<int, List<String>>();

  static bool isExists(int id) {
    return _ids.containsKey(id);
  }

  static void insert(int id, List<String> url) {
    _ids[id] = url;
  }

  static List<String> get(int id) {
    return _ids[id];
  }

  static void clear() {
    _ids.clear();
  }
}

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  final QueryResult queryResult;

  ArticleListItemVerySimpleWidget({this.queryResult});

  @override
  _ArticleListItemVerySimpleWidgetState createState() => _ArticleListItemVerySimpleWidgetState();
}

class _ArticleListItemVerySimpleWidgetState extends State<ArticleListItemVerySimpleWidget> {
  String thumbnail;
  double pad = 0.0;

  @override
  Widget build(BuildContext context) {
    var windowWidth = MediaQuery.of(context).size.width;
    if (!ThumbnailManager.isExists(widget.queryResult.id())) {
      HitomiManager.getImageList(widget.queryResult.id().toString())
          .then((images) {
        thumbnail = images[0];
        ThumbnailManager.insert(widget.queryResult.id(), images);
        setState(() {});
      });
    } else
      thumbnail = ThumbnailManager.get(widget.queryResult.id())[0];

    var headers = {
      "Referer": "https://hitomi.la/reader/${widget.queryResult.id()}.html/"
    };

    return GestureDetector(
      child: SizedBox(
        width: windowWidth - 100,
        height: 400,
        child: AnimatedContainer(
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.all(pad),
          child: Container(
            margin: EdgeInsets.only(bottom: 50),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: Offset(0, 3), // changes position of shadow
                ),
              ],
            ),
            child: Container(
              child: thumbnail != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        httpHeaders: headers,
                        placeholder: (b, c) {
                          return FlareActor(
                            "assets/flare/Loading2.flr",
                            alignment: Alignment.center,
                            fit: BoxFit.fitHeight,
                            animation: "Alarm",
                          );
                        },
                      ),
                    )
                  : FlareActor(
                      "assets/flare/Loading2.flr",
                      alignment: Alignment.center,
                      fit: BoxFit.fitHeight,
                      animation: "Alarm",
                    ),
            ),
          ),
        ),
      ),
      onTap: () {},
      onTapDown: (detail) {
        setState(() {
          pad = 10.0;
        });
      },
      onTapUp: (detail) {
        setState(() {
          pad = 0;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) {
              return ViewerPage(images: ThumbnailManager.get(widget.queryResult.id()), headers: headers,);
            },
          ),
        );
      },
      onLongPressEnd: (detail) {
        setState(() {
          pad = 0;
        });
      },
    );
  }
}
