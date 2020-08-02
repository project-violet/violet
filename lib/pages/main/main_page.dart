// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:division/division.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:gradient_widgets/gradient_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/CardScrollWidget.dart';
import 'package:violet/locale/locale.dart';
import 'package:open_file/open_file.dart';
import 'package:violet/version/update_sync.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  bool get wantKeepAlive => true;
  var currentPage = images.length - 1.0;
  var currentPage2 = images.length - 1.0;
  int count = 0;
  bool ee = false;
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    PageController controller = PageController(initialPage: images.length - 1);
    //PageController controller2 = PageController(initialPage: images.length - 1);
    controller.addListener(() {
      setState(() {
        currentPage = controller.page;
        //currentPage2 = controller2.page;
      });
    });
    final double width = MediaQuery.of(context).size.width;

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

class UpdateCard extends StatefulWidget {
  final VoidCallback clickEvent;

  UpdateCard({this.clickEvent});

  @override
  _UpdateCardState createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> with TickerProviderStateMixin {
  bool pressed = false;
  AnimationController rotationController;

  @override
  void initState() {
    rotationController = AnimationController(
      duration: const Duration(milliseconds: 270),
      vsync: this,
      // upperBound: pi * 2,
    );
    super.initState();
    updateCheckAndDownload();
  }

  ReceivePort _port = ReceivePort();

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }

  void updateCheckAndDownload() {
    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      if (UpdateSyncManager.updateRequire) {
        var bb = await Dialogs.yesnoDialog(
            context,
            'New update available! ' +
                UpdateSyncManager.updateMessage +
                ' Would you update?');
        if (bb == null || bb == false) return;
      } else
        return;

      if (!await Permission.storage.isGranted) {
        if (await Permission.storage.request() == PermissionStatus.denied) {
          await Dialogs.okDialog(context,
              'If you do not allow file permissions, you cannot continue :(');
          return;
        }
      }
      var ext = await getExternalStorageDirectory();
      bool once = false;
      IsolateNameServer.registerPortWithName(
          _port.sendPort, 'downloader_send_port');
      _port.listen((dynamic data) {
        String id = data[0];
        DownloadTaskStatus status = data[1];
        int progress = data[2];
        if (progress == 100 && !once) {
          OpenFile.open(
              '${ext.path}/${UpdateSyncManager.updateUrl.split('/').last}');
          once = true;
        }
        setState(() {});
      });

      FlutterDownloader.registerCallback(downloadCallback);
      final taskId = await FlutterDownloader.enqueue(
        url: UpdateSyncManager.updateUrl,
        savedDir: '${ext.path}',
        showNotification:
            true, // show download progress in status bar (for Android)
        openFileFromNotification:
            true, // click on notification to open downloaded file (for Android)
      );
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width - 16,
      height: 75,
      child: PimpedButton(
        particle: MyRectangle2DemoParticle(),
        pimpedWidgetBuilder: (context, controller) {
          return Parent(
              style: settingsItemStyle(pressed),
              gesture: Gestures()
                ..isTap((isTapped) {
                  if (isTapped)
                    rotationController.forward(from: 0.0);
                  else
                    rotationController.reverse(from: 0.7);
                  setState(() => pressed = isTapped);
                  controller.forward(from: 0.0);
                  Future.delayed(Duration(milliseconds: 200),
                      () => controller.forward(from: 0.0));
                  // Future.delayed(Duration(milliseconds: 200),
                  //     () => controller.forward(from: 0.0));
                  // Future.delayed(Duration(milliseconds: 300),
                  //     () => controller.forward(from: 0.0));
                  widget.clickEvent();
                }),
              child: Container(
                decoration: BoxDecoration(
                  // color: Color(0xff00D99E),
                  borderRadius: BorderRadius.circular(8),
                  // gradient: LinearGradient(
                  //   begin: Alignment.bottomLeft,
                  //   end: Alignment(0.8, 0.0),
                  //   colors: [
                  //     Gradients.backToFuture.colors.first.withOpacity(.3),
                  //     Colors.indigo.withOpacity(.3),
                  //     Gradients.backToFuture.colors.last.withOpacity(.3)
                  //   ],
                  //   tileMode: TileMode.clamp,
                  // ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: Offset(0, 15),
                      color:
                          Gradients.backToFuture.colors.first.withOpacity(.3),
                      spreadRadius: -9,
                    ),
                  ],
                ),
                child: GradientCard(
                  gradient: Gradients.aliHussien,
                  // shadowColor: Gradients.backToFuture.colors.last.withOpacity(0.2),
                  // elevation: 8,
                  child: Container(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: RotationTransition(
                              turns: Tween(begin: 0.0, end: 0.7)
                                  .animate(rotationController),
                              child: Icon(
                                MdiIcons.update,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '  Tap Me!',
                              style: TextStyle(
                                  fontFamily: "Calibre-Semibold",
                                  fontSize: 18,
                                  color: Colors.white),
                            ),
                          ),
                        ]
                        // child: Text(
                        //   // 'New Version',
                        //   '',
                        //   style: TextStyle(
                        //     fontSize: 30,
                        //     fontWeight: FontWeight.bold,
                        //     fontFamily: "Calibre-Semibold",
                        //     // letterSpacing: 1.0,
                        //   ),
                        // ),
                        ),
                  ),
                ),
              ));
        },
      ),
    );
  }

  final settingsItemStyle = (pressed) => ParentStyle()
    ..elevation(pressed ? 0 : 10000, color: Colors.transparent)
    ..scale(pressed ? 0.95 : 1.0)
    ..alignmentContent.center()
    // ..height(70)
    // ..margin(vertical: 10)
    // ..borderRadius(all: 15)
    // ..background.hex('#ffffff')
    ..ripple(true)
    ..animate(150, Curves.easeOut);

  final settingsItemIconStyle = (Color color) => ParentStyle()
    ..background.color(color)
    ..margin(left: 15)
    ..padding(all: 12)
    ..borderRadius(all: 30);

  final TxtStyle itemTitleTextStyle = TxtStyle()
    ..bold()
    ..fontSize(16);

  final TxtStyle itemDescriptionTextStyle = TxtStyle()
    ..textColor(Colors.black26)
    ..bold()
    ..fontSize(12);
}

