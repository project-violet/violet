// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:developer';
import 'package:violet/locale.dart';
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

class _AfterLoadingPageState extends State<AfterLoadingPage> {
  int _page = 0;
  PageController _c;
  @override
  void initState() {
    _c = new PageController(
      initialPage: _page,
    );
    super.initState();
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

    return new Scaffold(
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
        type: BottomNavigationBarType.shifting,
        //  backgroundColor: Colors.black,
        fixedColor: Settings.majorColor,
        unselectedItemColor: Colors.black,
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
              icon: new Icon(Icons.personal_video),
              title: new Text(Translations.of(context).trans('main'))),
          new BottomNavigationBarItem(
              icon: new Icon(Icons.search),
              title: new Text(Translations.of(context).trans('search'))),
          new BottomNavigationBarItem(
              icon: new Icon(Icons.file_download),
              title: new Text(Translations.of(context).trans('download'))),
          new BottomNavigationBarItem(
              icon: new Icon(Icons.bookmark),
              title: new Text(Translations.of(context).trans('bookmark'))),
          new BottomNavigationBarItem(
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
          new Center(
            child: Padding(
              padding: EdgeInsets.all(128),
              child: ShaderMask(
                shaderCallback: (bounds) => RadialGradient(
                  center: Alignment.centerLeft,
                  radius: 1,
                  colors: [Colors.yellow, Colors.red, Colors.purple],
                  tileMode: TileMode.clamp,
                ).createShader(bounds),
                child: FlareActor(
                  "assets/flare/SlidinSquaresLoader.flr",
                  animation: "SlideThem",
                  // 'assets/flare/Trim.flr',
                  // animation: "Untitled",
                  alignment: Alignment.center,
                  color: Colors.white,
                  fit: BoxFit.contain,
                  isPaused: false,
                  snapToEnd: true,
                ),
              ),
            ),
            // child: new Column(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   //children: <Widget>[new Icon(Icons.mail), new Text("Inbox")],
            //   //children: <Widget>[
            //   //  FlareActor(
            //   //    "assets/flare/check_profile.flr2d",
            //   //    //animation: "On",
            //   //  )
            //   //],
            //   Positioned.fill()
            // ),
          ),
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
    );
  }
}
