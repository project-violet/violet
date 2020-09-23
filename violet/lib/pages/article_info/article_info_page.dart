// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_statusbar_manager/flutter_statusbar_manager.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/article_info/simple_info.dart';
import 'package:violet/pages/download/download_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/widgets/article_item/thumbnail_manager.dart';
import 'package:violet/widgets/toast.dart';

class ArticleInfoPage extends StatelessWidget {
  final Key key;

  ArticleInfoPage({
    this.key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final data = Provider.of<ArticleInfo>(context);
    final mediaQuery = MediaQuery.of(context);

    print((mediaQuery.padding + mediaQuery.viewInsets).top);

    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade200,
      padding: EdgeInsets.only(
          top: 0, bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Card(
            elevation: 5,
            color:
                Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade200,
            // color: Colors.transparent,
            child: SizedBox(
              width: width - 32,
              height: height -
                  36 -
                  (mediaQuery.padding + mediaQuery.viewInsets).bottom,
              child: Stack(
                children: [
                  Container(
                    width: width,
                    height: height,
                    color: Settings.themeWhat
                        ? Colors.black.withOpacity(0.9)
                        : Colors.white.withOpacity(0.97),
                  ),
                  Container(
                    child: SingleChildScrollView(
                      controller: data.controller,
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
                                    : Colors.white.withOpacity(0.2),
                              ),
                              _InfoAreaWithCommentWidget(
                                headers: data.headers,
                                queryResult: data.queryResult,
                              ),
                              SimpleInfoWidget()
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
}

const String urlPattern = r'http';
const String emailPattern = r'\S+@\S+';
const String phonePattern = r'[\d-]{9,}';
final RegExp linkRegExp = RegExp(
    '($urlPattern)|($emailPattern)|($phonePattern)',
    caseSensitive: false);

class _InfoAreaWithCommentWidget extends StatefulWidget {
  final QueryResult queryResult;
  final Map<String, String> headers;

  _InfoAreaWithCommentWidget({this.queryResult, this.headers});

  @override
  __InfoAreaWithCommentWidgetState createState() =>
      __InfoAreaWithCommentWidgetState();
}

class __InfoAreaWithCommentWidgetState
    extends State<_InfoAreaWithCommentWidget> {
  List<Tuple3<DateTime, String, String>> comments =
      List<Tuple3<DateTime, String, String>>();

  @override
  void initState() {
    super.initState();
    if (widget.queryResult.ehash() != null) {
      Future.delayed(Duration(milliseconds: 100)).then((value) async {
        var cookie =
            (await SharedPreferences.getInstance()).getString('eh_cookies');
        if (cookie != null) {
          try {
            var html = await EHSession.requestString(
                'https://exhentai.org/g/${widget.queryResult.id()}/${widget.queryResult.ehash()}/');
            var article = EHParser.parseArticleData(html);
            setState(() {
              comments = article.comment;
            });
            return;
          } catch (e) {}
        }
        var html = (await http.get(
                'https://e-hentai.org/g/${widget.queryResult.id()}/${widget.queryResult.ehash()}/'))
            .body;
        if (html.contains('This gallery has been removed or is unavailable.'))
          return;
        var article = EHParser.parseArticleData(html);
        setState(() {
          comments = article.comment;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InfoAreaWidget(
      queryResult: widget.queryResult,
      headers: widget.headers,
      comments: comments,
    );
  }
}

class _InfoAreaWidget extends StatelessWidget {
  final QueryResult queryResult;
  final Map<String, String> headers;
  final List<Tuple3<DateTime, String, String>> comments;

  _InfoAreaWidget({@required this.queryResult, this.headers, this.comments});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.only(top: 4 * 50.0 + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // children: AnimationConfiguration.toStaggeredList(
        //   duration: const Duration(milliseconds: 370),
        //   childAnimationBuilder: (widget) => SlideAnimation(
        //     horizontalOffset: 50.0,
        //     child: FadeInAnimation(
        //       child: widget,
        //     ),
        //   ),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: RaisedButton(
                    child: Container(
                      width: (width - 32 - 64 - 32) / 2,
                      child: Text(
                        Translations.of(context).trans('download'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    color: Settings.majorColor.withAlpha(230),
                    onPressed: Platform.isAndroid
                        ? () async {
                            if (!await Permission.storage.isGranted) {
                              if (await Permission.storage.request() ==
                                  PermissionStatus.denied) {
                                await Dialogs.okDialog(context,
                                    'If you do not allow file permissions, you cannot continue :(');
                                return;
                              }
                            }
                            if (!DownloadPageManager.downloadPageLoaded) {
                              FlutterToast(context).showToast(
                                child: ToastWrapper(
                                  isCheck: false,
                                  isWarning: true,
                                  msg: 'You need to open the download tab!',
                                ),
                                gravity: ToastGravity.BOTTOM,
                                toastDuration: Duration(seconds: 4),
                              );
                              return;
                            }
                            await DownloadPageManager.appendTask(
                                'https://hitomi.la/galleries/' +
                                    queryResult.id().toString() +
                                    '.html');
                            Navigator.pop(context);
                          }
                        : null,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 0),
                  child: RaisedButton(
                    child: Container(
                      width: (width - 32 - 64 - 32) / 2,
                      child: Text(
                        Translations.of(context).trans('read'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    color: Settings.majorColor,
                    onPressed: () async {
                      if (Settings.useVioletServer) {
                        await VioletServer.view(queryResult.id());
                      }
                      await (await User.getInstance())
                          .insertUserLog(queryResult.id(), 0);
                      SystemChrome.setEnabledSystemUIOverlays([]);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) {
                            return Provider<ViewerPageProvider>.value(
                                value: ViewerPageProvider(
                                  uris: ThumbnailManager.get(queryResult.id())
                                      .item1,
                                  useWeb: true,
                                  headers: headers,
                                  id: queryResult.id(),
                                ),
                                child: ViewerPage());
                          },
                        ),
                      ).then((value) async {
                        await (await User.getInstance())
                            .updateUserLog(queryResult.id(), value as int);
                        SystemChrome.setEnabledSystemUIOverlays(
                            SystemUiOverlay.values);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          multipleChip(
              queryResult.tags(),
              Translations.of(context).trans('tags'),
              queryResult.tags() != null
                  ? (queryResult.tags() as String)
                      .split('|')
                      .where((element) => element != '')
                      .map((e) => _Chip(
                          group: e.contains(':') ? e.split(':')[0] : 'tags',
                          name: e.contains(':') ? e.split(':')[1] : e))
                      .toList()
                  : []),
          singleChip(
              queryResult.language(),
              Translations.of(context).trans('language').split(' ')[0].trim(),
              'language'),
          multipleChip(
              queryResult.artists(),
              Translations.of(context).trans('artists'),
              queryResult.artists() != null
                  ? (queryResult.artists() as String)
                      .split('|')
                      .where((element) => element != '')
                      .map((e) => _Chip(group: 'artists', name: e))
                      .toList()
                  : []),
          multipleChip(
              queryResult.groups(),
              Translations.of(context).trans('groups'),
              queryResult.groups() != null
                  ? (queryResult.groups() as String)
                      .split('|')
                      .where((element) => element != '')
                      .map((e) => _Chip(group: 'groups', name: e))
                      .toList()
                  : []),

          multipleChip(
              queryResult.series(),
              Translations.of(context).trans('series'),
              queryResult.series() != null
                  ? (queryResult.series() as String)
                      .split('|')
                      .where((element) => element != '')
                      .map((e) => _Chip(group: 'series', name: e))
                      .toList()
                  : []),
          multipleChip(
              queryResult.characters(),
              Translations.of(context).trans('character'),
              queryResult.characters() != null
                  ? (queryResult.characters() as String)
                      .split('|')
                      .where((element) => element != '')
                      .map((e) => _Chip(group: 'character', name: e))
                      .toList()
                  : []),
          singleChip(queryResult.type(), Translations.of(context).trans('type'),
              'type'),
          singleChip(queryResult.uploader(),
              Translations.of(context).trans('uploader'), 'uploader'),
          singleChip(queryResult.id().toString(),
              Translations.of(context).trans('id'), 'id'),
          singleChip(queryResult.classname(),
              Translations.of(context).trans('class'), 'class'),
          Container(height: 10),
          _buildDivider(),
          // Comment Area
          ExpandableNotifier(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: ScrollOnExpand(
                child: ExpandablePanel(
                  theme: ExpandableThemeData(
                      iconColor:
                          Settings.themeWhat ? Colors.white : Colors.grey,
                      animationDuration: const Duration(milliseconds: 500)),
                  header: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                    child: Text(
                        '${Translations.of(context).trans('comment')} (${comments.length})'),
                  ),
                  expanded: commentArea(context),
                ),
              ),
            ),
          ),

          _buildDivider(),
          ExpandableNotifier(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: ScrollOnExpand(
                scrollOnExpand: true,
                scrollOnCollapse: false,
                child: ExpandablePanel(
                  theme: ExpandableThemeData(
                      iconColor:
                          Settings.themeWhat ? Colors.white : Colors.grey,
                      animationDuration: const Duration(milliseconds: 500)),
                  header: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                    child: Text(Translations.of(context).trans('preview')),
                  ),
                  expanded: previewArea(),
                ),
              ),
            ),
          ),
        ],
        // ),
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

  Widget commentArea(BuildContext context) {
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
            // children: AnimationConfiguration.toStaggeredList(
            //     duration: const Duration(milliseconds: 900),
            //     childAnimationBuilder: (widget) => SlideAnimation(
            //           horizontalOffset: 50.0,
            //           child: FadeInAnimation(
            //             child: widget,
            //           ),
            //         ),
            children: children),
        // ),
      );
    }
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

  Widget previewArea() {
    if (ThumbnailManager.isExists(queryResult.id())) {
      var thumbnails =
          ThumbnailManager.get(queryResult.id()).item3.take(30).toList();
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

  Widget singleChip(dynamic target, String name, String raw) {
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
        children: <Widget>[_Chip(group: raw.toLowerCase(), name: target)],
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
}

// Create tag-chip
// group, name
class _Chip extends StatelessWidget {
  final String name;
  final String group;

  _Chip({this.name, this.group});

  @override
  Widget build(BuildContext context) {
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
            if ((group == 'groups' ||
                    group == 'artists' ||
                    group == 'uploader' ||
                    group == 'series' ||
                    group == 'character') &&
                name.toLowerCase() != 'n/a') {
              if (!Platform.isIOS) {
                Navigator.of(context).push(PageRouteBuilder(
                  // opaque: false,
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
                    isCharacter: group == 'character',
                    isSeries: group == 'series',
                    artist: name,
                  ),
                ));
              } else {
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => ArtistInfoPage(
                    isGroup: group == 'groups',
                    isUploader: group == 'uploader',
                    isCharacter: group == 'character',
                    isSeries: group == 'series',
                    artist: name,
                  ),
                ));
              }
            }
          },
        ));
    return fc;
  }
}
