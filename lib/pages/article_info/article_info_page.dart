// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:math';

import 'package:auto_animated/auto_animated.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/eh/eh_headers.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/related.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/simple_info.dart';
import 'package:violet/pages/artist_info/article_list_page.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/download/download_page.dart';
import 'package:violet/pages/main/info/lab/search_comment_author.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/variables.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/toast.dart';

class ArticleInfoPage extends StatelessWidget {
  const ArticleInfoPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final data = Provider.of<ArticleInfo>(context);
    final mediaQuery = MediaQuery.of(context);

    Variables.setArticleInfoHeight(
        height - 36 - (mediaQuery.padding + mediaQuery.viewInsets).bottom);

    return Container(
      color: Palette.themeColorLightShallow,
      padding: EdgeInsets.only(top: 0, bottom: Variables.bottomBarHeight),
      child: Card(
        elevation: 5,
        color: Palette.themeColorLightShallow,
        child: SizedBox(
          width: width - 16,
          height: Variables.articleInfoHeight,
          child: Container(
            // width: width,
            // height: height,
            color: Settings.themeWhat
                ? Colors.black.withOpacity(0.9)
                : Colors.white.withOpacity(0.97),
            child: ListView(
              controller: data.controller,
              children: [
                Container(
                  width: width,
                  height: 4 * 50.0 + 16,
                  color: Settings.themeWhat
                      ? Colors.grey.shade900.withOpacity(0.6)
                      : Colors.white.withOpacity(0.2),
                  child: SimpleInfoWidget(),
                ),
                // _functionButtons(width, context, data),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Settings.majorColor.withAlpha(230),
                      ),
                      onPressed: () async =>
                          await _downloadButtonEvent(context, data),
                      child: SizedBox(
                        width: (width - 32 - 64 - 32) / 2,
                        child: Text(
                          Translations.of(context).trans('download'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Settings.majorColor,
                      ),
                      onPressed: data.lockRead
                          ? null
                          : () async => await _readButtonEvent(context, data),
                      child: SizedBox(
                        width: (width - 32 - 64 - 32) / 2,
                        child: Text(
                          Translations.of(context).trans('read'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                TagInfoAreaWidget(queryResult: data.queryResult),
                const DividerWidget(),
                _CommentArea(
                  queryResult: data.queryResult,
                ),
                const DividerWidget(),
                ExpandableNotifier(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ScrollOnExpand(
                      scrollOnExpand: true,
                      scrollOnCollapse: false,
                      child: ExpandablePanel(
                        theme: ExpandableThemeData(
                            iconColor:
                                Settings.themeWhat ? Colors.white : Colors.grey,
                            animationDuration:
                                const Duration(milliseconds: 500)),
                        header: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                          child:
                              Text(Translations.of(context).trans('preview')),
                        ),
                        expanded:
                            PreviewAreaWidget(queryResult: data.queryResult),
                        collapsed: Container(),
                      ),
                    ),
                  ),
                ),
                if (Related.existsRelated(data.queryResult.id()))
                  const DividerWidget(),
                if (Related.existsRelated(data.queryResult.id()))
                  ExpandableNotifier(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ScrollOnExpand(
                        scrollOnExpand: true,
                        scrollOnCollapse: false,
                        child: ExpandablePanel(
                          theme: ExpandableThemeData(
                              iconColor: Settings.themeWhat
                                  ? Colors.white
                                  : Colors.grey,
                              animationDuration:
                                  const Duration(milliseconds: 500)),
                          header: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
                            child: Text(
                                '${Translations.of(context).trans('related')} ${Translations.of(context).trans('articles')}'),
                          ),
                          expanded: _RelatedArea(
                              relatedIds:
                                  Related.getRelated(data.queryResult.id())),
                          collapsed: Container(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*_functionButtons(width, context, data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        ElevatedButton(
          child: Container(
            width: (width - 32 - 64 - 32) / 2,
            child: Text(
              Translations.of(context).trans('download'),
              textAlign: TextAlign.center,
            ),
          ),
          style: ElevatedButton.styleFrom(
            primary: Settings.majorColor.withAlpha(230),
          ),
          onPressed: () async => await _downloadButtonEvent(context, data),
        ),
        const SizedBox(width: 4.0),
        ElevatedButton(
          child: Container(
            width: (width - 32 - 64 - 32) / 2,
            child: Text(
              Translations.of(context).trans('read'),
              textAlign: TextAlign.center,
            ),
          ),
          style: ElevatedButton.styleFrom(
            primary: Settings.majorColor,
          ),
          onPressed: data.lockRead
              ? null
              : () async => await _readButtonEvent(context, data),
        ),
      ],
    );
  }*/

  _downloadButtonEvent(context, data) async {
    if(Platform.isAndroid || Platform.isIOS){
      if (!Settings.useInnerStorage &&
          !await Permission.manageExternalStorage.isGranted) {
        if (await Permission.manageExternalStorage.request() ==
            PermissionStatus.denied) {
          await showOkDialog(context,
              'If you do not allow file permissions, you cannot continue :(');
          return;
        }
      }
    }
    if (!DownloadPageManager.downloadPageLoaded) {
      FToast ftoast = FToast();
      ftoast.init(context);
      ftoast.showToast(
        child: const ToastWrapper(
          isCheck: false,
          isWarning: true,
          msg: 'You need to open the download tab!',
        ),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
      );
      return;
    }

    if ((await Download.getInstance())
        .isDownloadedArticle(data.queryResult.id())) {
      if (await showYesNoDialog(context, '이미 다운로드된 작품입니다. 그래도 다운로드할까요?') !=
          true) {
        return;
      }
    }

    FToast ftoast = FToast();
    ftoast.init(context);
    ftoast.showToast(
      child: ToastWrapper(
        isCheck: true,
        isWarning: false,
        icon: Icons.download,
        msg: data.queryResult.id().toString() +
            Translations.of(context).trans('addtodownloadqueue'),
      ),
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 4),
    );

    await ScriptManager.refresh();

    DownloadPageManager.taskFromQueryResultController!.add(data.queryResult);
    Navigator.pop(context);
  }

  _readButtonEvent(context, data) async {
    if (Settings.useVioletServer) {
      Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        await VioletServer.view(data.queryResult.id());
      });
    }
    await (await User.getInstance()).insertUserLog(data.queryResult.id(), 0);

    await ScriptManager.refresh();

    if (!ProviderManager.isExists(data.queryResult.id())) {
      return;
    }

    var prov = await ProviderManager.get(data.queryResult.id());

    await prov.init();

    dynamic navigatorFunc = Navigator.push;

    if (Settings.usingPushReplacementOnArticleRead) {
      navigatorFunc = Navigator.pushReplacement;
    }

    navigatorFunc(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Provider<ViewerPageProvider>.value(
              value: ViewerPageProvider(
                // uris: ThumbnailManager.get(queryResult.id())
                //     .item1,
                // useWeb: true,
                uris: List<String>.filled(prov.length(), ''),
                useProvider: true,
                provider: prov,
                headers: data.headers,
                id: data.queryResult.id(),
                title: data.queryResult.title(),
                usableTabList: data.usableTabList,
              ),
              child: const ViewerPage());
        },
      ),
    ).then((value) async {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    });
  }
}

class DividerWidget extends StatelessWidget {
  const DividerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 8.0,
      ),
      width: double.infinity,
      height: 1.0,
      color: Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
    );
  }
}

class TagInfoAreaWidget extends StatelessWidget {
  final QueryResult queryResult;

