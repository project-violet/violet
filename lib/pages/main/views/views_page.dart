// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:bubble_tab_indicator/bubble_tab_indicator.dart';
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
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/v1/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class ViewsPage extends StatefulWidget {
  const ViewsPage({super.key});

  @override
  State<ViewsPage> createState() => _ViewsPageState();
}

class _ViewsPageState extends State<ViewsPage> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: <Widget>[
            TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BubbleTabIndicator(
                indicatorHeight: 40.0,
                indicatorColor: Settings.majorColor,
                tabBarIndicatorSize: TabBarIndicatorSize.tab,
                insets: const EdgeInsets.only(left: 8, right: 8, top: 21),
              ),
              tabs: [
                Container(
                  alignment: Alignment.center,
                  height: 50,
                  child: Column(
                    children: [
                      Container(height: 4),
                      Icon(Icons.star,
                          color: Settings.themeWhat ? null : Colors.black),
                      Text(Translations.of(context).trans('daily'),
                          style: Settings.themeWhat
                              ? null
                              : const TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  height: 50,
                  child: Column(
                    children: [
                      Container(height: 4),
                      Icon(MdiIcons.calendarWeek,
                          color: Settings.themeWhat ? null : Colors.black),
                      Text(Translations.of(context).trans('weekly'),
                          style: Settings.themeWhat
                              ? null
                              : const TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  height: 50,
                  child: Column(
                    children: [
                      Container(height: 4),
                      Icon(MdiIcons.calendarMonth,
                          color: Settings.themeWhat ? null : Colors.black),
                      Text(Translations.of(context).trans('monthly'),
                          style: Settings.themeWhat
                              ? null
                              : const TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  height: 50,
                  child: Column(
                    children: [
                      Container(height: 4),
                      Icon(MdiIcons.heart,
                          color: Settings.themeWhat ? null : Colors.black),
                      Text(Translations.of(context).trans('alltime'),
                          style: Settings.themeWhat
                              ? null
                              : const TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _Tab(0),
                  _Tab(1),
                  _Tab(2),
                  _Tab(3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final int index;

  const _Tab(this.index);

  @override
  State<_Tab> createState() => __TabState();
}

class __TabState extends State<_Tab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder(
      future: VioletServer.top(
              0, 600, ['daily', 'week', 'month', 'alltime'][widget.index])
          .then((value) async {
        if (value is int) return value;

        if (value == null || value.length == 0) return 900;

        var queryRaw =
            '${HitomiManager.translate2query('${Settings.includeTags} ${Settings.excludeTags.where((e) => e.trim() != '').map((e) => '-$e').join(' ')}')} AND ';
        // var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
        queryRaw += '(${value.map((e) => 'Id=${e.item1}').join(' OR ')})';
        var query = await QueryManager.query(queryRaw);

        if (query.results!.isEmpty) return 901;

        var qr = <String, QueryResult>{};
        for (var element in query.results!) {
          qr[element.id().toString()] = element;
        }

        var result = <Tuple2<QueryResult, int>>[];
        value.forEach((element) {
          if (qr[element.item1.toString()] == null) {
            // TODO: Handle qurey not found
            return;
          }
          result.add(Tuple2<QueryResult, int>(
              qr[element.item1.toString()]!, element.item2));
        });

        return result;
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.data is int) {
          var errmsg = {
            '400': 'Bad Request',
            '403': 'Forbidden',
            '429': 'Too Many Requests',
            '500': 'Internal Server Error',
            '502': 'Bad Gateway',
            '521': 'Web server is down',
            //
            '900': 'Nothing To Display',
            '901': 'No Query Results.',
          };
          return Center(
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
                    'Error${errmsg[snapshot.data.toString()] != null ? ': ${errmsg[snapshot.data.toString()]!}' : ' Code: ${snapshot.data}'}')
              ],
            ),
          );
        }

        // return ListView.builder(
        //   itemCount: snapshot.data.length,
        //   itemBuilder: (context, index) {
        //     return ListTile(
        //       title: Text(
        //           '${index + 1}. ' + snapshot.data[index].item1.toString()),
        //       subtitle: Text(snapshot.data[index].item2.toString()),
        //     );
        //   },
        // );
        var windowWidth = MediaQuery.of(context).size.width;

        var results = snapshot.data as List<Tuple2<QueryResult, int>>;

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: results.map((x) {
            return Align(
              key: Key('views${widget.index}/${x.item1.id()}'),
              alignment: Alignment.center,
              child: Provider<ArticleListItem>.value(
                value: ArticleListItem.fromArticleListItem(
                  queryResult: x.item1,
                  showDetail: true,
                  addBottomPadding: true,
                  width: (windowWidth - 4.0),
                  thumbnailTag: const Uuid().v4(),
                  viewed: x.item2,
                  usableTabList: results.map((e) => e.item1).toList(),
                  // isCheckMode: checkMode,
                  // isChecked: checked.contains(x.id()),
                ),
                child: const ArticleListItemWidget(),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
