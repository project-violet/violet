// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/segment/double_tap_to_top.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';
import 'package:violet/widgets/search_bar.dart';
import 'package:violet/widgets/theme_switchable_state.dart';

class HotPage extends StatefulWidget {
  const HotPage({super.key});

  @override
  State<HotPage> createState() => _HotPageState();
}

typedef RequestType = Tuple2<int, List<Tuple2<QueryResult, int>>?>;

class _HotPageState extends ThemeSwitchableState<HotPage>
    with AutomaticKeepAliveClientMixin<HotPage>, DoubleTapToTopMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  VoidCallback? get shouldReloadCallback => () => _shouldReload = true;

  bool _shouldReload = false;
  final Map<String, GlobalKey> itemKeys = {};

  AsyncMemoizer<RequestType>? _memoizer;
  Future<RequestType>? future;

  int index = 0;
  i2t() => ['daily', 'week', 'month', 'alltime'][index];
  i2tr() => ['daily', 'weekly', 'monthly', 'alltime'][index];

  Widget? cachedListView;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    future ??= _request();

    if (cachedListView == null || _shouldReload) {
      _shouldReload = false;

      itemKeys.clear();

      cachedListView = FutureBuilder(
        future: future,
        builder: (context, AsyncSnapshot<RequestType> snapshot) {
          late Widget sliverList;

          if (!snapshot.hasData) {
            sliverList = const SliverToBoxAdapter(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.data!.item1 != 200) {
            final errmsg = {
              400: 'Bad Request',
              403: 'Forbidden',
              429: 'Too Many Requests',
              500: 'Internal Server Error',
              502: 'Bad Gateway',
              521: 'Web server is down',
              //
              900: 'Nothing To Display',
              901: 'No Query Results.',
            };

            sliverList = SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Lottie.asset(
                        'assets/lottie/3227-error-404-facebook-style.json',
                      ),
                    ),
                    Container(height: 16),
                    const Text(
                      'Oops! Something was wrong!',
                      style: TextStyle(fontSize: 24),
                    ),
                    Container(height: 2),
                    const Text(
                      'If you still encounter this error, please contact the developer!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      errmsg[snapshot.data!.item1] != null
                          ? 'Error: ${errmsg[snapshot.data!.item1]!}'
                          : 'Error Code: ${snapshot.data!.item1}',
                    )
                  ],
                ),
              ),
            );
          } else {
            final windowWidth = MediaQuery.of(context).size.width;

            final results = snapshot.data!.item2!;

            sliverList = SliverList(
              delegate: SliverChildListDelegate(
                results.map((x) {
                  final keyStr = 'views$index/${x.item1.id()}';
                  if (!itemKeys.containsKey(keyStr)) {
                    itemKeys[keyStr] = GlobalKey();
                  }
                  return Align(
                    key: itemKeys[keyStr],
                    alignment: Alignment.center,
                    child: Provider<ArticleListItem>.value(
                      value: ArticleListItem.fromArticleListItem(
                        queryResult: x.item1,
                        showDetail: true,
                        showUltra: true,
                        addBottomPadding: true,
                        width: (windowWidth - 4.0),
                        thumbnailTag: const Uuid().v4(),
                        viewed: x.item2,
                        usableTabList: results.map((e) => e.item1).toList(),
                      ),
                      child: const ArticleListItemWidget(),
                    ),
                  );
                }).toList(),
              ),
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            controller: doubleTapToTopScrollController = ScrollController(),
            slivers: <Widget>[
              SliverPersistentHeader(
                floating: true,
                delegate: AnimatedOpacitySliver(
                  searchBar: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Stack(children: <Widget>[
                        _filter(),
                        _title(),
                      ])),
                ),
              ),
              sliverList,
            ],
          );
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: cachedListView!,
      ),
    );
  }

  Future<RequestType> _request([bool reload = false]) {
    _memoizer = AsyncMemoizer();
    return _memoizer!.runOnce(() async {
      final value = await VioletServer.top(0, 600, i2t());

      if (value is int) {
        return RequestType(value, null);
      }

      if (value == null || value.length == 0) {
        return const RequestType(900, null);
      }

      var queryRaw =
          '${HitomiManager.translate2query('${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}')} AND ';
      queryRaw += '(${value.map((e) => 'Id=${e.item1}').join(' OR ')})';
      final query = await QueryManager.query(queryRaw);

      if (query.results!.isEmpty) {
        return const Tuple2<int, List<Tuple2<QueryResult, int>>?>(901, null);
      }

      final qr = <String, QueryResult>{};
      for (var element in query.results!) {
        qr[element.id().toString()] = element;
      }

      final result = <Tuple2<QueryResult, int>>[];
      value.forEach((element) {
        if (qr[element.item1.toString()] == null) {
          // TODO: Handle qurey not found
          return;
        }
        result.add(Tuple2<QueryResult, int>(
            qr[element.item1.toString()]!, element.item2));
      });

      if (reload) setState(() {});

      return RequestType(200, result);
    });
  }

  Widget _filter() {
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton(
        color: Settings.themeWhat
            ? Settings.themeBlack
                ? const Color(0xFF060606)
                : Colors.grey.shade900.withOpacity(0.90)
            : Colors.grey.shade50,
        icon: Theme(
          data: ThemeData(
              useMaterial3: false,
              iconTheme: IconThemeData(
                  color: !Settings.themeWhat ? Colors.black : Colors.white)),
          child: const Icon(MdiIcons.finance),
        ),
        itemBuilder: (ctx) => [
          _buildPopupMenuItem('daily', 0, Icons.star),
          _buildPopupMenuItem('weekly', 1, MdiIcons.calendarWeek),
          _buildPopupMenuItem('monthly', 2, MdiIcons.calendarMonth),
          _buildPopupMenuItem('alltime', 3, MdiIcons.heart),
        ],
        onSelected: (index) {
          this.index = index! as int;
          cachedListView = null;
          future = _request(true);
        },
      ),
    );
  }

  PopupMenuItem _buildPopupMenuItem(
      String title, int index, IconData iconData) {
    return PopupMenuItem(
      value: index,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Theme(
            data: ThemeData(
                useMaterial3: false,
                iconTheme: IconThemeData(
                    color: !Settings.themeWhat ? Colors.black : Colors.white)),
            child: Icon(
              iconData,
            ),
          ),
          const SizedBox(width: 8),
          Text(Translations.instance!.trans(title)),
        ],
      ),
    );
  }

  Widget _title() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 12),
      child: Text(
        '${Translations.instance!.trans(i2tr())} ${Translations.instance!.trans('hot')}',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