  const TagInfoAreaWidget({super.key, required this.queryResult});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        MultiChipWidget(
            queryResult.tags(),
            Translations.of(context).trans('tags'),
            queryResult.tags() != null
                ? (queryResult.tags() as String)
                    .split('|')
                    .where((element) => element != '')
                    .map((e) => Tuple2<String, String>(
                        e.contains(':') ? e.split(':')[0] : 'tags',
                        e.contains(':') ? e.split(':')[1] : e))
                    .toList()
                : []),
        SingleChipWidget(
            queryResult.language(),
            Translations.of(context).trans('language').split(' ')[0].trim(),
            'language'),
        MultiChipWidget(
            queryResult.artists(),
            Translations.of(context).trans('artists'),
            queryResult.artists() != null
                ? (queryResult.artists() as String)
                    .split('|')
                    .where((element) => element != '')
                    .map((e) => Tuple2<String, String>('artists', e))
                    .toList()
                : []),
        MultiChipWidget(
            queryResult.groups(),
            Translations.of(context).trans('groups'),
            queryResult.groups() != null
                ? (queryResult.groups() as String)
                    .split('|')
                    .where((element) => element != '')
                    .map((e) => Tuple2<String, String>('groups', e))
                    .toList()
                : []),
        MultiChipWidget(
            queryResult.series(),
            Translations.of(context).trans('series'),
            queryResult.series() != null
                ? (queryResult.series() as String)
                    .split('|')
                    .where((element) => element != '')
                    .map((e) => Tuple2<String, String>('series', e))
                    .toList()
                : []),
        MultiChipWidget(
            queryResult.characters(),
            Translations.of(context).trans('character'),
            queryResult.characters() != null
                ? (queryResult.characters() as String)
                    .split('|')
                    .where((element) => element != '')
                    .map((e) => Tuple2<String, String>('character', e))
                    .toList()
                : []),
        SingleChipWidget(
            queryResult.type(), Translations.of(context).trans('type'), 'type'),
        SingleChipWidget(queryResult.uploader(),
            Translations.of(context).trans('uploader'), 'uploader'),
        SingleChipWidget(queryResult.id().toString(),
            Translations.of(context).trans('id'), 'id'),
        SingleChipWidget(queryResult.classname(),
            Translations.of(context).trans('class'), 'class'),
        Container(height: 10),
      ],
    );
  }

  Widget multipleChip(dynamic target, String name, List<Widget> wrap) {
    if (target == null) return Container();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Text(
            '    $name: ',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

class SingleChipWidget extends StatelessWidget {
  final String? target;
  final String name;
  final String raw;

  const SingleChipWidget(this.target, this.name, this.raw, {super.key});

  @override
  Widget build(BuildContext context) {
    if (target == null) return Container();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Text(
          '    $name: ',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      Wrap(
        children: <Widget>[_Chip(group: raw.toLowerCase(), name: target!)],
      ),
    ]);
  }
}

class MultiChipWidget extends StatelessWidget {
  final List<Tuple2<String, String>> groupName;
  final String name;
  final String? target;

  const MultiChipWidget(this.target, this.name, this.groupName, {super.key});

  @override
  Widget build(BuildContext context) {
    if (target == null) return Container();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Text(
            '    $name: ',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 3.0,
            runSpacing: ((){
              if(Platform.isLinux || Settings.useTabletMode || 
          MediaQuery.of(context).orientation == Orientation.landscape
              ) return 9.0;
              if(Platform.isAndroid || Platform.isIOS) return -9.0;
              return -9.0;
            })(),
            children: groupName
                .map((x) => _Chip(group: x.item1, name: x.item2))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class PreviewAreaWidget extends StatelessWidget {
  final QueryResult queryResult;

  const PreviewAreaWidget({super.key, required this.queryResult});

  @override
  Widget build(BuildContext context) {
    if (ProviderManager.isExists(queryResult.id())) {
      return FutureBuilder(
        future: Future.value(1).then((value) async {
          VioletImageProvider prov =
              await ProviderManager.get(queryResult.id());

          return Tuple2(
              await prov.getSmallImagesUrl(), await prov.getHeader(0));
        }),
        builder: (context,
            AsyncSnapshot<Tuple2<List<String>, Map<String, String>>> snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }
          return GridView.count(
            controller: null,
            physics: const ScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: ((){
              // @default return 3;
              if(Platform.isLinux || Settings.useTabletMode || 
          MediaQuery.of(context).orientation == Orientation.landscape
              ){
                return int.parse('${(int.parse(('${(MediaQuery.of(context).size.width)}'.split('.')[0])) / 200)}'.split('.')[0]);
              } else {
                return 3;
              }
            })(),
            childAspectRatio: 3 / 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: (snapshot.data!.item1)
                .take(30)
                .map((e) => CachedNetworkImage(
                      imageUrl: e,
                      httpHeaders: snapshot.data!.item2,
                    ))
                .toList(),
          );
        },
      );
    }
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Align(
            child: Text(
              '??? Unknown Error!',
              textAlign: TextAlign.center,
            ),
          ),
        )
      ],
    );
  }
}

