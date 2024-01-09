// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/context/modal_bottom_sheet_context.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/model/article_info.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/search/search_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/util/call_once.dart';
import 'package:violet/widgets/article_item/article_list_item_widget_controller.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';
import 'package:violet/widgets/toast.dart';

class ArticleListItemWidget extends StatefulWidget {
  final bool isChecked;
  final bool isCheckMode;

  const ArticleListItemWidget({
    super.key,
    this.isChecked = false,
    this.isCheckMode = false,
  });

  @override
  State<ArticleListItemWidget> createState() => _ArticleListItemWidgetState();
}

class _ArticleListItemWidgetState extends State<ArticleListItemWidget>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<ArticleListItemWidget> {
  late CallOnce initProvider;
  late ArticleListItem data;
  late ArticleListItemWidgetController c;
  late String getxId;

  @override
  bool get wantKeepAlive => true;

  bool animating = false;

  RxBool isChecked = false.obs;

  @override
  void initState() {
    super.initState();
    initProvider = CallOnce(initAfterProvider);

    isChecked.value = widget.isChecked;
  }

  initAfterProvider() {
    data = Provider.of<ArticleListItem>(context);
    getxId = const Uuid().v4();
    c = Get.put(
      ArticleListItemWidgetController(data),
      tag: getxId,
    );
  }

