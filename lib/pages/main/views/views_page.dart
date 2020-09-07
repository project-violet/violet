// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:bubble_tab_indicator/bubble_tab_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/component/hitomi/artists.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/main/artist_collection/artist_list_page.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';

class ViewsPage extends StatefulWidget {
  @override
  _ViewsPageState createState() => _ViewsPageState();
}

class _ViewsPageState extends State<ViewsPage> with TickerProviderStateMixin {
  TabController _tabController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Card(
              elevation: 5,
              color:
                  Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
              child: SizedBox(
                width: width - 16,
                height: height - 16,
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: <Widget>[
                      TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: new BubbleTabIndicator(
                          indicatorHeight: 40.0,
                          indicatorColor: Settings.majorColor,
                          tabBarIndicatorSize: TabBarIndicatorSize.tab,
                          insets: EdgeInsets.only(left: 8, right: 8, top: 21),
                        ),
                        // controller: _tabController,
                        tabs: [
                          Container(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Container(height: 4),
                                Icon(Icons.star,
                                    color: Settings.themeWhat
                                        ? null
                                        : Colors.black),
                                Text('Today',
                                    style: Settings.themeWhat
                                        ? null
                                        : TextStyle(color: Colors.black)),
                              ],
                            ),
                            height: 50,
                          ),
                          Container(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Container(height: 4),
                                Icon(MdiIcons.calendarWeek,
                                    color: Settings.themeWhat
                                        ? null
                                        : Colors.black),
                                Text('Weekly',
                                    style: Settings.themeWhat
                                        ? null
                                        : TextStyle(color: Colors.black)),
                              ],
                            ),
                            height: 50,
                          ),
                          Container(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Container(height: 4),
                                Icon(MdiIcons.calendarMonth,
                                    color: Settings.themeWhat
                                        ? null
                                        : Colors.black),
                                Text('Monthly',
                                    style: Settings.themeWhat
                                        ? null
                                        : TextStyle(color: Colors.black)),
                              ],
                            ),
                            height: 50,
                          ),
                          Container(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Container(height: 4),
                                Icon(MdiIcons.heart,
                                    color: Settings.themeWhat
                                        ? null
                                        : Colors.black),
                                Text('All Time',
                                    style: Settings.themeWhat
                                        ? null
                                        : TextStyle(color: Colors.black)),
                              ],
                            ),
                            height: 50,
                          ),
                        ],
                      ),
                      Expanded(
                        child: new TabBarView(
                          // controller: _tabController,
                          children: [
                            _tab(0),
                            _tab(1),
                            _tab(2),
                            _tab(3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _tab(index) {
    return FutureBuilder(
      future: VioletServer.top(
          0, 100, ['daily', 'week', 'month', 'alltime'][index]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(
                  '${index + 1}. ' + snapshot.data[index].item1.toString()),
              subtitle: Text(snapshot.data[index].item2.toString()),
            );
          },
        );
      },
    );
  }
}