const String urlPattern = r'http';
const String emailPattern = r'\S+@\S+';
const String phonePattern = r'[\d-]{9,}';
final RegExp linkRegExp = RegExp(
    '($urlPattern)|($emailPattern)|($phonePattern)',
    caseSensitive: false);

class _CommentArea extends StatefulWidget {
  final QueryResult queryResult;

  const _CommentArea({required this.queryResult});

  @override
  __CommentAreaState createState() => __CommentAreaState();
}

class __CommentAreaState extends State<_CommentArea> {
  List<Tuple3<DateTime, String, String>> comments = [];

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      if (widget.queryResult.ehash() != null) {
        final prefs = await MultiPreferences.getInstance();
        var cookie = await prefs.getString('eh_cookies');
        if (cookie != null) {
          try {
            final html = await EHSession.requestString(
                'https://exhentai.org/g/${widget.queryResult.id()}/${widget.queryResult.ehash()}/?p=0&inline_set=ts_l');
            final article = EHParser.parseArticleData(html);
            setState(() {
              comments.addAll(article.comment ?? []);
              comments.sort((x, y) => x.item1.compareTo(y.item1));
            });
            return;
          } catch (_) {}
        }
        try {
          final html = (await http.get(
                  'https://e-hentai.org/g/${widget.queryResult.id()}/${widget.queryResult.ehash()}/?p=0&inline_set=ts_l'))
              .body;
          if (html
              .contains('This gallery has been removed or is unavailable.')) {
            return;
          }
          final article = EHParser.parseArticleData(html);
          setState(() {
            comments.addAll(article.comment ?? []);
            comments.sort((x, y) => x.item1.compareTo(y.item1));
          });
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _InfoAreaWidget(
      queryResult: widget.queryResult,
      comments: comments,
    );
  }
}

class _InfoAreaWidget extends StatefulWidget {
  final QueryResult queryResult;
  final List<Tuple3<DateTime, String, String>> comments;

