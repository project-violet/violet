// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/component/image_provider.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';
import 'package:violet/widgets/theme_switchable_state.dart';
import 'package:violet/widgets/toast.dart';

typedef BookmarkCallback = void Function(int article);
typedef BookmarkCheckCallback = void Function(int article, bool check);

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  final bool isChecked;
  final bool isCheckMode;
  final ArticleListItem? articleListItem;

  const ArticleListItemVerySimpleWidget({
    Key? key,
    this.isChecked = false,
    this.isCheckMode = false,
    this.articleListItem,
  }) : super(key: key);

  @override
  State<ArticleListItemVerySimpleWidget> createState() =>
      _ArticleListItemVerySimpleWidgetState();
}

class _ArticleListItemVerySimpleWidgetState
    extends State<ArticleListItemVerySimpleWidget>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<ArticleListItemVerySimpleWidget> {
  late ArticleListItem data;

  @override
  bool get wantKeepAlive => true;

  String? thumbnail;
  int imageCount = 0;
  double pad = 0.0;
  double scale = 1.0;
  bool onScaling = false;
  bool isBlurred = false;
  bool disposed = false;
  ValueNotifier<bool> isBookmarked = ValueNotifier<bool>(false);
  bool animating = false;
  bool isLastestRead = false;
  bool disableFiltering = false;
  int latestReadPage = 0;
  Map<String, String>? headers;
  FlareControls? _flareController;
  double? thisWidth, thisHeight;

  GlobalKey bodyKey = GlobalKey();

  bool isChecked = false;

  late final FToast fToast;

  @override
  void initState() {
    super.initState();
    isChecked = widget.isChecked;
    fToast = FToast();
    fToast.init(context);
  }

  String? artist;
  String? title;
  String? dateTime;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _init();
  }

  bool firstChecked = false;
  bool _inited = false;
  _init() {
    if (_inited) return;
    _inited = true;

    if (!Settings.simpleItemWidgetLoadingIcon) {
      _flareController = FlareControls();
    }

    data = Provider.of<ArticleListItem>(context);

    disableFiltering = data.disableFilter;

    if (data.showDetail) {
      thisWidth = data.width - 16;
      if (!data.showUltra) {
        thisHeight = 130.0;
      } else {
        Future.delayed(const Duration(milliseconds: 500)).then((value) {
          if (bodyKey.currentContext != null) {
            _shouldReload = true;
            setState(() {
              thisHeight = bodyKey.currentContext!.size!.height;
            });
          }
        });
      }
    } else {
      thisWidth = data.width - (data.addBottomPadding ? 100 : 0);
      if (data.addBottomPadding) {
        thisHeight = 500.0;
      } else {
        thisHeight = data.width * 4 / 3;
      }
    }

    _checkIsBookmarked();
    _checkLastRead();
    _initTexts();
    _setProvider();
  }

  _checkIsBookmarked() {
    Bookmark.getInstance().then((value) async {
      isBookmarked.value = await value.isBookmark(data.queryResult.id());
    });
  }

  _checkLastRead() {
    User.getInstance().then((value) => value.getUserLog().then((value) async {
          var x = value.where((e) =>
              e.articleId() == data.queryResult.id().toString() &&
              e.lastPage() != null &&
              e.lastPage()! > 1 &&
              DateTime.parse(e.datetimeStart())
                      .difference(DateTime.now())
                      .inDays <
                  31);
          if (x.isEmpty) return;
          _shouldReload = true;
          setState(() {
            isLastestRead = true;
            latestReadPage = x.first.lastPage()!;
          });
        }));
  }

  _initTexts() {
    artist = (data.queryResult.artists() as String)
        .split('|')
        .where((x) => x.isNotEmpty)
        .join(',');

    if (artist == 'N/A') {
      var group = data.queryResult.groups() != null
          ? data.queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    title = HtmlUnescape().convert(data.queryResult.title());
    dateTime = data.queryResult.getDateTime() != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(data.queryResult.getDateTime()!)
        : '';

    _shouldReload = true;

    if (data.showDetail) setState(() {});
  }

  _setProvider() async {
    VioletImageProvider provider;

    if (!ProviderManager.isExists(data.queryResult.id())) {
      provider = await HentaiManager.getImageProvider(data.queryResult);
      ProviderManager.insert(data.queryResult.id(), provider);
    } else {
      provider = await ProviderManager.get(data.queryResult.id());
    }

    thumbnail = await provider.getThumbnailUrl();
    imageCount = provider.length();
    headers = await provider.getHeader(0);
    if (!disposed) {
      setState(() {
        _shouldReload = true;
      });
    }
  }

  BodyWidget? _body;
  bool _shouldReload = false;

  Widget? _cachedBuildWidget;
  bool _shouldReloadCachedBuildWidget = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (disposed) return Container();

    _doBookmarkScaling();

    if (_cachedBuildWidget == null ||
        _shouldReloadCachedBuildWidget ||
        _shouldReload) {
      if (_body == null || _shouldReload) {
        _shouldReload = false;

        // https://stackoverflow.com/a/52249579
        final body = BodyWidget(
          key: bodyKey,
          data: data,
          thumbnail: thumbnail,
          imageCount: imageCount,
          isBookmarked: isBookmarked,
          flareController: _flareController,
          pad: pad,
          isBlurred: isBlurred,
          headers: headers,
          isLastestRead: isLastestRead,
          latestReadPage: latestReadPage,
          disableFiltering: disableFiltering,
          artist: artist,
          title: title,
          dateTime: dateTime,
        );

        _body = body;
      }

      _cachedBuildWidget = Container(
        color: isChecked ? Colors.amber : Colors.transparent,
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
              child: SizedBox(
                width: thisWidth,
                height: thisHeight,
                child: AnimatedContainer(
                  curve: Curves.easeInOut,
                  duration: const Duration(milliseconds: 300),
                  transform: thisHeight == null
                      ? null
                      : (Matrix4.identity()
                        ..translate(thisWidth! / 2, thisHeight! / 2)
                        ..scale(scale)
                        ..translate(-thisWidth! / 2, -thisHeight! / 2)),
                  child: _body,
                ),
              ),
            );
          },
        ),
      );
    }

    return _cachedBuildWidget!;
  }

  _doBookmarkScaling() {
    if (data.bookmarkMode) {
      if (!widget.isCheckMode && !onScaling && scale != 1.0) {
        _animateScale(1.0);
      } else if (widget.isCheckMode && isChecked && scale != 0.95) {
        _animateScale(0.95);
      }
    }
  }

  _animateScale(double scale) {
    _shouldReloadCachedBuildWidget = true;
    Future.delayed(const Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      this.scale = scale;
    });
  }

  _onTapDown(detail) {
    if (onScaling) return;
    onScaling = true;
    _animateScale(0.95);
  }

  _onTapUp(detail) async {
    if (data.selectMode) {
      data.selectCallback!();
      return;
    }

    onScaling = false;

    if (widget.isCheckMode) {
      isChecked = !isChecked;
      data.bookmarkCheckCallback!(data.queryResult.id(), isChecked);
      _animateScale(isChecked ? 0.95 : 1.0);
      return;
    }

    if (firstChecked) return;

    _animateScale(1.0);

    if (!Settings.lightMode) {
      _showArticleInfo();
    } else {
      _viewArticle();
    }
  }

  _showArticleInfo() {
    final height = MediaQuery.of(context).size.height;

    // https://github.com/flutter/flutter/issues/67219
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
                queryResult: data.queryResult,
                thumbnail: thumbnail,
                headers: headers,
                heroKey: data.thumbnailTag,
                isBookmarked: isBookmarked.value,
                controller: controller,
                usableTabList: data.usableTabList,
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
  }

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
              headers: headers,
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
    onScaling = false;
    if (data.bookmarkMode) {
      if (widget.isCheckMode) {
        isChecked = !isChecked;
        _animateScale(1.0);
        return;
      }
      isChecked = true;
      firstChecked = true;
      _animateScale(0.95);
      data.bookmarkCallback!(data.queryResult.id());
      return;
    }

    if (isBookmarked.value) {
      if (!await showYesNoDialog(context, '북마크를 삭제할까요?', '북마크')) return;
    }
    try {
      fToast.showToast(
        child: ToastWrapper(
          icon: isBookmarked.value ? Icons.delete_forever : Icons.check,
          color: isBookmarked.value
              ? Colors.redAccent.withOpacity(0.8)
              : Colors.greenAccent.withOpacity(0.8),
          msg:
              '${data.queryResult.id()}${Translations.of(context).trans(isBookmarked.value ? 'removetobookmark' : 'addtobookmark')}',
        ),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
      );
    } catch (e, st) {
      Logger.error('[ArticleList-LongPress] E: $e\n'
          '$st');
    }
    isBookmarked.value = !isBookmarked.value;

    if (isBookmarked.value) {
      await (await Bookmark.getInstance()).bookmark(data.queryResult.id());
    } else {
      await (await Bookmark.getInstance()).unbookmark(data.queryResult.id());
    }

    if (!isBookmarked.value) {
      if (!Settings.simpleItemWidgetLoadingIcon) {
        _flareController!.play('Unlike');
      }
    } else {
      controller.forward(from: 0.0);
      if (!Settings.simpleItemWidgetLoadingIcon) _flareController!.play('Like');
    }

    await HapticFeedback.lightImpact();

    pad = 0;
    _animateScale(1.0);
  }

  _onPressEnd(detail) {
    onScaling = false;
    if (firstChecked) {
      firstChecked = false;
      return;
    }

    pad = 0;
    _animateScale(1.0);
  }

  _onTapCancle() {
    onScaling = false;

    pad = 0;
    _animateScale(1.0);
  }

  Future<void> _onDoubleTap() async {
    if (!Settings.lightMode) {
      _showThumbnailView();
    } else {
      _showArticleInfo();
    }
  }

  _showThumbnailView() async {
    onScaling = false;

    if (data.doubleTapCallback == null) {
      Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation, Widget wi) {
          return FadeTransition(opacity: animation, child: wi);
        },
        pageBuilder: (_, __, ___) => ThumbnailViewPage(
          thumbnail: thumbnail!,
          headers: headers!,
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
      pad = 0;
    });
  }
}