  @override
  void dispose() {
    c.disposed = true;
    super.dispose();
    Get.delete<ArticleListItemWidgetController>(tag: getxId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initProvider.call();
  }

  bool firstChecked = false;

  BodyWidget? _body;
  bool _shouldReload = false;

  Widget? _cachedBuildWidget;
  bool _shouldReloadCachedBuildWidget = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (c.disposed) return Container();

    _doBookmarkScaling();

    if (_cachedBuildWidget == null ||
        _shouldReloadCachedBuildWidget ||
        _shouldReload) {
      if (_body == null || _shouldReload) {
        _shouldReload = false;

        // https://stackoverflow.com/a/52249579
        final body = BodyWidget(
          key: c.bodyKey,
          getxId: getxId,
        );

        _body = body;
      }

      _cachedBuildWidget = Obx(
        () => Container(
          color: isChecked.value ? Colors.amber : Colors.transparent,
          child: PimpedButton(
            particle: Rectangle2DemoParticle(),
            pimpedWidgetBuilder: (context, controller) {
              return GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onLongPress: () async {
                  await _onLongPress(controller);
                },
                onLongPressEnd: _onPressEnd,
                onTapCancel: _onTapCancle,
                onDoubleTap: _onDoubleTap,
                child: Obx(
                  () => SizedBox(
                    width: c.thisWidth,
                    height: c.thisHeight.isNaN ? null : c.thisHeight.value,
                    child: AnimatedContainer(
                      curve: Curves.easeInOut,
                      duration: const Duration(milliseconds: 300),
                      transform: c.thisHeight.value.isNaN
                          ? null
                          : (Matrix4.identity()
                            ..translate(c.thisWidth / 2, c.thisHeight / 2)
                            ..scale(c.scale.value)
                            ..translate(-c.thisWidth / 2, -c.thisHeight / 2)),
                      child: FutureBuilder<QueryResult>(
                        /*
                         * This checks QueryResult then 
                         * do idQueryWeb when QueryResult keys was only exists 'Id'
                         */
                        future: (() {
                          if (_body?.c.articleListItem.queryResult.result.keys
                                      .length ==
                                  1 &&
                              _body?.c.articleListItem.queryResult.result.keys
                                      .lastOrNull ==
                                  'Id') {
                            return HentaiManager.idQueryWeb(
                                '${_body?.c.articleListItem.queryResult.id()}');
                          } else {
                            return Future.value(
                                _body?.c.articleListItem.queryResult ??
                                    QueryResult(result: {}));
                          }
                        })(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            if (_body?.c.articleListItem.queryResult.result.keys
                                        .length ==
                                    1 &&
                                _body?.c.articleListItem.queryResult.result.keys
                                        .lastOrNull ==
                                    'Id') {
                              final oldGetxId = _body!.getxId;
                              final newGetxId = const Uuid().v4();
                              final tmpC = ArticleListItemWidgetController(
                                  ArticleListItem(
                                // key: _body!.c.articleListItem.key,
                                queryResult: snapshot.data!,
                                addBottomPadding:
                                    _body!.c.articleListItem.addBottomPadding,
                                showDetail: _body!.c.articleListItem.showDetail,
                                showUltra: _body!.c.articleListItem.showUltra,
                                width: _body!.c.articleListItem.width,
                                thumbnailTag:
                                    _body!.c.articleListItem.thumbnailTag,
                                bookmarkMode:
                                    _body!.c.articleListItem.bookmarkMode,
                                bookmarkCallback:
                                    _body!.c.articleListItem.bookmarkCallback,
                                bookmarkCheckCallback: _body!
                                    .c.articleListItem.bookmarkCheckCallback,
                                viewed: _body!.c.articleListItem.viewed,
                                seconds: _body!.c.articleListItem.seconds,
                                disableFilter:
                                    _body!.c.articleListItem.disableFilter,
                                doubleTapCallback:
                                    _body!.c.articleListItem.doubleTapCallback,
                                usableTabList:
                                    _body!.c.articleListItem.usableTabList,
                                selectMode: _body!.c.articleListItem.selectMode,
                                selectCallback:
                                    _body!.c.articleListItem.selectCallback,
                              ));
                              c.dispose();
                              c = tmpC;

                              Get.delete(tag: oldGetxId);
                              Get.put(c, tag: newGetxId);
                              final body = BodyWidget(
                                key: c.bodyKey,
                                getxId: newGetxId,
                              );
                              _body = body;
                              return body;
                            } else {
                              return _body!;
                            }
                          } else {
                            return _body!;
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return _cachedBuildWidget!;
  }

  _doBookmarkScaling() {
    if (data.bookmarkMode) {
      if (!widget.isCheckMode && !c.onScaling && c.scale.value != 1.0) {
        _animateScale(1.0);
      } else if (widget.isCheckMode &&
          isChecked.value &&
          c.scale.value != 0.95) {
        _animateScale(0.95);
      }
    }
  }

  _animateScale(double scale) {
    c.scale.value = scale;
  }

  _onTapDown(detail) {
    if (c.onScaling) return;
    c.onScaling = true;
    _animateScale(0.95);
  }

  _onTapUp(detail) async {
    if (data.selectMode) {
      data.selectCallback!();
      return;
    }

    c.onScaling = false;

    if (widget.isCheckMode) {
      isChecked.value = !isChecked.value;
      data.bookmarkCheckCallback!(data.queryResult.id(), isChecked.value);
      _animateScale(isChecked.value ? 0.95 : 1.0);
      return;
    }

    if (firstChecked) return;

    _animateScale(1.0);

    if (!Settings.liteMode) {
      _showArticleInfo();
    } else {
      _showArticleInfo();
    }
  }

  Future<void> _showArticleInfo() async {
    final height = MediaQuery.of(context).size.height;

    // https://github.com/flutter/flutter/issues/67219
    FutureBuilder<QueryResult>? cache;
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
            cache ??= FutureBuilder<QueryResult>(
              /*
                * This checks QueryResult then 
                * do idQueryWeb when QueryResult keys was only exists 'Id'
                */
              future: (() {
                if (data.queryResult.result.keys.length == 1 &&
                    data.queryResult.result.keys.lastOrNull == 'Id') {
                  return HentaiManager.idQueryWeb('${data.queryResult.id()}');
                } else {
                  return Future.value(data.queryResult);
                }
              })(),
              builder: (context, snapshot) {
                getBody(queryResult) {
                  return Provider<ArticleInfo>.value(
                    value: ArticleInfo.fromArticleInfo(
                      queryResult: queryResult,
                      thumbnail: c.thumbnail.value,
                      headers: c.headers,
                      heroKey: data.thumbnailTag,
                      isBookmarked: c.isBookmarked.value,
                      controller: controller,
                      usableTabList: data.usableTabList,
                    ),
                    child: const ArticleInfoPage(
                      key: ObjectKey('asdfasdf'),
                    ),
                  );
                }

                if (snapshot.hasData) {
                  return getBody(snapshot.data);
                } else {
                  return getBody(data.queryResult);
                }
              },
            );
            return cache!;
          },
        );
      },
    );
  }

  // ignore: unused_element
  _viewArticle() async {
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

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Provider<ViewerPageProvider>.value(
            value: ViewerPageProvider(
              // useWeb: true,
              uris: List<String>.filled(prov.length(), ''),
              useProvider: true,
              provider: prov,
              headers: c.headers,
              id: data.queryResult.id(),
              title: data.queryResult.title(),
              usableTabList: data.usableTabList,
            ),
            child: const ViewerPage(),
          );
        },
      ),
    ).then((value) async {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    });
  }

  Future<void> _onLongPress(controller) async {
    c.onScaling = false;

    if (data.bookmarkMode) {
      if (widget.isCheckMode) {
        isChecked.value = !isChecked.value;
        _animateScale(1.0);
        return;
      }
      isChecked.value = true;
      firstChecked = true;
      _animateScale(0.95);
      data.bookmarkCallback!(data.queryResult.id());
      return;
    }

    if (c.isBookmarked.value) {
      if (!await showYesNoDialog(context, '북마크를 삭제할까요?', '북마크')) return;
    }

    if (!c.disposed) {
      final fToast = FToast();
      fToast.init(context);
      fToast.showToast(
        child: ToastWrapper(
          icon: c.isBookmarked.value ? Icons.delete_forever : Icons.check,
          color: c.isBookmarked.value
              ? Colors.redAccent.withOpacity(0.8)
              : Colors.greenAccent.withOpacity(0.8),
          msg:
              '${data.queryResult.id()}${locale.Translations.of(context).trans(c.isBookmarked.value ? 'removetobookmark' : 'addtobookmark')}',
        ),
        ignorePointer: true,
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
      );
    }

    if (!c.isBookmarked.value) {
      await (await Bookmark.getInstance()).bookmark(data.queryResult.id());
    } else {
      await (await Bookmark.getInstance()).unbookmark(data.queryResult.id());
    }

    c.isBookmarked.value = !c.isBookmarked.value;

    if (!c.isBookmarked.value) {
      if (!Settings.simpleItemWidgetLoadingIcon) {
        c.flareController!.play('Unlike');
      }
    } else {
      controller.forward(from: 0.0);
      if (!Settings.simpleItemWidgetLoadingIcon) {
        c.flareController!.play('Like');
      }
    }

    await HapticFeedback.lightImpact();

    c.pad.value = 0;
    _animateScale(1.0);
  }

  _onPressEnd(detail) {
    c.onScaling = false;
    if (firstChecked) {
      firstChecked = false;
      return;
    }

    c.pad.value = 0;
    _animateScale(1.0);
  }

  _onTapCancle() {
    c.onScaling = false;

    c.pad.value = 0;
    _animateScale(1.0);
  }

  Future<void> _onDoubleTap() async {
    if (!Settings.liteMode) {
      _showThumbnailView();
    } else {
      _showThumbnailView();
    }
  }

  _showThumbnailView() async {
    c.onScaling = false;

    if (data.doubleTapCallback == null) {
      Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation, Widget wi) {
          return FadeTransition(opacity: animation, child: wi);
        },
        pageBuilder: (_, __, ___) => ThumbnailViewPage(
          thumbnail: c.thumbnail.value,
          headers: c.headers,
          heroKey: data.thumbnailTag,
          showUltra: data.showUltra,
        ),
      ));
    } else {
      data.doubleTapCallback!();
    }

    _shouldReloadCachedBuildWidget = true;
    Future.delayed(const Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      c.pad.value = 0;
    });
  }
}

