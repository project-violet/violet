// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/network/wrapper.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';
import 'package:violet/widgets/toast.dart';

typedef void BookmarkCallback(int article);
typedef void BookmarkCheckCallback(int article, bool check);

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  // final bool addBottomPadding;
  // final bool showDetail;
  // final QueryResult queryResult;
  // final double width;
  // final String thumbnailTag;
  // final bool bookmarkMode;
  // final BookmarkCallback bookmarkCallback;
  // final BookmarkCheckCallback bookmarkCheckCallback;
  bool isChecked;
  final bool isCheckMode;
  final ArticleListItem articleListItem;

  ArticleListItemVerySimpleWidget({
    // this.queryResult,
    // this.addBottomPadding,
    // this.showDetail,
    // this.width,
    // this.thumbnailTag,
    // this.bookmarkMode = false,
    // this.bookmarkCallback,
    // this.bookmarkCheckCallback,
    this.isChecked = false,
    this.isCheckMode = false,
    this.articleListItem,
  });

  @override
  _ArticleListItemVerySimpleWidgetState createState() =>
      _ArticleListItemVerySimpleWidgetState();
}

class _ArticleListItemVerySimpleWidgetState
    extends State<ArticleListItemVerySimpleWidget>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<ArticleListItemVerySimpleWidget> {
  ArticleListItem data;

  @override
  bool get wantKeepAlive => true;

  String thumbnail;
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
  Map<String, String> headers;
  final FlareControls _flareController = FlareControls();
  double thisWidth, thisHeight;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  String artist;
  String title;
  String dateTime;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  bool firstChecked = false;

  bool _inited = false;

  _init() {
    if (_inited) return;
    _inited = true;

    if (widget.articleListItem == null)
      data = Provider.of<ArticleListItem>(context);
    else
      data = widget.articleListItem;

    disableFiltering = (data.disableFilter != null && data.disableFilter);

    thisWidth = data.showDetail
        ? data.width - 16
        : data.width - (data.addBottomPadding ? 100 : 0);
    thisHeight = data.showDetail
        ? 130.0
        : data.addBottomPadding
            ? 500.0
            : data.width * 4 / 3;

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
              e.lastPage() > 1 &&
              DateTime.parse(e.datetimeStart())
                      .difference(DateTime.now())
                      .inDays <
                  31);
          if (x.length == 0) return;
          _shouldReload = true;
          setState(() {
            isLastestRead = true;
            latestReadPage = x.first.lastPage();
          });
        }));
  }

  _initTexts() {
    artist = (data.queryResult.artists() as String)
        .split('|')
        .where((x) => x.length != 0)
        .join(',');
    if (artist == 'N/A') {
      var group = data.queryResult.groups() != null
          ? data.queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    title = HtmlUnescape().convert(data.queryResult.title());
    dateTime = data.queryResult.getDateTime() != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(data.queryResult.getDateTime())
        : '';
    _shouldReload = true;

    if (data.showDetail) setState(() {});
  }

  _setProvider() {
    if (!ProviderManager.isExists(data.queryResult.id())) {
      HentaiManager.getImageProvider(data.queryResult).then((value) async {
        thumbnail = await value.getThumbnailUrl();
        imageCount = value.length();
        headers = await value.getHeader(0);
        ProviderManager.insert(data.queryResult.id(), value);
        if (!disposed)
          setState(() {
            _shouldReload = true;
          });
      });
    } else {
      Future.delayed(Duration(milliseconds: 1)).then((v) async {
        var provider = ProviderManager.get(data.queryResult.id());
        thumbnail = await provider.getThumbnailUrl();
        imageCount = provider.length();
        headers = await provider.getHeader(0);
        if (!disposed)
          setState(() {
            _shouldReload = true;
          });
      });
    }
  }

  BodyWidget _body;
  bool _shouldReload = false;

  Widget _cachedBuildWidget;
  bool _shouldReloadCachedBuildWidget = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (disposed) return null;

    _init();

    if (data.bookmarkMode &&
        !widget.isCheckMode &&
        !onScaling &&
        scale != 1.0) {
      _shouldReloadCachedBuildWidget = true;
      Future.delayed(Duration(milliseconds: 500))
          .then((value) => _shouldReloadCachedBuildWidget = false);
      setState(() {
        scale = 1.0;
      });
    } else if (data.bookmarkMode &&
        widget.isCheckMode &&
        widget.isChecked &&
        scale != 0.95) {
      _shouldReloadCachedBuildWidget = true;
      Future.delayed(Duration(milliseconds: 500))
          .then((value) => _shouldReloadCachedBuildWidget = false);
      setState(() {
        scale = 0.95;
      });
    }

    if (_cachedBuildWidget == null ||
        _shouldReloadCachedBuildWidget ||
        _shouldReload) {
      if (_body == null || _shouldReload) {
        _shouldReload = false;

        // https://stackoverflow.com/a/52249579
        final body = BodyWidget(
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
        color: widget.isChecked ? Colors.amber : Colors.transparent,
        child: PimpedButton(
          particle: Rectangle2DemoParticle(),
          pimpedWidgetBuilder: (context, controller) {
            return GestureDetector(
              child: SizedBox(
                width: thisWidth,
                height: thisHeight,
                child: AnimatedContainer(
                  curve: Curves.easeInOut,
                  duration: const Duration(milliseconds: 300),
                  transform: Matrix4.identity()
                    ..translate(thisWidth / 2, thisHeight / 2)
                    ..scale(scale)
                    ..translate(-thisWidth / 2, -thisHeight / 2),
                  child: _body,
                ),
              ),
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onLongPress: () async {
                await _onLongPress(controller);
              },
              onLongPressEnd: _onPressEnd,
              onTapCancel: _onTapCancle,
              onDoubleTap: _onDoubleTap,
            );
          },
        ),
      );
    }

    return _cachedBuildWidget;
  }

  _onTapDown(detail) {
    if (onScaling) return;
    onScaling = true;
    _shouldReloadCachedBuildWidget = true;
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      // pad = 10.0;
      scale = 0.95;
    });
  }

  _onTapUp(detail) {
    if (data.selectMode) {
      data.selectCallback();
      return;
    }

    onScaling = false;

    if (widget.isCheckMode) {
      widget.isChecked = !widget.isChecked;
      data.bookmarkCheckCallback(data.queryResult.id(), widget.isChecked);
      _shouldReloadCachedBuildWidget = true;
      Future.delayed(Duration(milliseconds: 500))
          .then((value) => _shouldReloadCachedBuildWidget = false);
      setState(() {
        if (widget.isChecked)
          scale = 0.95;
        else
          scale = 1.0;
      });
      return;
    }
    if (firstChecked) return;
    _shouldReloadCachedBuildWidget = true;
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      scale = 1.0;
    });

    final height = MediaQuery.of(context).size.height;

    // https://github.com/flutter/flutter/issues/67219
    var cache;
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
            if (cache == null) {
              cache = Provider<ArticleInfo>.value(
                child: ArticleInfoPage(
                  key: ObjectKey('asdfasdf'),
                ),
                value: ArticleInfo.fromArticleInfo(
                  queryResult: data.queryResult,
                  thumbnail: thumbnail,
                  headers: headers,
                  heroKey: data.thumbnailTag,
                  isBookmarked: isBookmarked.value,
                  controller: controller,
                  usableTabList: data.usableTabList,
                ),
              );
            }
            return cache;
          },
        );
      },
    );
  }

  Future<void> _onLongPress(controller) async {
    onScaling = false;
    if (data.bookmarkMode) {
      if (widget.isCheckMode) {
        widget.isChecked = !widget.isChecked;
        _shouldReloadCachedBuildWidget = true;
        Future.delayed(Duration(milliseconds: 500))
            .then((value) => _shouldReloadCachedBuildWidget = false);
        setState(() {
          scale = 1.0;
        });
        return;
      }
      widget.isChecked = true;
      firstChecked = true;
      _shouldReloadCachedBuildWidget = true;
      Future.delayed(Duration(milliseconds: 500))
          .then((value) => _shouldReloadCachedBuildWidget = false);
      setState(() {
        scale = 0.95;
      });
      data.bookmarkCallback(data.queryResult.id());
      return;
    }

    if (isBookmarked.value) {
      if (!await showYesNoDialog(context, '북마크를 삭제할까요?', '북마크')) return;
    }
    try {
      FlutterToast(context).showToast(
        child: ToastWrapper(
          icon: isBookmarked.value ? Icons.delete_forever : Icons.check,
          color: isBookmarked.value
              ? Colors.redAccent.withOpacity(0.8)
              : Colors.greenAccent.withOpacity(0.8),
          msg:
              '${data.queryResult.id()}${Translations.of(context).trans(isBookmarked.value ? 'removetobookmark' : 'addtobookmark')}',
        ),
        gravity: ToastGravity.BOTTOM,
        toastDuration: Duration(seconds: 4),
      );
    } catch (e, st) {
      Logger.error(
          '[ArticleList-LongPress] E: ' + e.toString() + '\n' + st.toString());
    }
    isBookmarked.value = !isBookmarked.value;

    if (isBookmarked.value)
      await (await Bookmark.getInstance()).bookmark(data.queryResult.id());
    else
      await (await Bookmark.getInstance()).unbookmark(data.queryResult.id());

    if (!isBookmarked.value)
      _flareController.play('Unlike');
    else {
      controller.forward(from: 0.0);
      _flareController.play('Like');
    }

    await HapticFeedback.vibrate();

    _shouldReloadCachedBuildWidget = true;
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      pad = 0;
      scale = 1.0;
    });
  }

  _onPressEnd(detail) {
    onScaling = false;
    if (firstChecked) {
      firstChecked = false;
      return;
    }
    _shouldReloadCachedBuildWidget = true;
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      pad = 0;
      scale = 1.0;
    });
  }

  _onTapCancle() {
    onScaling = false;
    _shouldReloadCachedBuildWidget = true;
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      pad = 0;
      scale = 1.0;
    });
  }

  Future<void> _onDoubleTap() async {
    onScaling = false;

    if (data.doubleTapCallback == null) {
      var sz = await _calculateImageDimension(thumbnail);
      Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        transitionDuration: Duration(milliseconds: 500),
        transitionsBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation, Widget wi) {
          return FadeTransition(opacity: animation, child: wi);
        },
        pageBuilder: (_, __, ___) => ThumbnailViewPage(
          size: sz,
          thumbnail: thumbnail,
          headers: headers,
          heroKey: data.thumbnailTag,
        ),
      ));
    } else {
      data.doubleTapCallback();
    }

    _shouldReloadCachedBuildWidget = true;
    Future.delayed(Duration(milliseconds: 500))
        .then((value) => _shouldReloadCachedBuildWidget = false);
    setState(() {
      pad = 0;
    });
  }

  Future<Size> _calculateImageDimension(String url) {
    Completer<Size> completer = Completer();
    Image image = Image(image: CachedNetworkImageProvider(url));
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }
}

