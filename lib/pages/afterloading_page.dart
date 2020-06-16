// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:developer';
import 'package:violet/locale.dart';
import 'package:violet/main.dart';
import 'package:violet/pages/bookmark_page.dart';
import 'package:violet/pages/database_download_page.dart';
import 'package:violet/pages/loading_page.dart';
import 'package:violet/pages/main_page.dart';
import 'package:violet/pages/search_page.dart';
import 'package:violet/pages/settings_page.dart';
import 'package:violet/pages/splash_page.dart';
import 'package:violet/settings.dart';
import 'package:violet/widgets/CardScrollWidget.dart';

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
    // await new Future.delayed(const Duration(seconds: 3));
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

  // var currentPage = images.length - 1.0;

  @override
  Widget build(BuildContext context) {
    // PageController controller = PageController(initialPage: images.length - 1);
    // controller.addListener(() {
    //   setState(() {
    //     currentPage = controller.page;
    //   });
    // });

    return
        // AnnotatedRegion<SystemUiOverlayStyle>(
        //   value: SystemUiOverlayStyle(
        //     statusBarColor: Colors.transparent,
        //   ),
        //   child:
        new Scaffold(
      key: scaffoldKey,
      bottomNavigationBar: //new Theme(
          // data: Theme.of(context).copyWith(
          //     // sets the background color of the `BottomNavigationBar`
          //     canvasColor: Colors.purple,
          //     // sets the active color of the `BottomNavigationBar` if `Brightness` is light
          //     primaryColor: Colors.red,

          //     textTheme: Theme.of(context)
          //         .textTheme
          //         .copyWith(caption: new TextStyle(color: Colors.yellow))),
          //child:
          BottomNavigationBar(
            elevation: 9,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.shifting,
        //  backgroundColor: Colors.black,
        fixedColor: Settings.majorColor,
        unselectedItemColor:
            Settings.themeWhat ? Colors.white : Colors.black, //Colors.black,
            // backgroundColor: Colors.transparent,
        //backgroundColor: Color(0x4FB200ED),
        //backgroundColor: Color(0x4FB200ED),
        // selectedItemColor: Colors.black,

        currentIndex: _page,
        onTap: (index) {
          this._c.animateToPage(index,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut);
        },
        items: <BottomNavigationBarItem>[
          new BottomNavigationBarItem(
             backgroundColor: Settings.themeWhat ? Colors.grey.shade900.withOpacity(0.90) : Colors.grey.shade50,
              icon: new Icon(MdiIcons.home),
              title: new Text(Translations.of(context).trans('main'))),
          new BottomNavigationBarItem(
             backgroundColor: Settings.themeWhat ? Colors.grey.shade900.withOpacity(0.90) : Colors.grey.shade50,
              icon: new Icon(Icons.search),
              title: new Text(Translations.of(context).trans('search'))),
          // new BottomNavigationBarItem(
          //     icon: new Icon(Icons.file_download),
          //     title: new Text(Translations.of(context).trans('download'))),
          new BottomNavigationBarItem(
            //  backgroundColor: Colors.grey.shade900.withOpacity(0.90),
             backgroundColor: Settings.themeWhat ? Colors.grey.shade900.withOpacity(0.90) : Colors.grey.shade50,
              icon: new Icon(Icons.bookmark),
              title: new Text(Translations.of(context).trans('bookmark'))),
          new BottomNavigationBarItem(
            //  backgroundColor: Colors.grey.shade900.withOpacity(0.90),
             backgroundColor: Settings.themeWhat ? Colors.grey.shade900.withOpacity(0.90) : Colors.grey.shade50,
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
          new Center(
            child: Padding(
              padding: EdgeInsets.all(64),
              child: ShaderMask(
                shaderCallback: (bounds) => RadialGradient(
                  center: Alignment.bottomLeft,
                  radius: 2,
                  colors: [Colors.yellow, Colors.red, Colors.purple],
                  tileMode: TileMode.clamp,
                ).createShader(bounds),
                child: FlareActor(
                  'assets/flare/Trim.flr',
                  animation: "Untitled",
                  alignment: Alignment.center,
                  color: Colors.white,
                  fit: BoxFit.cover,
                  isPaused: false,
                  snapToEnd: true,
                ),
              ),
            ),
          ),
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