class BodyWidget extends StatelessWidget {
  final ArticleListItem data;
  final String? thumbnail;
  final int imageCount;
  final ValueNotifier<bool> isBookmarked;
  final FlareControls? flareController;
  final double pad;
  final bool isBlurred;
  final Map<String, String>? headers;
  final bool isLastestRead;
  final int latestReadPage;
  final bool disableFiltering;
  final String? artist;
  final String? title;
  final String? dateTime;

  const BodyWidget({
    Key? key,
    required this.data,
    required this.thumbnail,
    required this.imageCount,
    required this.isBookmarked,
    required this.flareController,
    required this.pad,
    required this.isBlurred,
    required this.headers,
    required this.isLastestRead,
    required this.latestReadPage,
    required this.disableFiltering,
    required this.artist,
    required this.title,
    required this.dateTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: data.addBottomPadding
          ? data.showDetail
              ? const EdgeInsets.only(bottom: 6)
              : const EdgeInsets.only(bottom: 50)
          : EdgeInsets.zero,
      decoration: !Settings.themeFlat
          ? BoxDecoration(
              color: data.showDetail
                  ? Settings.themeWhat
                      ? Settings.themeBlack
                          ? const Color(0xFF141414)
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
      color: !Settings.themeFlat || !data.showDetail
          ? null
          : Settings.themeWhat
              ? Colors.black26
              : Colors.white,
      child: data.showDetail
          ? IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  ThumbnailWidget(
                    id: data.queryResult.id().toString(),
                    showDetail: data.showDetail,
                    showUltra: data.showUltra,
                    thumbnail: thumbnail,
                    thumbnailTag: data.thumbnailTag,
                    imageCount: imageCount,
                    isBookmarked: isBookmarked,
                    flareController: flareController,
                    pad: pad,
                    isBlurred: isBlurred,
                    headers: headers,
                    isLastestRead: isLastestRead,
                    latestReadPage: latestReadPage,
                    disableFiltering: disableFiltering,
                  ),
                  Expanded(
                    child: _DetailWidget(
                      artist: artist,
                      title: title,
                      imageCount: imageCount,
                      dateTime: dateTime,
                      viewed: data.viewed,
                      seconds: data.seconds,
                      showUltra: data.showUltra,
                      queryResult: data.queryResult,
                    ),
                  )
                ],
              ),
            )
          : ThumbnailWidget(
              id: data.queryResult.id().toString(),
              showDetail: data.showDetail,
              showUltra: data.showUltra,
              thumbnail: thumbnail,
              thumbnailTag: data.thumbnailTag,
              imageCount: imageCount,
              isBookmarked: isBookmarked,
              flareController: flareController,
              pad: pad,
              isBlurred: isBlurred,
              headers: headers,
              isLastestRead: isLastestRead,
              latestReadPage: latestReadPage,
              disableFiltering: disableFiltering,
            ),
    );
  }
}