  const _InfoAreaWidget({
    required this.queryResult,
    required this.comments,
  });

  @override
  __InfoAreaWidgetState createState() => __InfoAreaWidgetState();
}

class __InfoAreaWidgetState extends State<_InfoAreaWidget> {
  @override
  Widget build(BuildContext context) {
    return ExpandableNotifier(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ScrollOnExpand(
          child: ExpandablePanel(
            theme: ExpandableThemeData(
                iconColor: Settings.themeWhat ? Colors.white : Colors.grey,
                animationDuration: const Duration(milliseconds: 500)),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
              child: Text(
                  '${Translations.of(context).trans('comment')} (${widget.comments.length})'),
            ),
            expanded: commentArea(context),
            collapsed: Container(),
          ),
        ),
      ),
    );
  }

  Widget commentArea(BuildContext context) {
    if (widget.comments.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Align(
                  child: Text(
                    'No Comments',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            ],
          ),
          comment(context),
        ],
      );
    } else {
      var children = List<Widget>.from(widget.comments.map((e) {
        return InkWell(
          onTap: () async {
            // showOkDialog(context, e.item3, 'Comments');
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
          onLongPress: () async {
            PlatformNavigator.navigateSlide(
                context, LabSearchCommentsAuthor(e.item2));
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
                          DateFormat('yyyy-MM-dd HH:mm')
                              .format(e.item1.toLocal()),
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ]),
            subtitle: buildTextWithLinks(e.item3),
          ),
        );
      }));

      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
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
            children: children + [comment(context)]),
        // ),
      );
    }
  }

  Widget comment(context) {
    return InkWell(
      onTap: () async {
        // check loginable

        if (widget.queryResult.ehash() == null) {
          await showOkDialog(context, 'Cannot write comment!');
          return;
        }

        final prefs = await MultiPreferences.getInstance();
        var cookie = await prefs.getString('eh_cookies');
        if (cookie == null || !cookie.contains('ipb_pass_hash')) {
          await showOkDialog(context, 'Please, Login First!');
          return;
        }

        TextEditingController text = TextEditingController();
        Widget okButton = TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          child: Text(Translations.of(context).trans('ok')),
          onPressed: () async {
            if ((await EHSession.postComment(
                        'https://exhentai.org/g/${widget.queryResult.id()}/${widget.queryResult.ehash()}',
                        text.text))
                    .trim() !=
                '') {
              await showOkDialog(
                  context, 'Too short, or Not a valid session! Try Again!');
              return;
            }
            Navigator.pop(context, true);
          },
        );
        Widget cancelButton = TextButton(
          style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
          child: Text(Translations.of(context).trans('cancel')),
          onPressed: () {
            Navigator.pop(context, false);
          },
        );
        await showDialog(
          useRootNavigator: false,
          context: context,
          builder: (BuildContext context) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            title: const Text('Write Comment'),
            content: TextField(
              controller: text,
              autofocus: true,
            ),
            actions: [okButton, cancelButton],
          ),
        );
      },
      splashColor: Colors.white,
      child: const ListTile(
        // dense: true,
        // contentPadding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Text('Write Comment')],
        ),
      ),
    );
  }

  TextSpan buildLinkComponent(String text, String linkToOpen) => TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            openUrl(linkToOpen);
          },
      );

  Future<void> openUrl(String url) async {
    final ehPattern =
        RegExp(r'^(https?://)?e(-|x)hentai.org/g/(?<id>\d+)/(?<hash>\w+)/?$');
    if (ehPattern.stringMatch(url) == url) {
      var match = ehPattern.allMatches(url);
      var id = match.first.namedGroup('id')!.trim();
      _showArticleInfo(int.parse(id));
    } else if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  void _showArticleInfo(int id) async {
    final height = MediaQuery.of(context).size.height;

    final search = await HentaiManager.idSearch(id.toString());
    if (search.results.length != 1) return;

    final qr = search.results.first;

    HentaiManager.getImageProvider(qr).then((value) async {
      var thumbnail = await value.getThumbnailUrl();
      var headers = await value.getHeader(0);
      ProviderManager.insert(qr.id(), value);

      var isBookmarked =
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

  List<InlineSpan> linkify(String text) {
    final List<InlineSpan> list = <InlineSpan>[];
    final RegExpMatch? match =
        RegExp(r'(https?://.*?)([\<"\n\r ]|$)').firstMatch(text);
    if (match == null) {
      list.add(TextSpan(text: text));
      return list;
    }

    if (match.start > 0) {
      list.add(TextSpan(text: text.substring(0, match.start)));
    }

    final String linkText = match.group(1)!;
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
    if (ProviderManager.isExists(widget.queryResult.id())) {
      return FutureBuilder(
        future: ProviderManager.get(widget.queryResult.id())
            .then((value) => value.getSmallImagesUrl()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }
          return GridView.count(
            controller: null,
            physics: const ScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 3 / 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: (snapshot.data as List<String>)
                .map((e) => CachedNetworkImage(
                      imageUrl: e,
                    ))
                .toList(),
          );
        },
      );
    }
    return const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Align(
              child: Text(
                '??? Unknown Error!',
                textAlign: TextAlign.center,
              ),
            ),
          )
        ]);
  }
}

