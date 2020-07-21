// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale.dart';
import 'package:violet/main.dart';
import 'package:violet/pages/bookmark/bookmark_page.dart';
import 'package:violet/pages/download/download_page.dart';
import 'package:violet/pages/main/main_page.dart';
import 'package:violet/pages/search/search_page.dart';
import 'package:violet/pages/settings/settings_page.dart';
import 'package:violet/settings.dart';

class AfterLoadingPage extends StatefulWidget {
  @override
  _AfterLoadingPageState createState() => new _AfterLoadingPageState();
}

class _AfterLoadingPageState extends State<AfterLoadingPage>
    with WidgetsBindingObserver {
  int _page = 0;
  PageController _c;
  bool isBlurred = false;

  @override
  void initState() {
    _c = new PageController(
      initialPage: _page,
    );
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    setState(() {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive)
        isBlurred = true;
      else
        isBlurred = false;
    });
  }

  @override
  void disposed() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: scaffoldKey,
      bottomNavigationBar: BottomNavigationBar(
        elevation: 9,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.shifting,
        fixedColor: Settings.majorColor,
        unselectedItemColor:
            Settings.themeWhat ? Colors.white : Colors.black, //Colors.black,
        currentIndex: _page,
        onTap: (index) {
          this._c.animateToPage(index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut);
        },
        items: <BottomNavigationBarItem>[
          new BottomNavigationBarItem(
              backgroundColor: Settings.themeWhat
                  ? Colors.grey.shade900.withOpacity(0.90)
                  : Colors.grey.shade50,
              icon: new Icon(MdiIcons.home),
              title: new Text(Translations.of(context).trans('main'))),
          new BottomNavigationBarItem(
              backgroundColor: Settings.themeWhat
                  ? Colors.grey.shade900.withOpacity(0.90)
                  : Colors.grey.shade50,
              icon: new Icon(Icons.search),
              title: new Text(Translations.of(context).trans('search'))),
          // new BottomNavigationBarItem(
          //     icon: new Icon(MdiIcons.accountGroup),
          //     title: new Text(Translations.of(context).trans('community'))),
          new BottomNavigationBarItem(
              backgroundColor: Settings.themeWhat
                  ? Colors.grey.shade900.withOpacity(0.90)
                  : Colors.grey.shade50,
              icon: new Icon(Icons.bookmark),
              title: new Text(Translations.of(context).trans('bookmark'))),
          new BottomNavigationBarItem(
              icon: new Icon(Icons.file_download),
              title: new Text(Translations.of(context).trans('download'))),
          new BottomNavigationBarItem(
              backgroundColor: Settings.themeWhat
                  ? Colors.grey.shade900.withOpacity(0.90)
                  : Colors.grey.shade50,
              icon: new Icon(Icons.settings),
              title: new Text(Translations.of(context).trans('settings'))),
        ],
      ),
      body: new PageView(
        controller: _c,
        onPageChanged: (newPage) {
          setState(() {
            this._page = newPage;
          });
        },
        children: <Widget>[
          MainPage(),
          // new Center(
          //   child: new Column(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       ShaderMask(
          //         shaderCallback: (rect) {
          //           return LinearGradient(
          //             begin: Alignment.topCenter,
          //             end: Alignment.bottomCenter,
          //             colors: [
          //               Colors.transparent,
          //               Colors.black,
          //               Colors.transparent
          //             ],
          //           ).createShader(
          //               Rect.fromLTRB(0, 0, rect.width, rect.height));
          //         },
          //         blendMode: BlendMode.dstIn,
          //         child: FadeInImage(
          //           width: double.infinity,
          //           height: 200,
          //           image: NetworkImage(""),
          //           fit: BoxFit.cover,
          //           placeholder: AssetImage('assets/images/loading.gif'),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          SearchPage(),
          // new Center(
          //   child: Padding(
          //     padding: EdgeInsets.all(128),
          //     child: ShaderMask(
          //       shaderCallback: (bounds) => RadialGradient(
          //         center: Alignment.centerLeft,
          //         radius: 1,
          //         colors: [Colors.yellow, Colors.red, Colors.purple],
          //         tileMode: TileMode.clamp,
          //       ).createShader(bounds),
          //       child: FlareActor(
          //         "assets/flare/SlidinSquaresLoader.flr",
          //         animation: "SlideThem",
          //         // 'assets/flare/Trim.flr',
          //         // animation: "Untitled",
          //         alignment: Alignment.center,
          //         color: Colors.white,
          //         fit: BoxFit.contain,
          //         isPaused: false,
          //         snapToEnd: true,
          //       ),
          //     ),
          //   ),
          // ),
          // new Center(
          //   child: new Column(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: <Widget>[new Icon(Icons.mail), new Text("Inbox")],
          //   ),
          // ),
          // new Center(
          //   child: Padding(
          //     padding: EdgeInsets.all(64),
          //     child: Column(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: <Widget>[
          //         CachedNetworkImage(
          //           imageUrl:
          //               "https://www.amazing-animations.com/animations/construction5.gif",
          //         ),
          //         Container(
          //           padding: EdgeInsets.all(4),
          //         ),
          //         Text('공사중!'),
          //       ],
          //     ),
          //   ),
          // ),

          BookmarkPage(),
          DownloadPage(),
          // new Center(
          //   child: Padding(
          //     padding: EdgeInsets.all(64),
          //     child: ShaderMask(
          //       shaderCallback: (bounds) => RadialGradient(
          //         center: Alignment.bottomLeft,
          //         radius: 2,
          //         colors: [Colors.yellow, Colors.red, Colors.purple],
          //         tileMode: TileMode.clamp,
          //       ).createShader(bounds),
          //       child: FlareActor(
          //         'assets/flare/Trim.flr',
          //         animation: "Untitled",
          //         alignment: Alignment.center,
          //         color: Colors.white,
          //         fit: BoxFit.cover,
          //         isPaused: false,
          //         snapToEnd: true,
          //       ),
          //     ),
          //   ),
          // ),
          SettingsPage(),
          // new Center(
          //   child: new Column(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: <Widget>[new Icon(Icons.mail), new Text("Inbox")],
          //   ),
          // ),
        ],
      ),
      // ),
    );
  }
}

// https://stackoverflow.com/a/50074067/3355656
class OnePage extends StatefulWidget {
  final Color color;

  const OnePage({Key key, this.color}) : super(key: key);

  @override
  _OnePageState createState() => new _OnePageState();
}

class _OnePageState extends State<OnePage>
    with AutomaticKeepAliveClientMixin<OnePage> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return new SizedBox.expand(
      child: new ListView.builder(
        itemCount: 100,
        itemBuilder: (context, index) {
          return new Padding(
            padding: const EdgeInsets.all(10.0),
            child: new Text(
              '$index',
              style: new TextStyle(color: widget.color),
            ),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
