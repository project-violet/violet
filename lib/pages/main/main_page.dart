// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/pages/main/card/contact_card.dart';
import 'package:violet/pages/main/card/discord_card.dart';
import 'package:violet/pages/main/card/github_card.dart';
import 'package:violet/pages/main/card/update_card.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/version/update_sync.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  bool get wantKeepAlive => true;
  int count = 0;
  bool ee = false;
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    final cardList = [
      DiscordCard(),
      ContactCard(),
      GithubCard(),
    ];

    return Container(
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(4),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Violet',
                        style: TextStyle(
                          fontSize: 46.0,
                          fontFamily: "Calibre-Semibold",
                          letterSpacing: 1.0,
                        )),
                  ],
                ),
              ),
              _versionArea(),
              CarouselSlider(
                options: CarouselOptions(
                  height: 70,
                  aspectRatio: 16 / 9,
                  viewportFraction: 1.0,
                  initialPage: 0,
                  enableInfiniteScroll: false,
                  reverse: false,
                  autoPlay: true,
                  autoPlayInterval: Duration(seconds: 10),
                  autoPlayAnimationDuration: Duration(milliseconds: 800),
                  autoPlayCurve: Curves.fastOutSlowIn,
                  enlargeCenterPage: true,
                  scrollDirection: Axis.horizontal,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _current = index;
                    });
                  },
                ),
                items: cardList.map((card) {
                  return Builder(
                    builder: (BuildContext context) => card,
                  );
                }).toList(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3].map((url) {
                  int index = [1, 2, 3].indexOf(url);
                  return Container(
                    width: 8.0,
                    height: 8.0,
                    margin:
                        EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _current == index
                          ? Settings.themeWhat
                              ? Color.fromRGBO(255, 255, 255, 0.9)
                              : Color.fromRGBO(0, 0, 0, 0.9)
                          : Settings.themeWhat
                              ? Color.fromRGBO(255, 255, 255, 0.4)
                              : Color.fromRGBO(0, 0, 0, 0.4),
                    ),
                  );
                }).toList(),
              ),
              Padding(
                padding: EdgeInsets.all(12),
              ),
              _userArea(),
              UpdateCard(
                clickEvent: () async {
                  count++;
                  await Vibration.vibrate(duration: 50, amplitude: 50);
                  if (count >= 10 && count <= 20 && !ee) {
                    ee = true;
                    Future.delayed(Duration(milliseconds: 7800), () {
                      count = 20;
                      ee = false;
                      setState(() {});
                    });
                  }
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String numberWithComma(int param) {
    return new NumberFormat('###,###,###,###')
        .format(param)
        .replaceAll(' ', '');
  }

  _versionArea() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
                width: 1.6,
                color: Settings.themeWhat ? Colors.white : Colors.black,
                style: BorderStyle.solid)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                        // '${Translations.of(context).trans('mainversion')}:',
                        'Version:',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18)),
                  ),
                  Text(
                      ' ${UpdateSyncManager.majorVersion}.${UpdateSyncManager.minorVersion}.${UpdateSyncManager.patchVersion}',
                      style: TextStyle(
                          fontFamily: "Calibre-Semibold", fontSize: 18))
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                        // '${Translations.of(context).trans('maindb')}:',
                        'Database:',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18)),
                  ),
                  FutureBuilder(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Text(' ??',
                              style: TextStyle(
                                  fontFamily: "Calibre-Semibold",
                                  fontSize: 18));
                        }
                        return Text(
                            ' ' +
                                DateFormat('yyyy-MM-dd').format(DateTime.parse(
                                    snapshot.data.getString('databasesync'))),
                            style: TextStyle(
                                fontFamily: "Calibre-Semibold", fontSize: 18));
                      }),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  _userArea() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
                width: 1.6,
                color: Settings.themeWhat ? Colors.white : Colors.black,
                style: BorderStyle.solid)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                        // '${Translations.of(context).trans('mainread')}:',
                        'Read:',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18)),
                  ),
                  FutureBuilder(future: Future.sync(
                    () async {
                      return await (await User.getInstance()).getUserLog();
                    },
                  ), builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Text(' ??',
                          style: TextStyle(
                              fontFamily: "Calibre-Semibold", fontSize: 18));
                    }
                    return Text(' ' + numberWithComma(snapshot.data.length),
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18));
                  }),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                        // '${Translations.of(context).trans('mainbookmark')}:',
                        'Bookmark:',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18)),
                  ),
                  FutureBuilder(future: Future.sync(
                    () async {
                      return await (await Bookmark.getInstance()).getArticle();
                    },
                  ), builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Text(' ??',
                          style: TextStyle(
                              fontFamily: "Calibre-Semibold", fontSize: 18));
                    }
                    return Text(' ' + numberWithComma(snapshot.data.length),
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18));
                  }),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                        // '${Translations.of(context).trans('maindownload')}:',
                        'Donwload:',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18)),
                  ),
                  FutureBuilder(future: Future.sync(
                    () async {
                      return await (await Download.getInstance())
                          .getDownloadItems();
                    },
                  ), builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Text(' ??',
                          style: TextStyle(
                              fontFamily: "Calibre-Semibold", fontSize: 18));
                    }
                    return Text(' ' + numberWithComma(snapshot.data.length),
                        style: TextStyle(
                            fontFamily: "Calibre-Semibold", fontSize: 18));
                  }),
                ],
              ),
              count > 0
                  ? Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                              // '${Translations.of(context).trans('maindownload')}:',
                              'Tap Count:',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: "Calibre-Semibold",
                                  fontSize: 18)),
                        ),
                        Text(' ' + numberWithComma(count),
                            style: TextStyle(
                                fontFamily: "Calibre-Semibold", fontSize: 18))
                      ],
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}
