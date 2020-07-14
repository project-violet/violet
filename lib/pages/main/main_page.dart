// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:division/division.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:gradient_widgets/gradient_widgets.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:violet/dialogs.dart';
import 'package:violet/main.dart';
import 'package:violet/server/ws.dart';
import 'package:violet/settings.dart';
import 'package:violet/widgets/CardScrollWidget.dart';
import 'package:violet/locale.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:open_file/open_file.dart';
import 'package:violet/update_sync.dart';

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

    return
        // Stack(
        //   children: <Widget>[
        // Visibility(
        //     visible: count >= 10,
        //     child: Draggable(
        //         feedback: Lottie.asset('assets/lottie/26438-drone-flight.json'),
        //         child: Lottie.asset('assets/lottie/26438-drone-flight.json'))),
        Container(
      //color: Color(0x2FB200ED),
      //decoration:
      // BoxDecoration(
      //   boxShadow: [
      //     // const BoxShadow(
      //     //   color: Color(0x2FB200ED),
      //     //   //color: Colors.black,
      //     // ),
      //     const BoxShadow(
      //       //color: Colors.black,
      //       color: Color(0x2FB200ED),
      //       //offset: Offset(0,10),
      //       spreadRadius: -12.0,
      //       blurRadius: 12.0,
      //     ),
      //   ],
      //   color: Color(0x2FB200ED),
      // ),
      // ShapeDecoration(
      //   color: Color(0x2FB200EB),
      //   shape: Border(bottom: BorderSide(width: 4)),
      //   // shadows: [
      //   //   const BoxShadow(
      //   //     color: Colors.purple
      //   //   ),
      //   // ],
      // ),
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(80),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Notice', //Translations.of(context).trans('notice'),
                        style: TextStyle(
                          fontSize: 46.0,
                          fontFamily: "Calibre-Semibold",
                          letterSpacing: 1.0,
                        )),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12),
              ),
              // Text(
              //   Translations.of(context).trans('notice1'),
              // ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: Translations.of(context).trans('notice21'),
                      style: TextStyle(
                          color:
                              Settings.themeWhat ? Colors.white : Colors.black),
                    ),
                    TextSpan(
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                        decoration: TextDecoration.underline,
                      ),
                      text: 'violet.dev.master@gmail.com',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          final url = 'mailto:violet.dev.master@gmail.com';
                          if (await canLaunch(url)) {
                            await launch(
                              url,
                              forceSafariVC: false,
                            );
                          }
                        },
                    ),
                    TextSpan(
                      text: Translations.of(context).trans('notice22'),
                      style: TextStyle(
                          color:
                              Settings.themeWhat ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              ),
              // Text(Translations.of(context).trans('notice3')),
              Text(''),
              Text(Translations.of(context).trans('notice4')),
              Text(Translations.of(context).trans('notice5')),
              Text(''),
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

              Visibility(
                visible: count >= 10 && ee,
                child: Stack(children: <Widget>[
                  // Lottie.asset('assets/lottie/26438-drone-flight.json'),
                  Lottie.network(
                      'https://raw.githubusercontent.com/xvrh/lottie-flutter/master/example/assets/lottiefiles/fabulous_onboarding_animation.json')
                ]),
              ),
              Visibility(
                visible: count >= 20 && !ee,
                child: Stack(children: <Widget>[
                  // Lottie.asset('assets/lottie/26438-drone-flight.json'),
                  Lottie.asset(
                      'assets/lottie/24208-menhera-chan-at-cocopry-sticker-10.json')
                ]),
              ),

              // Container(
              //   width: 88,
              //   height: 30,
              //   decoration: BoxDecoration(
              //       color: Color(0xff00D99E),
              //       borderRadius: BorderRadius.circular(15),
              //       boxShadow: [
              //         BoxShadow(
              //             blurRadius: 8,
              //             offset: Offset(0, 15),
              //             color: Color(0xff00D99E).withOpacity(.6),
              //             spreadRadius: -9)
              //       ]),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: <Widget>[
              //       Icon(
              //         Icons.shopping_cart,
              //         size: 12,
              //       ),
              //       SizedBox(width: 6),
              //       Text("CART",
              //           style: TextStyle(
              //             fontSize: 10,
              //             color: Colors.white,
              //             letterSpacing: 1,
              //           ))
              //     ],
              //   ),
              // ),
              // Container(
              //   child: GradientCard(
              //     gradient: Gradients.backToFuture,
              //     shadowColor:
              //         Gradients.backToFuture.colors.last.withOpacity(0.25),
              //     elevation: 32,
              //     child: Container(
              //       width: width - 30,
              //       height: 150,
              //     ),
              //   ),
              // decoration: BoxDecoration(
              //   // color: Colors.green,
              //   borderRadius: BorderRadius.only(
              //       topLeft: Radius.circular(10),
              //       topRight: Radius.circular(10),
              //       bottomLeft: Radius.circular(10),
              //       bottomRight: Radius.circular(10)),
              //   boxShadow: [
              //     BoxShadow(
              //       color: Colors.orange.withOpacity(0.5),
              //       spreadRadius: 5,
              //       blurRadius: 17,
              //       offset: Offset(0, 3), // changes position of shadow
              //     ),
              //   ],
              // ),
              // ),
              // Container(
              //   // margin:
              //   //     EdgeInsets.only(left: 30, top: 100, right: 30, bottom: 50),
              //   height: 50,
              //   width: 200,
              //   decoration: BoxDecoration(
              //     color: Colors.green,
              //     borderRadius: BorderRadius.only(
              //         topLeft: Radius.circular(10),
              //         topRight: Radius.circular(10),
              //         bottomLeft: Radius.circular(10),
              //         bottomRight: Radius.circular(10)),
              //     boxShadow: [
              //       BoxShadow(
              //         color: Colors.green.withOpacity(0.5),
              //         spreadRadius: 5,
              //         blurRadius: 7,
              //         offset: Offset(0, 3), // changes position of shadow
              //       ),
              //     ],
              //   ),
              // ),
              // Text('Copyright (C) 2020. dc-koromo. All rights reserved.'),
              // Padding(
              //   padding: EdgeInsets.all(10),
              // ),
              // Text('Violet 0.3'),
              // Text(
              //   'Thanks to Flutter developers.',
              //   style: TextStyle(fontStyle: FontStyle.italic),
              // ),
              // Padding(
              //   padding: EdgeInsets.all(100),
              // ),
              // Padding(
              //   padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: <Widget>[
              //       Text(Translations.of(context).trans('news'),
              //           style: TextStyle(
              //             fontSize: 46.0,
              //             fontFamily: "Calibre-Semibold",
              //             letterSpacing: 1.0,
              //           )),
              //     ],
              //   ),
              // ),
              // Container(
              //   transform: Matrix4.translationValues(0, 0, 0),
              //   child: Stack(
              //     children: <Widget>[
              //       CardScrollWidget(currentPage),
              //       Positioned.fill(
              //         child: PageView.builder(
              //           itemCount: images.length,
              //           controller: controller,
              //           reverse: true,
              //           itemBuilder: (context, index) {
              //             return Container();
              //           },
              //         ),
              //       )
              //     ],
              //   ),
              // ),
              // Stack(
              //   children: <Widget>[
              //     CardScrollWidget(currentPage2),
              //     Positioned.fill(
              //      child: PageView.builder(
              //        itemCount: images.length,
              //        controller: controller2,
              //        reverse: true,
              //        itemBuilder: (context, index) {
              //          return Container();
              //        },
              //      ),
              //     )
              //   ],
              // ),
              // Padding(
              //   padding: const EdgeInsets.symmetric(vertical: 24.0),
              //   child: Text(
              //       '${Translations.of(context).trans('numcunuser')}$userConnectionCount'),
              // )
              // StreamBuilder(
              //   stream: channel.stream,
              //   builder: (context, snapshot) {
              //     print(snapshot.data.toString().split(' ')[1]);
              //     return Padding(
              //       padding: const EdgeInsets.symmetric(vertical: 24.0),
              //       child: Text(snapshot.hasData
              //           ? '${Translations.of(context).trans('numcunuser')}${snapshot.data.toString().split(' ')[1]}'
              //           : ''),
              //     );
              //   },
              // )
            ],
          ),
        ),
      ),
      // ),
      // ],
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
        var bb = await Dialogs.yesnoDialog(context,
            '새로운 업데이트가 있습니다. ' + UpdateSyncManager.updateMessage + ' 다운로드할까요?');
        if (bb == null || bb == false) return;
      } else
        return;

      if (!await Permission.storage.isGranted) {
        if (await Permission.storage.request() == PermissionStatus.denied) {
          await Dialogs.okDialog(context, '권한을 허용하지 않으면 업데이트를 진행할 수 없습니다.');
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
      width: width - 150,
      height: 100,
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
                    child: Center(
                      child: RotationTransition(
                        turns: Tween(begin: 0.0, end: 0.7)
                            .animate(rotationController),
                        child: ShaderMask(
                          shaderCallback: (bounds) => RadialGradient(
                            center: Alignment.bottomLeft,
                            radius: 1.5,
                            colors: [
                              Colors.red.shade300,
                              Colors.purple.shade800
                            ],
                            tileMode: TileMode.clamp,
                          ).createShader(bounds),
                          child: Icon(
                            MdiIcons.update,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
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