// Create tag-chip
// group, name
class _Chip extends StatelessWidget {
  final String name;
  final String group;

  const _Chip({required this.name, required this.group});

  String normalize(String tag) {
    if (tag == 'groups') return 'group';
    if (tag == 'artists') return 'artist';
    if (tag == 'tags') return 'tag';
    return tag;
  }

  @override
  Widget build(BuildContext context) {
    var tagDisplayed = name;
    Color color = Colors.grey;

    if (Settings.translateTags) {
      tagDisplayed =
          TagTranslate.ofAny(tagDisplayed).split(':').last.split('|').first;
    }

    if (group == 'female') {
      color = Colors.pink.shade400;
    } else if (group == 'male') {
      color = Colors.blue;
    } else if (group == 'prefix') {
      color = Colors.orange;
    } else if (group == 'id') {
      color = Colors.orange;
    }

    var mustHasMorePad = true;
    Widget avatar = Text(group[0].toUpperCase(),
        style: const TextStyle(color: Colors.white));

    if (group == 'female') {
      mustHasMorePad = false;
      avatar = const Icon(
        MdiIcons.genderFemale,
        size: 18.0,
        color: Colors.white,
      );
    } else if (group == 'male') {
      mustHasMorePad = false;
      avatar = const Icon(
        MdiIcons.genderMale,
        size: 18.0,
        color: Colors.white,
      );
    } else if (group == 'language') {
      mustHasMorePad = false;
      avatar = const Icon(
        Icons.language,
        size: 18.0,
        color: Colors.white,
      );
    } else if (group == 'artists') {
      mustHasMorePad = false;
      avatar = const Icon(
        MdiIcons.account,
        size: 18.0,
        color: Colors.white,
      );
    } else if (group == 'groups') {
      mustHasMorePad = false;
      avatar = const Icon(
        MdiIcons.accountGroup,
        size: 15.0,
        color: Colors.white,
      );
    }

    final fc = GestureDetector(
      child: RawChip(
        labelPadding: const EdgeInsets.all(0.0),
        label: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(
                  left: 2.0 + (mustHasMorePad ? 4.0 : 0),
                  right: (mustHasMorePad ? 4.0 : 0)),
              child: avatar,
            ),
            Text(
              ' $tagDisplayed ',
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
        // avatar: CircleAvatar(
        //   backgroundColor: avatarBg,
        //   child: avatar,
        // ),
        // label: Text(
        //   ' $tagDisplayed',
        //   style: const TextStyle(
        //     color: Colors.white,
        //   ),
        // ),
        backgroundColor: color,
        elevation: 6.0,
        // shadowColor: Colors.grey[60],
        padding: const EdgeInsets.all(6.0),
      ),
      onLongPress: () async {
        if (!Settings.excludeTags
            .contains('${normalize(group)}:${name.replaceAll(' ', '_')}')) {
          final yn = await showYesNoDialog(context, '이 태그를 제외태그에 추가할까요?');
          if (yn) {
            Settings.excludeTags
                .add('${normalize(group)}:${name.replaceAll(' ', '_')}');
            await Settings.setExcludeTags(Settings.excludeTags.join(' '));
            await showOkDialog(context, '제외태그에 성공적으로 추가했습니다!');
          }
        } else {
          await showOkDialog(context, '이미 제외태그에 추가된 항목입니다!');
        }
      },
      onTap: () async {
        if ((group == 'groups' ||
                group == 'artists' ||
                group == 'uploader' ||
                group == 'series' ||
                group == 'character') &&
            name.toLowerCase() != 'n/a') {
          PlatformNavigator.navigateSlide(
            context,
            ArtistInfoPage(
              isGroup: group == 'groups',
              isUploader: group == 'uploader',
              isCharacter: group == 'character',
              isSeries: group == 'series',
              artist: name,
            ),
          );
        } else if (group == 'id') {
          Clipboard.setData(ClipboardData(text: name));
          FToast fToast = FToast();
          fToast.init(context);
          fToast.showToast(
            child: ToastWrapper(
              isCheck: true,
              isWarning: false,
              msg: Translations.of(context).trans('copied'),
            ),
            gravity: ToastGravity.BOTTOM,
            toastDuration: const Duration(seconds: 4),
          );
        }
      },
    );

    return SizedBox(
      height: ((){
        if(Platform.isLinux || Settings.useTabletMode || 
          MediaQuery.of(context).orientation == Orientation.landscape
        ) return 44.0;
        if(Platform.isAndroid || Platform.isIOS) return 44.0;
        return 44.0;
      })(),
      child: FittedBox(child: fc),
    );
  }
}

