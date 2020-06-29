// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:violet/database.dart';
import 'package:violet/settings.dart';
import 'package:violet/widgets/article_list_item_widget.dart';

class ArticleInfoPage extends StatefulWidget {
  final QueryResult queryResult;
  final String thumbnail;
  final String heroKey;
  final Map<String, String> headers;

  ArticleInfoPage(
      {this.queryResult, this.heroKey, this.headers, this.thumbnail});

  @override
  _ArticleInfoPageState createState() => _ArticleInfoPageState();
}

class _ArticleInfoPageState extends State<ArticleInfoPage>
    with SingleTickerProviderStateMixin {
  Animation<double> animation;
  AnimationController controller;
  ScrollController _controller = ScrollController();
  bool firstListen = false;

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(duration: const Duration(seconds: 1), vsync: this);
    animation = Tween<double>(begin: 0, end: 3.0).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => controller.forward());
    _controller.addListener(() {
      firstListen = true;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var unescape = new HtmlUnescape();
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    var artist = (widget.queryResult.artists() as String)
        .split('|')
        .where((x) => x.length != 0).elementAt(0);

    if (artist == 'N/A') {
      var group = widget.queryResult.groups() != null
          ? widget.queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Card(
            elevation: 10,
            // color:
            //     Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
            color: Colors.transparent,
            child: SizedBox(
              width: width - 32,
              height: height - 64,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(1)),
                  boxShadow: [
                    BoxShadow(
                      color: Settings.themeWhat
                          ? Colors.black.withOpacity(0.4)
                          : Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 1,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: _controller,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        children: [
                          Container(
                            width: width,
                            height: 4 * 50.0 + 16,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: animation.value,
                                  sigmaY: animation.value),
                              child: Container(
                                color: Settings.themeWhat
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                          Container(
                            // padding: EdgeInsets.only(top: 4 * 50.0 +16),
                            width: width,
                            // height: height - 16,
                            height: firstListen
                                ? _controller.position.maxScrollExtent +
                                    height -
                                    64
                                : height - 64,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: animation.value,
                                  sigmaY: animation.value),
                              child: Container(
                                color: Settings.themeWhat
                                    ? Colors.black.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Hero(
                                tag: "thumbnail" +
                                    widget.queryResult.id().toString(),
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5.0),
                                    child: GestureDetector(
                                        onTap: () async {
                                          Navigator.of(context)
                                              .push(PageRouteBuilder(
                                            opaque: false,
                                            transitionDuration:
                                                Duration(milliseconds: 500),
                                            transitionsBuilder:
                                                (BuildContext context,
                                                    Animation<double> animation,
                                                    Animation<double>
                                                        secondaryAnimation,
                                                    Widget wi) {
                                              return new FadeTransition(
                                                  opacity: animation,
                                                  child: wi);
                                            },
                                            pageBuilder: (_, __, ___) =>
                                                ThumbnailViewPage(
                                              size: null,
                                              thumbnail: widget.thumbnail,
                                              headers: widget.headers,
                                              heroKey: 'thumbnail' +
                                                  widget.queryResult
                                                      .id()
                                                      .toString(),
                                            ),
                                          ));
                                        },
                                        child: widget.thumbnail != null
                                            ? CachedNetworkImage(
                                                imageUrl: widget.thumbnail,
                                                fit: BoxFit.cover,
                                                httpHeaders: widget.headers,
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
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 4 * 50.0,
                                  width: 3 * 50.0,
                                  child: Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Stack(children: <Widget>[
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: AnimationConfiguration
                                            .toStaggeredList(
                                                duration: const Duration(
                                                    milliseconds: 900),
                                                childAnimationBuilder:
                                                    (widget) => SlideAnimation(
                                                          horizontalOffset:
                                                              50.0,
                                                          child:
                                                              FadeInAnimation(
                                                            child: widget,
                                                          ),
                                                        ),
                                                children: <Widget>[
                                              Text(
                                                  unescape.convert(widget
                                                      .queryResult
                                                      .title()),
                                                  maxLines: 5,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(artist),
                                              // Text(queryResult.type() as String),
                                              // Container(
                                              //   padding: EdgeInsets.all(3),
                                              // ),
                                              // Row(
                                              //   children: <Widget>[
                                              //     Icon(
                                              //       Icons.date_range,
                                              //       size: 20,
                                              //     ),
                                              //     Text(
                                              //         queryResult.getDateTime() !=
                                              //                 null
                                              //             ? DateFormat(
                                              //                     ' yyyy/MM/dd HH:mm')
                                              //                 .format(queryResult
                                              //                     .getDateTime())
                                              //             : '',
                                              //         style: TextStyle(fontSize: 15)),
                                              //   ],
                                              // ),
                                              // Expanded(
                                              //   child: Align(
                                              //     alignment: Alignment.bottomCenter,
                                              //     child: Padding(
                                              //             padding:
                                              //                 EdgeInsets.fromLTRB(
                                              //                     0, 0, 4, 0),
                                              //             child: Text(
                                              //                 queryResult.getDateTime() !=
                                              //                         null
                                              //                     ? DateFormat(
                                              //                             'yyyy/MM/dd HH:mm')
                                              //                         .format(queryResult
                                              //                             .getDateTime())
                                              //                     : '',
                                              //                 style: TextStyle(
                                              //                     fontSize: 13))),
                                              // Row(
                                              //   mainAxisAlignment:
                                              //       MainAxisAlignment
                                              //           .spaceBetween,
                                              //   crossAxisAlignment:
                                              //       CrossAxisAlignment.center,
                                              //   children: [

                                              // ),
                                              // Text('asdf'),
                                              // Text('asdf'),
                                              // Text('asdf')
                                            ]),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                            0, 4 * 50.0 - 50, 0, 0),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: AnimationConfiguration
                                                .toStaggeredList(
                                                    duration: const Duration(
                                                        milliseconds: 900),
                                                    childAnimationBuilder:
                                                        (widget) =>
                                                            SlideAnimation(
                                                              horizontalOffset:
                                                                  50.0,
                                                              child:
                                                                  FadeInAnimation(
                                                                child: widget,
                                                              ),
                                                            ),
                                                    children: <Widget>[
                                                  Row(
                                                    children: <Widget>[
                                                      Icon(
                                                        Icons.date_range,
                                                        size: 20,
                                                      ),
                                                      Text(
                                                          widget.queryResult
                                                                      .getDateTime() !=
                                                                  null
                                                              ? DateFormat(
                                                                      ' yyyy/MM/dd HH:mm')
                                                                  .format(widget
                                                                      .queryResult
                                                                      .getDateTime())
                                                              : '',
                                                          style: TextStyle(
                                                              fontSize: 15)),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: <Widget>[
                                                      Icon(
                                                        Icons.photo,
                                                        size: 20,
                                                      ),
                                                      Text(
                                                          ' ' +
                                                              (widget.thumbnail !=
                                                                      null
                                                                  ? ThumbnailManager.get(widget
                                                                              .queryResult
                                                                              .id())
                                                                          .item2
                                                                          .length
                                                                          .toString() +
                                                                      ' Page'
                                                                  : ''),
                                                          style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500)),
                                                    ],
                                                  ),
                                                ])),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.only(top: 4 * 50.0 + 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: AnimationConfiguration.toStaggeredList(
                                duration: const Duration(milliseconds: 900),
                                childAnimationBuilder: (widget) =>
                                    SlideAnimation(
                                  horizontalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: widget,
                                  ),
                                ),
                                children: <Widget>[
                                  Align(
                                    alignment: Alignment.center,
                                    child: RaisedButton(
                                      child: Container(
                                        width: 150,
                                        child: Text('읽기', textAlign: TextAlign.center,),
                                      ),
                                      color: Settings.majorColor,
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Expanded(
                      //   child: Container(
                      //     color: Settings.themeWhat
                      //         ? Color(0xFF353535)
                      //         : Colors.grey.shade100,
                      //   ),
                      // )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
