// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/pages/main/faq/faq_page.dart';
import 'package:violet/pages/main/info/user_manual_page.dart';
import 'package:violet/pages/main/info/violet_page.dart';
import 'package:violet/settings/settings.dart';

class InfoPage extends StatefulWidget {
  @override
  _InfoPageState createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;

    final mediaQuery = MediaQuery.of(context);

    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
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
                height: height -
                    16 -
                    (mediaQuery.padding + mediaQuery.viewInsets).bottom,
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
                          Image.asset(
                            'assets/images/logo.png',
                            width: 45,
                            height: 45,
                          ),
                          // 'Violet History',
                          // 'What is violet?',
                          'Violet이란?',
                          'Violet은 무엇인가요?',
                          null,
                          () async {
                            await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return VioletPage();
                              },
                            );
                          },
                        ),
                        _buildItem(
                          Icon(MdiIcons.bookOpenPageVariant,
                              size: 40, color: Colors.brown),
                          // 'User Manual',
                          // 'Check out the user manual here!',
                          '유저 메뉴얼',
                          '여기서 사용법을 확인하세요!',
                          UserManualPage(),
                        ),
                        _buildItem(
                          Icon(MdiIcons.frequentlyAskedQuestions,
                              size: 40, color: Colors.orange),
                          'FAQ',
                          // 'Frequently Asked Questions',
                          '자주 묻는 질문',
                          FAQPageKorean(),
                        ),
                        _buildItem(
                          Icon(MdiIcons.routes, size: 40, color: Colors.yellow),
                          'Violet WalkRoad',
                          '향후 동향과 역사를 살펴보세요!',
                          null,
                          () async {
                            const url =
                                'https://www.notion.so/Violet-WalkRoad-1bd9b8bf4bbf48dd81525f2acd19da45';
                            if (await canLaunch(url)) {
                              await launch(url);
                            }
                          },
                        ),
                        _buildItem(
                          Icon(MdiIcons.gmail,
                              size: 40, color: Colors.redAccent),
                          'Gmail',
                          // 'Contact the developer',
                          '개발자에게 연락해보세요!',
                          null,
                          () async {
                            const url =
                                'mailto:violet.dev.master@gmail.com?subject=[App Issue] &body=';
                            if (await canLaunch(url)) {
                              await launch(url);
                            }
                          },
                        ),
                        _buildItem(
                          Icon(MdiIcons.discord,
                              size: 40, color: Color(0xFF7189da)),
                          // 'Discord Channel',
                          // 'Communicate with developers',
                          '디스코드 채널',
                          '개발자와 소통해보세요!',
                          null,
                          () async {
                            const url = 'https://discord.gg/K8qny6E';
                            if (await canLaunch(url)) {
                              await launch(url);
                            }
                          },
                        ),
                        _buildItem(
                          Icon(MdiIcons.github, size: 40, color: Colors.black),
                          // 'GitHub Repository',
                          // 'Contribute to the project',
                          'GitHub 저장소',
                          '프로젝트에 기여해보세요!',
                          null,
                          () async {
                            const url =
                                'https://github.com/project-violet/violet';
                            if (await canLaunch(url)) {
                              await launch(url);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
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
            InkWell(
              child: Image.asset(
                'assets/images/logo.png',
                width: 100,
                height: 100,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 12),
            ),
            Text(
              'Project Violet',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 16.0,
                fontFamily: "Calibre-Semibold",
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'Copyright (C) 2020-2021 by project-violet',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 12.0,
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
                if (!Platform.isIOS) {
                  Navigator.of(context).push(PageRouteBuilder(
                    transitionDuration: Duration(milliseconds: 500),
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
                    pageBuilder: (_, __, ___) => warp,
                  ));
                } else {
                  Navigator.of(context)
                      .push(CupertinoPageRoute(builder: (_) => warp));
                }
              } else {
                await run();
              }
            },
          ),
        ),
      ),
    );
  }
}
