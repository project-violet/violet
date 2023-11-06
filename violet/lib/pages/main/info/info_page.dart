// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/pages/main/faq/faq_page.dart';
import 'package:violet/pages/main/info/lab_page.dart';
import 'package:violet/pages/main/info/user_manual_page.dart';
import 'package:violet/pages/main/info/violet_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Padding(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Container(height: 16),
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
                      return const VioletPage();
                    },
                  );
                },
              ),
              _buildItem(
                const Icon(MdiIcons.bookOpenPageVariant,
                    size: 40, color: Colors.brown),
                // 'User Manual',
                // 'Check out the user manual here!',
                '유저 메뉴얼',
                '여기서 사용법을 확인하세요!',
                const UserManualPage(),
              ),
              _buildItem(
                const Icon(MdiIcons.frequentlyAskedQuestions,
                    size: 40, color: Colors.orange),
                'FAQ',
                // 'Frequently Asked Questions',
                '자주 묻는 질문',
                const FAQPageKorean(),
              ),
              _buildItem(
                const Icon(MdiIcons.routes, size: 40, color: Colors.yellow),
                'Violet WalkRoad',
                '향후 동향과 역사를 살펴보세요!',
                null,
                () async {
                  final url = Uri.parse(
                      'https://www.notion.so/Violet-WalkRoad-1bd9b8bf4bbf48dd81525f2acd19da45');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
              _buildItem(
                const Icon(MdiIcons.flask, size: 40, color: Color(0xFF73BE1E)),
                '실험실',
                '새로운 기능들을 체험해보세요!',
                const LaboratoryPage(),
              ),
              _buildItem(
                const Icon(MdiIcons.gmail, size: 40, color: Colors.redAccent),
                'Gmail',
                // 'Contact the developer',
                '개발자에게 연락해보세요!',
                null,
                () async {
                  final url = Uri(
                    scheme: 'mailto',
                    path: 'violet.dev.master@gmail.com',
                    queryParameters: {
                      'subject': '[App Issue] ',
                    },
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
              _buildItem(
                const Icon(MdiIcons.discord,
                    size: 40, color: Color(0xFF7189da)),
                // 'Discord Channel',
                // 'Communicate with developers',
                '디스코드 채널',
                '개발자와 소통해보세요!',
                null,
                () async {
                  final url = Uri.parse('https://discord.gg/K8qny6E');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
              _buildItem(
                const Icon(MdiIcons.github, size: 40, color: Colors.black),
                // 'GitHub Repository',
                // 'Contribute to the project',
                'GitHub 저장소',
                '프로젝트에 기여해보세요!',
                null,
                () async {
                  final url =
                      Uri.parse('https://github.com/project-violet/violet');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
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
      margin: const EdgeInsets.all(40),
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
            const Padding(
              padding: EdgeInsets.only(top: 12),
            ),
            Text(
              'Project Violet',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 16.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'Copyright (C) 2020-2023 by project-violet',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 12.0,
                fontFamily: 'Calibre-Semibold',
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Settings.themeWhat ? Colors.black26 : Colors.white,
        borderRadius: const BorderRadius.only(
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
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Material(
          color: Settings.themeWhat
              ? Settings.themeBlack
                  ? Palette.blackThemeBackground
                  : Colors.black38
              : Colors.white,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
            leading: image,
            title: Text(title, style: const TextStyle(fontSize: 16.0)),
            subtitle: Text(subtitle),
            onTap: () async {
              if (warp != null) {
                PlatformNavigator.navigateSlide(context, warp);
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
