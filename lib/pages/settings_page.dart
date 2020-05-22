import 'package:flutter/material.dart';

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
                        'Copyright (C) 2020 by dc-koromo',
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
      transform: Matrix4.translationValues(0, -4, 0),
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