class BodyWidget extends StatelessWidget {
  late final ArticleListItemWidgetController c;

  final String getxId;

  BodyWidget({
    super.key,
    required this.getxId,
  }) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: c.articleListItem.addBottomPadding
          ? c.articleListItem.showDetail
              ? const EdgeInsets.only(bottom: 6)
              : const EdgeInsets.only(bottom: 50)
          : EdgeInsets.zero,
      decoration: !Settings.themeFlat
          ? BoxDecoration(
              color: c.articleListItem.showDetail
                  ? Settings.themeWhat
                      ? Settings.themeBlack
                          ? Palette.blackThemeBackground
                          : Colors.grey.shade800
                      : Colors.white70
                  : Colors.grey.withOpacity(0.3),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              boxShadow: [
                BoxShadow(
                  color: Settings.themeWhat
                      ? Colors.grey.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.4),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3), // changes position of shadow
                ),
              ],
            )
          : null,
      color: !Settings.themeFlat || !c.articleListItem.showDetail
          ? null
          : Settings.themeWhat
              ? Colors.black26
              : Colors.white,
      child: c.articleListItem.showDetail
          ? IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  ThumbnailWidget(
                    getxId: getxId,
                  ),
                  Expanded(
                    child: _DetailWidget(
                      getxId: getxId,
                    ),
                  )
                ],
              ),
            )
          : ThumbnailWidget(
              getxId: getxId,
            ),
    );
  }
}

