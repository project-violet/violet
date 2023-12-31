// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/pages/viewer/viewer_page.dart';
import 'package:violet/pages/viewer/viewer_page_provider.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/dots_indicator.dart';

class ViewerTabPanel extends StatefulWidget {
  final int articleId;
  final double height;
  final List<QueryResult>? usableTabList;

  const ViewerTabPanel({
    super.key,
    required this.articleId,
    this.usableTabList,
    required this.height,
  });

  @override
  State<ViewerTabPanel> createState() => _ViewerTabPanelState();
}

class _ViewerTabPanelState extends State<ViewerTabPanel> {
  final PageController _pageController = PageController(initialPage: 0);

  // static const _kDuration = const Duration(milliseconds: 300);
  // static const _kCurve = Curves.ease;

  static const _kDuration = Duration(milliseconds: 300);
  static const _kCurve = Curves.ease;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var view = Stack(
      children: [
        PageView(
          controller: _pageController,
          children: [
            if (widget.usableTabList != null)
              _UsableTabList(
                articleId: widget.articleId,
                usableTabList: widget.usableTabList!,
              ),
            _ArtistsArticleTabList(
              height: widget.height,
              articleId: widget.articleId,
            ),
          ],
        ),
        FutureBuilder(
          future: Future.value(1),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Container();
            return Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: Container(
                color: null,
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: DotsIndicator(
                    controller: _pageController,
                    itemCount: widget.usableTabList != null ? 2 : 1,
                    onPageSelected: (int page) {
                      _pageController.animateToPage(
                        page,
                        duration: _kDuration,
                        curve: _kCurve,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );

    if (Settings.enableViewerFunctionBackdropFilter) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
            padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
            child: view,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black.withOpacity(0.8),
        padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
        child: view,
      );
    }
  }
}

class _UsableTabList extends StatefulWidget {
  final int articleId;
  final List<QueryResult> usableTabList;

  const _UsableTabList({
    required this.articleId,
    required this.usableTabList,
  });

  @override
  State<_UsableTabList> createState() => __UsableTabListState();
}

class __UsableTabListState extends State<_UsableTabList>
    with AutomaticKeepAliveClientMixin<_UsableTabList> {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  Map<int, GlobalKey> itemKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();

    for (var element in widget.usableTabList) {
      itemKeys[element.id()] = GlobalKey();
    }

    Future.value(1).then((value) {
      var row = widget.usableTabList
              .indexWhere((element) => element.id() == widget.articleId) ~/
          3;
      if (row == 0) return;
      var firstItemHeight = (itemKeys[widget.usableTabList.first.id()]!
              .currentContext!
              .findRenderObject() as RenderBox)
          .size
          .height;
      _scrollController.jumpTo(
        row * (firstItemHeight + 8) - 100,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var windowWidth = MediaQuery.of(context).size.width;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      controller: _scrollController,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildListDelegate(
              widget.usableTabList.map(
                (e) {
                  return Padding(
                    key: itemKeys[e.id()],
                    padding: EdgeInsets.zero,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Provider<ArticleListItem>.value(
                        value: ArticleListItem.fromArticleListItem(
                          queryResult: e,
                          addBottomPadding: false,
                          showDetail: false,
                          width: (windowWidth - 4.0) / 3.0,
                          thumbnailTag: const Uuid().v4(),
                          selectMode: true,
                          selectCallback: () {
                            Navigator.pop(context, e);
                          },
                        ),
                        child: const ArticleListItemWidget(),
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistsArticleTabList extends StatefulWidget {
  final int articleId;
  final double height;

  const _ArtistsArticleTabList({
    required this.articleId,
    required this.height,
  });

  @override
  State<_ArtistsArticleTabList> createState() => __ArtistsArticleTabListState();
}

class __ArtistsArticleTabListState extends State<_ArtistsArticleTabList>
    with AutomaticKeepAliveClientMixin<_ArtistsArticleTabList> {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  Map<int, GlobalKey> itemKeys = <int, GlobalKey>{};
  bool isLoaded = false;
  bool isJumped = false;
  List<QueryResult> articleList = [];

  @override
  void initState() {
    super.initState();

    Future.value(1).then((value) async {
      final mqrr = await HentaiManager.idSearch(widget.articleId.toString());
      if (mqrr.results.isEmpty) return;

      final mqr = mqrr.results.first;

      var what = '';
      if (mqr.artists() != null) {
        what += (mqr.artists() as String)
            .split('|')
            .where((element) => element != '' && element.toLowerCase() != 'n/a')
            .map((element) => 'artist:${element.replaceAll(' ', '_')}')
            .join(' or ');
      }

      if (mqr.groups() != null) {
        if (what != '') what += ' or ';
        what += (mqr.groups() as String)
            .split('|')
            .where((element) => element != '' && element.toLowerCase() != 'n/a')
            .map((element) => 'group:${element.replaceAll(' ', '_')}')
            .join(' or ');
      }

      if (what == '') {
        setState(() => isLoaded = true);
        return;
      }

      final queryString = HitomiManager.translate2query(
          '($what) ${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ').trim()}');
      var queryResult = (await (await DataBaseManager.getInstance())
              .query('$queryString ORDER BY Id DESC LIMIT 500'))
          .map((e) => QueryResult(result: e))
          .toList();

      if (queryResult.isEmpty) {
        setState(() => isLoaded = true);
        return;
      }

      articleList = queryResult;
      for (var element in articleList) {
        itemKeys[element.id()] = GlobalKey();
      }

      setState(() => isLoaded = true);

      if (!articleList.any((element) => element.id() == widget.articleId)) {
        return;
      }

      Future.delayed(const Duration(milliseconds: 50)).then((value) {
        var row = articleList
                .indexWhere((element) => element.id() == widget.articleId) ~/
            3;
        if (row == 0) return;
        var firstItemHeight = (itemKeys[articleList.first.id()]!
                .currentContext!
                .findRenderObject() as RenderBox)
            .size
            .height;
        _scrollController.jumpTo(
          row * (firstItemHeight + 8) - 100,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    var windowWidth = MediaQuery.of(context).size.width;

    return !isLoaded
        ? Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Settings.majorColor.withAlpha(150),
              ),
            ),
          )
        : CustomScrollView(
            physics: const BouncingScrollPhysics(),
            controller: _scrollController,
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3 / 4,
                  ),
                  delegate: SliverChildListDelegate(
                    articleList.map(
                      (e) {
                        return Padding(
                          key: itemKeys[e.id()],
                          padding: EdgeInsets.zero,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Provider<ArticleListItem>.value(
                              value: ArticleListItem.fromArticleListItem(
                                queryResult: e,
                                addBottomPadding: false,
                                showDetail: false,
                                width: (windowWidth - 4.0) / 3.0,
                                thumbnailTag: const Uuid().v4(),
                                selectMode: true,
                                selectCallback: () async {
                                  if (!Settings
                                      .showNewViewerWhenArtistArticleListItemTap) {
                                    _showArticleInfo(e);
                                  } else {
                                    _showViewer(e);
                                  }
                                },
                              ),
                              child: const ArticleListItemWidget(),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
              ),
            ],
          );
  }

  Future<void> _showArticleInfo(QueryResult e) async {
    var prov = await ProviderManager.get(e.id());
    var thumbnail = await prov.getThumbnailUrl();
    var headers = await prov.getHeader(0);
    ProviderManager.insert(e.id(), prov);

    var isBookmarked = await (await Bookmark.getInstance()).isBookmark(e.id());

    Provider<ArticleInfo>? cache;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 400 / widget.height,
          minChildSize: 400 / widget.height,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            cache ??= Provider<ArticleInfo>.value(
              value: ArticleInfo.fromArticleInfo(
                queryResult: e,
                thumbnail: thumbnail,
                headers: headers,
                heroKey: 'zxcvzxcvzxcv',
                isBookmarked: isBookmarked,
                controller: controller,
                usableTabList: articleList,
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

  Future<void> _showViewer(QueryResult e) async {
    if (Settings.useVioletServer) {
      Future.delayed(const Duration(milliseconds: 100)).then((value) async {
        await VioletServer.view(e.id());
      });
    }

    await (await User.getInstance()).insertUserLog(e.id(), 0);

    var prov = await ProviderManager.get(e.id());

    await prov.init();

    var headers = await prov.getHeader(0);

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Provider<ViewerPageProvider>.value(
              value: ViewerPageProvider(
                uris: List<String>.filled(prov.length(), ''),
                useProvider: true,
                provider: prov,
                headers: headers,
                id: e.id(),
                title: e.title(),
                usableTabList: articleList,
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