class BodyWidget extends StatelessWidget {
  final ArticleListItem data;
  final String thumbnail;
  final int imageCount;
  final ValueNotifier<bool> isBookmarked;
  final FlareControls flareController;
  final double pad;
  final bool isBlurred;
  final Map<String, String> headers;
  final bool isLastestRead;
  final int latestReadPage;
  final bool disableFiltering;
  final String artist;
  final String title;
  final String dateTime;

  BodyWidget({
    this.data,
    this.thumbnail,
    this.imageCount,
    this.isBookmarked,
    this.flareController,
    this.pad,
    this.isBlurred,
    this.headers,
    this.isLastestRead,
    this.latestReadPage,
    this.disableFiltering,
    this.artist,
    this.title,
    this.dateTime,
  });

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
                      ? Colors.grey.shade800
                      : Colors.white70
                  : Colors.grey.withOpacity(0.3),
              borderRadius: const BorderRadius.all(const Radius.circular(3)),
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
          ? Row(
              children: <Widget>[
                ThumbnailWidget(
                  id: data.queryResult.id().toString(),
                  showDetail: data.showDetail,
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
                ))
              ],
            )
          : ThumbnailWidget(
              id: data.queryResult.id().toString(),
              showDetail: data.showDetail,
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
  final String title;
  final String artist;
  final int imageCount;
  final String dateTime;
  final int viewed;
  final int seconds;

  _DetailWidget({
    this.title,
    this.artist,
    this.imageCount,
    this.dateTime,
    this.viewed,
    this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            artist,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
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
}
