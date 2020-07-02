// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:ui';

import 'package:auto_animated/auto_animated.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable/expandable.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/database.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/viewer_page.dart';
import 'package:violet/settings.dart';
import 'package:violet/user.dart';
import 'package:violet/widgets/article_list_item_widget.dart';
import 'package:violet/pages/artist_info_page.dart';

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
  bool isBookmarked = false;
  FlareControls _flareController = FlareControls();
  bool firstListen = false;
  List<Tuple3<DateTime, String, String>> comments =
      List<Tuple3<DateTime, String, String>>();

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(duration: const Duration(seconds: 1), vsync: this);
    animation = Tween<double>(begin: 0, end: 0).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => controller.forward());
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => setState(() {}));
    int i = 0;
    Bookmark.getInstance().then((value) async {
      isBookmarked = await value.isBookmark(widget.queryResult.id());
      if (isBookmarked) setState(() {});
    });
    if (widget.queryResult.ehash() != null) {
      Future.delayed(Duration(milliseconds: 100)).then((value) async {
        var html = await EHSession.requestString(
            'https://exhentai.org/g/${widget.queryResult.id()}/${widget.queryResult.ehash()}/');
        var article = EHParser.parseArticleData(html);
        setState(() {
          comments = article.comment;
        });
      });
    }
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
        .where((x) => x.length != 0)
        .elementAt(0);

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
            elevation: 5,
            color: Colors.transparent,
            child: SizedBox(
              width: width - 32,
              height: height - 64,
              child: Stack(
                children: [
                  Container(
                    width: width,
                    height: height,
                    color: Settings.themeWhat
                        ? Colors.black.withOpacity(0.8)
                        : Colors.white.withOpacity(0.9),
                  ),
                  Container(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Stack(
                            children: [
                              Container(
                                width: width,
                                height: 4 * 50.0 + 16,
                                color: Settings.themeWhat
                                    ? Colors.grey.shade900.withOpacity(0.6)
                                    : Colors.white.withOpacity(0.6),
                              ),
                              Container(
                                padding: EdgeInsets.only(top: 4 * 50.0 + 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      AnimationConfiguration.toStaggeredList(
                                    duration: const Duration(milliseconds: 400),
                                    childAnimationBuilder: (widget) =>
                                        SlideAnimation(
                                      horizontalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: widget,
                                      ),
                                    ),
                                    children: <Widget>[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding:
                                                  EdgeInsets.only(right: 4),
                                              child: RaisedButton(
                                                child: Container(
                                                  width:
                                                      (width - 32 - 64 - 32) /
                                                          2,
                                                  child: Text(
                                                    '다운로드',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                color: Settings.majorColor,
                                                // onPressed: () {},
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding:
                                                  EdgeInsets.only(right: 0),
                                              child: RaisedButton(
                                                child: Container(
                                                  width:
                                                      (width - 32 - 64 - 32) /
                                                          2,
                                                  child: Text(
                                                    '읽기',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                color: Settings.majorColor,
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      fullscreenDialog: true,
                                                      builder: (context) {
                                                        return ViewerPage(
                                                          id: widget.queryResult
                                                              .id()
                                                              .toString(),
                                                          images: ThumbnailManager
                                                                  .get(widget
                                                                      .queryResult
                                                                      .id())
                                                              .item1,
                                                          headers:
                                                              widget.headers,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      singleChip(widget.queryResult.language(),
                                          "Language"),
                                      multipleChip(
                                          widget.queryResult.artists(),
                                          'Aritsts',
                                          widget.queryResult.artists() != null
                                              ? (widget.queryResult.artists()
                                                      as String)
                                                  .split('|')
                                                  .where((element) =>
                                                      element != '')
                                                  .map(
                                                      (e) => chip('artists', e))
                                                  .toList()
                                              : []),
                                      multipleChip(
                                          widget.queryResult.groups(),
                                          'Groups',
                                          widget.queryResult.groups() != null
                                              ? (widget.queryResult.groups()
                                                      as String)
                                                  .split('|')
                                                  .where((element) =>
                                                      element != '')
                                                  .map((e) => chip('groups', e))
                                                  .toList()
                                              : []),
                                      multipleChip(
                                          widget.queryResult.tags(),
                                          'Tags',
                                          widget.queryResult.tags() != null
                                              ? (widget.queryResult.tags()
                                                      as String)
                                                  .split('|')
                                                  .where((element) =>
                                                      element != '')
                                                  .map((e) => chip(
                                                      e.contains(':')
                                                          ? e.split(':')[0]
                                                          : 'tags',
                                                      e.contains(':')
                                                          ? e.split(':')[1]
                                                          : e))
                                                  .toList()
                                              : []),
                                      multipleChip(
                                          widget.queryResult.series(),
                                          'Series',
                                          widget.queryResult.series() != null
                                              ? (widget.queryResult.series()
                                                      as String)
                                                  .split('|')
                                                  .where((element) =>
                                                      element != '')
                                                  .map((e) => chip('series', e))
                                                  .toList()
                                              : []),
                                      multipleChip(
                                          widget.queryResult.characters(),
                                          'Character',
                                          widget.queryResult.characters() !=
                                                  null
                                              ? (widget.queryResult.characters()
                                                      as String)
                                                  .split('|')
                                                  .where((element) =>
                                                      element != '')
                                                  .map((e) =>
                                                      chip('character', e))
                                                  .toList()
                                              : []),
                                      singleChip(
                                          widget.queryResult.type(), "Type"),
                                      singleChip(widget.queryResult.uploader(),
                                          "Uploader"),
                                      singleChip(
                                          widget.queryResult.id().toString(),
                                          "Id"),
                                      singleChip(widget.queryResult.classname(),
                                          "Class"),
                                      Container(height: 10),
                                      _buildDivider(),
                                      // Comment Area
                                      ExpandableNotifier(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: ScrollOnExpand(
                                            child: ExpandablePanel(
                                              theme: ExpandableThemeData(
                                                  iconColor: Settings.themeWhat
                                                      ? Colors.white
                                                      : Colors.grey,
                                                  animationDuration:
                                                      const Duration(
                                                          milliseconds: 500)),
                                              header: Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                    12, 12, 0, 0),
                                                child: Text(
                                                    'Comments (${comments.length})'),
                                              ),
                                              expanded: commentArea(),
                                            ),
                                          ),
                                        ),
                                      ),

                                      _buildDivider(),
                                      ExpandableNotifier(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: ScrollOnExpand(
                                            scrollOnExpand: true,
                                            scrollOnCollapse: false,
                                            child: ExpandablePanel(
                                              theme: ExpandableThemeData(
                                                  iconColor: Settings.themeWhat
                                                      ? Colors.white
                                                      : Colors.grey,
                                                  animationDuration:
                                                      const Duration(
                                                          milliseconds: 500)),
                                              header: Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                    12, 12, 0, 0),
                                                child: Text('Preview'),
                                              ),
                                              expanded: previewArea(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Stack(
                                    children: <Widget>[
                                      Hero(
                                        tag: "thumbnail" +
                                            widget.queryResult.id().toString(),
                                        child: Padding(
                                          padding: EdgeInsets.all(8),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(5.0),
                                            child: GestureDetector(
                                                onTap: () async {
                                                  Navigator.of(context)
                                                      .push(PageRouteBuilder(
                                                    opaque: false,
                                                    transitionDuration:
                                                        Duration(
                                                            milliseconds: 500),
                                                    transitionsBuilder:
                                                        (BuildContext context,
                                                            Animation<double>
                                                                animation,
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
                                                      thumbnail:
                                                          widget.thumbnail,
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
                                                        imageUrl:
                                                            widget.thumbnail,
                                                        fit: BoxFit.cover,
                                                        httpHeaders:
                                                            widget.headers,
                                                        height: 4 * 50.0,
                                                        width: 3 * 50.0,
                                                      )
                                                    : SizedBox(
                                                        height: 4 * 50.0,
                                                        width: 3 * 50.0,
                                                        child: FlareActor(
                                                          "assets/flare/Loading2.flr",
                                                          alignment:
                                                              Alignment.center,
                                                          fit: BoxFit.fitHeight,
                                                          animation: "Alarm",
                                                        ),
                                                      )),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(8),
                                        child: GestureDetector(
                                          child: Transform(
                                            transform: new Matrix4.identity()
                                              ..scale(1.0),
                                            child: SizedBox(
                                              width: 40,
                                              height: 40,
                                              child: FlareActor(
                                                'assets/flare/likeUtsua.flr',
                                                animation: isBookmarked
                                                    ? "Like"
                                                    : "IdleUnlike",
                                                controller: _flareController,
                                                // color: Colors.orange,
                                                // snapToEnd: true,
                                              ),
                                            ),
                                          ),
                                          onTap: () async {
                                            isBookmarked = !isBookmarked;
                                            if (isBookmarked)
                                              await (await Bookmark
                                                      .getInstance())
                                                  .bookmark(
                                                      widget.queryResult.id());
                                            else
                                              await (await Bookmark
                                                      .getInstance())
                                                  .unbookmark(
                                                      widget.queryResult.id());
                                            if (!isBookmarked)
                                              _flareController.play('Unlike');
                                            else {
                                              _flareController.play('Like');
                                            }
                                          },
                                        ),
                                      ),
                                    ],
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
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    900),
                                                        childAnimationBuilder:
                                                            (widget) =>
                                                                SlideAnimation(
                                                                  horizontalOffset:
                                                                      50.0,
                                                                  child:
                                                                      FadeInAnimation(
                                                                    child:
                                                                        widget,
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
                                                                  fontSize:
                                                                      15)),
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
                                                                      ? ThumbnailManager.get(widget.queryResult.id())
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Container _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 8.0,
      ),
      width: double.infinity,
      height: 1.0,
      color: Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
    );
  }

  Widget commentArea() {
    if (comments.length == 0) {
      return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              // alignment: Alignment.center,
              child: Align(
                // alignment: Alignment.center,
                child: Text(
                  'No Comments',
                  textAlign: TextAlign.center,
                ),
              ),
              width: 100,
              height: 100,
            )
          ]);
    } else {
      var children = comments.map((e) {
        return InkWell(
          onTap: () async {
            // Dialogs.okDialog(context, e.item3, 'Comments');
            AlertDialog alert = AlertDialog(
              content: SelectableText(e.item3),
              // actions: [
              //   okButton,
              // ],
            );
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return alert;
              },
            );
          },
          splashColor: Colors.white,
          child: ListTile(
            // dense: true,
            title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text(e.item2),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                          '${DateFormat('yyyy-MM-dd HH:mm').format(e.item1)}',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ]),
            subtitle: buildTextWithLinks(e.item3),
          ),
        );
      }).toList();

      return Padding(
        padding: EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 900),
              childAnimationBuilder: (widget) => SlideAnimation(
                    horizontalOffset: 50.0,
                    child: FadeInAnimation(
                      child: widget,
                    ),
                  ),
              children: children),
        ),
      );
    }
  }

  Widget previewArea() {
    if (ThumbnailManager.isExists(widget.queryResult.id())) {
      var thumbnails =
          ThumbnailManager.get(widget.queryResult.id()).item3.take(30).toList();
      return GridView.count(
        controller: null,
        physics: ScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 3,
        childAspectRatio: 3 / 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: thumbnails
            .map((e) => CachedNetworkImage(
                  imageUrl: e,
                ))
            .toList(),
      );
    }
    return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            // alignment: Alignment.center,
            child: Align(
              // alignment: Alignment.center,
              child: Text(
                '??? Unknown Error!',
                textAlign: TextAlign.center,
              ),
            ),
            width: 100,
            height: 100,
          )
        ]);
  }

  Widget singleChip(dynamic target, String name) {
    if (target == null) return Container();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Padding(
        padding: EdgeInsets.only(top: 10.0),
        child: Text(
          '    $name: ',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      Wrap(
        children: <Widget>[chip(name.toLowerCase(), target)],
      ),
    ]);
  }

  Widget multipleChip(dynamic target, String name, List<Widget> wrap) {
    if (target == null) return Container();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: 10.0),
          child: Text(
            '    $name: ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 1.0,
            runSpacing: -12.0,
            children: wrap,
          ),
        ),
      ],
    );
  }

  // Create tag-chip
  // group, name
  Widget chip(String group, String name) {
    var tagRaw = name;
    var count = '';
    var color = Colors.grey;

    if (group == 'female')
      color = Colors.pink;
    else if (group == 'male')
      color = Colors.blue;
    else if (group == 'prefix')
      color = Colors.orange;
    else if (group == 'id') color = Colors.orange;

    Widget avatar = Text(group[0].toUpperCase());

    if (group == 'female')
      avatar = Icon(MdiIcons.genderFemale, size: 18.0);
    else if (group == 'male')
      avatar = Icon(MdiIcons.genderMale, size: 18.0);
    else if (group == 'language')
      avatar = Icon(Icons.language, size: 18.0);
    else if (group == 'artists')
      avatar = Icon(MdiIcons.account, size: 18.0);
    else if (group == 'groups')
      avatar = Icon(MdiIcons.accountGroup, size: 15.0);

    var fc = Transform.scale(
        scale: 0.95,
        child: RawChip(
          labelPadding: EdgeInsets.all(0.0),
          avatar: CircleAvatar(
            backgroundColor: Colors.grey.shade600,
            child: avatar,
          ),
          label: Text(
            ' ' + tagRaw + count,
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          elevation: 6.0,
          // shadowColor: Colors.grey[60],
          padding: EdgeInsets.all(6.0),
          onPressed: () async {
            if ((group == 'groups' || group == 'artists' || group == 'uploader') && name.toLowerCase() != 'n/a') {
              Navigator.of(context).push(PageRouteBuilder(
                opaque: false,
                transitionDuration: Duration(milliseconds: 500),
                // transitionsBuilder: (BuildContext context,
                //     Animation<double> animation,
                //     Animation<double> secondaryAnimation,
                //     Widget wi) {
                //   // return wi;
                //   return new FadeTransition(opacity: animation, child: wi);
                // },
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
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
                pageBuilder: (_, __, ___) => ArtistInfoPage(
                  isGroup: group == 'groups',
                  isUploader: group == 'uploader',
                  artist: name,
                ),
              ));
            }
          },
        ));
    return fc;
  }

  TextSpan buildLinkComponent(String text, String linkToOpen) => TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            openUrl(linkToOpen);
          },
      );

  Future<void> openUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  List<InlineSpan> linkify(String text) {
    final List<InlineSpan> list = <InlineSpan>[];
    final RegExpMatch match =
        RegExp(r'(https?://.*?)([\<"\n\r ]|$)').firstMatch(text);
    if (match == null) {
      list.add(TextSpan(text: text));
      return list;
    }

    if (match.start > 0) {
      list.add(TextSpan(text: text.substring(0, match.start)));
    }

    final String linkText = match.group(1);
    if (linkText.contains(RegExp(urlPattern, caseSensitive: false))) {
      list.add(buildLinkComponent(linkText, linkText));
    } else if (linkText.contains(RegExp(emailPattern, caseSensitive: false))) {
      list.add(buildLinkComponent(linkText, 'mailto:$linkText'));
    } else if (linkText.contains(RegExp(phonePattern, caseSensitive: false))) {
      list.add(buildLinkComponent(linkText, 'tel:$linkText'));
    } else {
      throw 'Unexpected match: $linkText';
    }

    list.addAll(linkify(text.substring(match.start + linkText.length)));

    return list;
  }

  Text buildTextWithLinks(String textToLink) =>
      Text.rich(TextSpan(children: linkify(textToLink)));
}

const String urlPattern = r'http';
const String emailPattern = r'\S+@\S+';
const String phonePattern = r'[\d-]{9,}';
final RegExp linkRegExp = RegExp(
    '($urlPattern)|($emailPattern)|($phonePattern)',
    caseSensitive: false);