class _RelatedArea extends StatelessWidget {
  final List<int> relatedIds;
  const _RelatedArea({required this.relatedIds});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: QueryManager.queryIds(relatedIds),
      builder: (context, AsyncSnapshot<List<QueryResult>> snapshot) {
        if (!snapshot.hasData) return Container();

        return Column(children: <Widget>[
          articleArea(context, snapshot.data!),
          Visibility(
            visible: relatedIds.length > 6,
            child: more(
              context,
              () => ArticleListPage(
                  cc: snapshot.data!,
                  name:
                      '${Translations.of(context).trans('related')} ${Translations.of(context).trans('articles')}'),
            ),
          ),
        ]);
      },
    );
  }

  Widget more(BuildContext context, Widget Function() what) {
    return SizedBox(
      height: 60,
      child: InkWell(
        onTap: () async {
          PlatformNavigator.navigateSlide(context, what(), opaque: true);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Text(Translations.of(context).trans('more'))],
        ),
      ),
    );
  }

  Widget articleArea(BuildContext context, List<QueryResult> cc) {
    var windowWidth = MediaQuery.of(context).size.width;
    return LiveGrid(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      showItemInterval: const Duration(milliseconds: 50),
      showItemDuration: const Duration(milliseconds: 150),
      visibleFraction: 0.001,
      itemCount: min(cc.length, 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (context, index, animation) {
        return FadeTransition(
          opacity: Tween<double>(
            begin: 0,
            end: 1,
          ).animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.1),
              end: Offset.zero,
            ).animate(animation),
            child: Padding(
              padding: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  child: Provider<ArticleListItem>.value(
                    value: ArticleListItem.fromArticleListItem(
                      queryResult: cc[index],
                      showDetail: false,
                      addBottomPadding: false,
                      width: (windowWidth - 4.0) / 3,
                      thumbnailTag: const Uuid().v4(),
                      usableTabList: cc,
                    ),
                    child: const ArticleListItemWidget(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
