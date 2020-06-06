// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/pages/test_page.dart';
import 'package:url_launcher/url_launcher.dart';

// https://www.youtube.com/watch?v=gzfJaDt9ok8
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _build_group('시스템'),
              _build_items([
                ListTile(
                  leading: Icon(Icons.folder_open, color: Colors.purple),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("저장 위치 설정"),
                      Text("현재 위치: /android/Pictures"),
                    ],
                  ),
                  trailing: Icon(Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
                _build_divider(),
                ListTile(
                  leading: Icon(Icons.receipt, color: Colors.purple),
                  title: Text("로그 기록"),
                  trailing: Icon(Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
                _build_divider(),
                ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.purple),
                  title: Text("정보"),
                  trailing: Icon(Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
                _build_divider(),
                ListTile(
                  leading: Icon(Icons.developer_mode, color: Colors.orange),
                  title: Text("개발자 도구"),
                  trailing: Icon(Icons.keyboard_arrow_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => TestPage(),
                      ),
                    );
                  },
                ),
              ]),
              _build_group('뷰어'),
              _build_items([
                ListTile(
                  leading: Icon(Icons.view_array, color: Colors.purple),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("뷰어 타입"),
                      Text("현재 타입: 스크롤 뷰"),
                    ],
                  ),
                  trailing: Icon(Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
              ]),
              _build_group('캐시'),
              _build_items([
                ListTile(
                  leading: Icon(Icons.lock_outline, color: Colors.purple),
                  title: Text("Enable Locking"),
                  trailing: AbsorbPointer(
                    child: Switch(
                      value: true,
                      onChanged: (value) {
                        //setState(() {
                        //  isSwitched = value;
                        //  print(isSwitched);
                        //});
                      },
                      activeTrackColor: Colors.purple,
                      activeColor: Colors.purpleAccent,
                    ),
                  ),
                  //Icon(Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
              ]),
              _build_group('잠금'),
              _build_items([
                ListTile(
                  leading: Icon(Icons.lock_outline, color: Colors.purple),
                  title: Text("잠금 기능 켜기"),
                  trailing: AbsorbPointer(
                    child: Switch(
                      value: true,
                      onChanged: (value) {
                        //setState(() {
                        //  isSwitched = value;
                        //  print(isSwitched);
                        //});
                      },
                      activeTrackColor: Colors.purple,
                      activeColor: Colors.purpleAccent,
                    ),
                  ),
                  //Icon(Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
              ]),
              _build_group('네트워크'),
              _build_items([
                ListTile(
                  leading: Icon(
                    Icons.router,
                    color: Colors.purple,
                  ),
                  title: Text("라우팅 규칙"),
                  trailing: Icon(
                      // Icons.message,
                      Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
              ]),
              _build_group('기타'),
              _build_items([
                ListTile(
                  leading: Icon(
                    MdiIcons.discord,
                    color: Color(0xFF7189da),
                  ),
                  title: Text("디스코드 채널"),
                  trailing: Icon(
                      // Icons.message,
                      Icons.keyboard_arrow_right),
                  onTap: () async {
                    const url = 'https://discord.gg/K8qny6E';
                    if (await canLaunch(url)) {
                      await launch(url);
                    }
                  },
                ),
                _build_divider(),
                ListTile(
                  leading: Icon(
                    MdiIcons.gmail,
                    color: Colors.redAccent,
                  ),
                  title: Text("개발자 문의"),
                  trailing: Icon(
                      // Icons.email,
                      Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
                _build_divider(),
                ListTile(
                  leading: Icon(
                    MdiIcons.heart,
                    color: Colors.orange,
                  ),
                  title: Text("후원"),
                  trailing: Icon(
                      // Icons.email,
                      Icons.keyboard_arrow_right),
                  onTap: () {},
                ),
                _build_divider(),
                ListTile(
                  leading: Icon(
                    Icons.open_in_new,
                    color: Colors.purple,
                  ),
                  title: Text("외부 링크"),
                  trailing: Icon(
                      // Icons.email,
                      Icons.keyboard_arrow_right),
                  onTap: () {},
                ), 
              ]),
              Container(
                margin: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: <Widget>[
                      // Card(
                      //   elevation: 5,
                      //   shape: RoundedRectangleBorder(
                      //     borderRadius: BorderRadius.circular(10.0),
                      //   ),
                      //   child:
                      InkWell(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                        ),
                        //onTap: () {},
                      ),
                      // ),
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                      ),
                      Text(
                        'Project Violet',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16.0,
                          fontFamily: "Calibre-Semibold",
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Copyright (C) 2020 by NViolet',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12.0,
                          fontFamily: "Calibre-Semibold",
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Container _build_divider() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 8.0,
      ),
      width: double.infinity,
      height: 1.0,
      color: Colors.grey.shade400,
    );
  }

  Padding _build_group(String name) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(name,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 24.0,
                fontFamily: "Calibre-Semibold",
                letterSpacing: 1.0,
              )),
        ],
      ),
    );
  }

  Container _build_items(List<Widget> items) {
    return Container(
      transform: Matrix4.translationValues(0, -2, 0),
      child: Card(
        elevation: 4.0,
        margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Column(children: items),
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  final String name;
  //final List<SettingsItem> items;

  SettingsGroup({this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(name,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24.0,
                      fontFamily: "Calibre-Semibold",
                      letterSpacing: 1.0,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsItem extends StatefulWidget {
  @override
  _SettingsItemState createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