// Artist List Item Details
class _DetailWidget extends StatelessWidget {
  final String? title;
  final String? artist;
  final int imageCount;
  final String? dateTime;
  final int? viewed;
  final int? seconds;
  final bool showUltra;
  final QueryResult queryResult;

  const _DetailWidget({
    required this.title,
    required this.artist,
    required this.imageCount,
    required this.dateTime,
    required this.viewed,
    required this.seconds,
    required this.showUltra,
    required this.queryResult,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            artist ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (showUltra) tagArea() else const Spacer(),
          Row(
            children: [
              const Icon(Icons.date_range, size: 18),
              Text(
                ' $dateTime',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Row(
            children: [
              const Icon(Icons.photo, size: 18),
              Text(
                ' $imageCount Page',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4.0),
              if (viewed != null) const Icon(MdiIcons.eyeOutline, size: 18),
              if (viewed != null)
                Text(
                  ' $viewed Viewed',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
              if (seconds != null) const Icon(MdiIcons.clockOutline, size: 18),
              if (seconds != null)
                Text(
                  ' $seconds Seconds',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget tagArea() {
    if (queryResult.tags() == null) return Container(height: 30);

    final tags = (queryResult.tags() as String)
        .split('|')
        .where((element) => element != '')
        .map((e) => Tuple2<String, String>(
            e.contains(':') ? e.split(':')[0] : 'tags',
            e.contains(':') ? e.split(':')[1] : e))
        .toList();

    return Wrap(
      spacing: 2.0,
      runSpacing: -10.0,
      children:
          tags.map((x) => TagChip(group: x.item1, name: x.item2)).toList(),
    );
  }
}

class TagChip extends StatelessWidget {
  final String name;
  final String group;

  const TagChip({Key? key, required this.name, required this.group})
      : super(key: key);

  String normalize(String tag) {
    if (tag == 'groups') return 'group';
    if (tag == 'artists') return 'artist';
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

    Widget avatar = Text(group[0].toUpperCase(),
        style: const TextStyle(color: Colors.white));

    if (group == 'female') {
      avatar = const Icon(
        MdiIcons.genderFemale,
        size: 18.0,
        color: Colors.white,
      );
    } else if (group == 'male') {
      avatar = const Icon(
        MdiIcons.genderMale,
        size: 18.0,
        color: Colors.white,
      );
    }

    final fc = GestureDetector(
      child: RawChip(
        labelPadding: const EdgeInsets.all(0.0),
        avatar: CircleAvatar(
          // backgroundColor: Colors.grey.shade600,
          backgroundColor: color,
          child: avatar,
        ),
        label: Text(
          ' $tagDisplayed',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
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
    );

    return SizedBox(
      height: 42,
      child: FittedBox(child: fc),
    );
  }
}