class MyRectangle2DemoParticle extends Particle {
  @override
  void paint(Canvas canvas, Size size, progress, seed) {
    Random random = Random(seed);
    int randomMirrorOffset = random.nextInt(10) + 1;
    CompositeParticle(children: [
      Firework(),
      RectangleMirror.builder(
          numberOfParticles: random.nextInt(6) + 4,
          particleBuilder: (int) {
            return AnimatedPositionedParticle(
              begin: Offset(0.0, -10.0),
              end: Offset(0.0, -60.0),
              child:
                  FadingRect(width: 5.0, height: 15.0, color: intToColor(int)),
            );
          },
          initialDistance: -pi / randomMirrorOffset),
    ]).paint(canvas, size, progress, seed);
  }
}

class DiscordCard extends StatefulWidget {
  @override
  _DiscordCardState createState() => _DiscordCardState();
}

class _DiscordCardState extends State<DiscordCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width - 16,
      height: 65,
      child: Parent(
        style: settingsItemStyle(pressed),
        gesture: Gestures()
          ..isTap((isTapped) {
            setState(() => pressed = isTapped);
          })
          ..onTapUp((detail) async {
            const url = 'https://discord.gg/K8qny6E';
            if (await canLaunch(url)) {
              await launch(url);
            }
          }),
        child: Container(
          width: width - 16,
          height: 65,
          margin: EdgeInsets.symmetric(horizontal: 0.0),
          child: Card(
            color: Color(0xFF7189da),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  MdiIcons.discord,
                  color: Colors.white,
                ),
                Padding(
                  padding: Translations.of(context).dbLanguageCode == 'en'
                      ? EdgeInsets.only(top: 4)
                      : EdgeInsets.only(top: 4),
                  child: Text(
                    '  ${Translations.of(context).trans('maindiscord')}',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontFamily: "Calibre-Semibold",
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final settingsItemStyle = (pressed) => ParentStyle()
    ..elevation(pressed ? 0 : 10000, color: Colors.transparent)
    ..scale(pressed ? 0.95 : 1.0)
    ..alignmentContent.center()
    ..ripple(true)
    ..animate(150, Curves.easeOut);
}

class ContactCard extends StatefulWidget {
  @override
  _ContactCardState createState() => _ContactCardState();
}

class _ContactCardState extends State<ContactCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width - 16,
      height: 65,
      child: Parent(
        style: settingsItemStyle(pressed),
        gesture: Gestures()
          ..isTap((isTapped) {
            setState(() => pressed = isTapped);
          })
          ..onTapUp((detail) async {
            const url =
                'mailto:violet.dev.master@gmail.com?subject=[App Issue] &body=';
            if (await canLaunch(url)) {
              await launch(url);
            }
          }),
        child: Container(
          width: width - 16,
          height: 65,
          margin: EdgeInsets.symmetric(horizontal: 0.0),
          child: Card(
            color: Colors.redAccent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  MdiIcons.gmail,
                  color: Colors.white,
                ),
                Padding(
                  padding: Translations.of(context).dbLanguageCode == 'en'
                      ? EdgeInsets.only(top: 4)
                      : EdgeInsets.only(top: 4),
                  child: Text(
                    '  ${Translations.of(context).trans('maincontact')}',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontFamily: "Calibre-Semibold",
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final settingsItemStyle = (pressed) => ParentStyle()
    ..elevation(pressed ? 0 : 10000, color: Colors.transparent)
    ..scale(pressed ? 0.95 : 1.0)
    ..alignmentContent.center()
    ..ripple(true)
    ..animate(150, Curves.easeOut);
}

class GithubCard extends StatefulWidget {
  @override
  _GithubCardState createState() => _GithubCardState();
}

class _GithubCardState extends State<GithubCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width - 16,
      height: 65,
      child: Parent(
        style: settingsItemStyle(pressed),
        gesture: Gestures()
          ..isTap((isTapped) {
            setState(() => pressed = isTapped);
          })
          ..onTapUp((detail) async {
            const url = 'https://github.com/project-violet/';
            if (await canLaunch(url)) {
              await launch(url);
            }
          }),
        child: Container(
          width: width - 16,
          height: 65,
          margin: EdgeInsets.symmetric(horizontal: 0.0),
          child: Card(
            color: Color(0xFF24292E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  MdiIcons.github,
                  color: Colors.white,
                ),
                Padding(
                  padding: Translations.of(context).dbLanguageCode == 'en'
                      ? EdgeInsets.only(top: 4)
                      : EdgeInsets.only(top: 4),
                  child: Text(
                    '  ${Translations.of(context).trans('maingithub')}',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontFamily: "Calibre-Semibold",
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final settingsItemStyle = (pressed) => ParentStyle()
    ..elevation(pressed ? 0 : 10000, color: Colors.transparent)
    ..scale(pressed ? 0.95 : 1.0)
    ..alignmentContent.center()
    ..ripple(true)
    ..animate(150, Curves.easeOut);
}
