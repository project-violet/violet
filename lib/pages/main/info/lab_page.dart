// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/component/hitomi/ldi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/pages/artist_info/article_list_page.dart';
import 'package:violet/pages/main/info/user_manual_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/settings/settings.dart';

class LaboratoryPage extends StatefulWidget {
  @override
  _LaboratoryPageState createState() => _LaboratoryPageState();
}

class _LaboratoryPageState extends State<LaboratoryPage> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Padding(
        padding: EdgeInsets.only(top: 16),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            children: [
              // Container(height: 40),
              _buildTitle(),
              // Container(height: 30),
              _buildItem(
                Icon(MdiIcons.meteor, size: 40, color: Colors.brown),
                // 'User Manual',
                // 'Check out the user manual here!',
                '#001 Articles',
                'Likes and Dislikes Index (LDI) DESC',
                //ArticleListPage(name: "LDI DESC", ),
                null,
                () async {
                  if (LDI.ldi == null) await LDI.init();

                  var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
                  queryRaw += 'Id IN (' +
                      LDI.ldi.map((e) => e.item1).take(1500).join(',') +
                      ')';
                  var qm = await QueryManager.query(
                      queryRaw + ' AND ExistOnHitomi=1');

                  await navigate(
                      ArticleListPage(name: "LDI DESC", cc: qm.results));
                },
              ),
              _buildItem(
                Icon(MdiIcons.meteor, size: 40, color: Colors.brown),
                // 'User Manual',
                // 'Check out the user manual here!',
                '#002 Articles',
                'Likes and Dislikes Index (LDI) ASC',
                null,
                () async {
                  if (LDI.ldi == null) await LDI.init();

                  var queryRaw = 'SELECT * FROM HitomiColumnModel WHERE ';
                  queryRaw += 'Id IN (' +
                      LDI.ldi.reversed
                          .map((e) => e.item1)
                          .take(1500)
                          .join(',') +
                      ')';
                  var qm = await QueryManager.query(
                      queryRaw + ' AND ExistOnHitomi=1');

                  await navigate(
                      ArticleListPage(name: "LDI ASC", cc: qm.results));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  _buildTitle() {
    return Container(
      margin: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: <Widget>[
            Icon(MdiIcons.flask, size: 100, color: Color(0xFF73BE1E)),
            Padding(
              padding: EdgeInsets.only(top: 12),
            ),
            Text(
              'Violet Laboratory',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 16.0,
                fontFamily: "Calibre-Semibold",
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _buildItem(image, title, subtitle, [warp, run]) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Settings.themeWhat ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: Settings.themeWhat
                ? Colors.black26
                : Colors.grey.withOpacity(0.1),
            spreadRadius: Settings.themeWhat ? 0 : 5,
            blurRadius: 7,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Material(
          color: Settings.themeWhat ? Colors.black38 : Colors.white,
          child: ListTile(
            contentPadding:
                EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
            leading: image,
            title: Text(title, style: TextStyle(fontSize: 16.0)),
            subtitle: Text(subtitle),
            onTap: () async {
              if (warp != null) {
                await navigate(warp);
              } else {
                await run();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> navigate(Widget page) async {
    if (!Platform.isIOS) {
      Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.ease;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        pageBuilder: (_, __, ___) => page,
      ));
    } else {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
    }
  }
}