// Artist List Item Details
class _DetailWidget extends StatelessWidget {
  late final ArticleListItemWidgetController c;

  _DetailWidget({
    required String getxId,
  }) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Theme(
        data: ThemeData(
            useMaterial3: false,
            iconTheme: IconThemeData(
                color: !Settings.themeWhat ? Colors.black : Colors.white)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              c.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              c.artist,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (c.articleListItem.showUltra) tagArea() else const Spacer(),
            Row(
              children: [
                const Icon(Icons.date_range, size: 18),
                Text(
                  ' ${c.dateTime}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2.0),
            Row(
              children: [
                const Icon(Icons.photo, size: 18),
                Obx(
                  () => Text(
                    ' ${c.imageCount.value} Page',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4.0),
                if (c.articleListItem.viewed != null)
                  const Icon(MdiIcons.eyeOutline, size: 18),
                if (c.articleListItem.viewed != null)
                  Text(
                    ' ${c.articleListItem.viewed} Viewed',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                if (c.articleListItem.seconds != null)
                  const Icon(MdiIcons.clockOutline, size: 18),
                if (c.articleListItem.seconds != null)
                  Text(
                    ' ${c.articleListItem.seconds} Seconds',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget tagArea() {
    if (c.articleListItem.queryResult.tags() == null) {
      return Container(height: 30);
    }

    final tags = (c.articleListItem.queryResult.tags() as String)
        .split('|')
        .where((element) => element != '')
        .map((e) => Tuple2<String, String>(
            e.contains(':') ? e.split(':')[0] : 'tags',
            e.contains(':') ? e.split(':')[1] : e))
        .toList();

    return Wrap(
      spacing: 3.0,
      runSpacing: -10.0,
      children:
          tags.map((x) => TagChip(group: x.item1, name: x.item2)).toList(),
    );
  }
}

class TagChip extends StatelessWidget {
  final String name;
  final String group;

  const TagChip({super.key, required this.name, required this.group});

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
        backgroundColor: color,
        elevation: 6.0,
        // shadowColor: Colors.grey[60],
        padding: const EdgeInsets.all(6.0),
      ),
      onTap: () async {
        final targetTag = '${normalize(group)}:${name.replaceAll(' ', '_')}';

        CupertinoScaffold? cached;
        if (ModalBottomSheetContext.up() == 0) {
          await CupertinoScaffold.showCupertinoModalBottomSheet(
            context: context,
            builder: (context) {
              cached ??=
                  CupertinoScaffold(body: SearchPage(searchKeyWord: targetTag));
              return cached!;
            },
          );
        } else {
          await showCupertinoModalBottomSheet(
            context: context,
            builder: (context) {
              cached ??=
                  CupertinoScaffold(body: SearchPage(searchKeyWord: targetTag));
              return cached!;
            },
          );
        }

        ModalBottomSheetContext.down();
      },
      onLongPress: () async {
        final targetTag = '${normalize(group)}:${name.replaceAll(' ', '_')}';
        if (!Settings.excludeTags.contains(targetTag)) {
          final yn =
              await showYesNoDialog(context, '$targetTag 태그를 제외태그에 추가할까요?');
          if (yn) {
            Settings.excludeTags.add(targetTag);
            await Settings.setExcludeTags(Settings.excludeTags.join(' '));
            await showOkDialog(context, '제외태그에 성공적으로 추가했습니다!');
          }
        } else {
          await showOkDialog(context, '$targetTag 태그는 이미 제외태그에 추가된 항목입니다!');
        }
      },
    );

    return SizedBox(
      height: 42,
      child: FittedBox(child: fc),
    );
  }
}

class ModalInsideModal extends StatelessWidget {
  final bool reverse;

  const ModalInsideModal({super.key, this.reverse = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Material(
            child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          reverse: reverse,
          shrinkWrap: true,
          controller: ModalScrollController.of(context),
          physics: const ClampingScrollPhysics(),
          children: ListTile.divideTiles(
              context: context,
              tiles: List.generate(
                100,
                (index) => ListTile(
                    title: Text('Item $index'),
                    onTap: () => showCupertinoModalBottomSheet(
                          expand: true,
                          isDismissible: false,
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              ModalInsideModal(reverse: reverse),
                        )),
              )).toList(),
        ),
      ),
    )));
  }
}
