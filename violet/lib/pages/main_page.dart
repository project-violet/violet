// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/widgets/CardScrollWidget.dart';
import 'package:violet/locale.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  var currentPage = images.length - 1.0;
  var currentPage2 = images.length - 1.0;

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

    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
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
                padding: EdgeInsets.all(50),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Notice',//Translations.of(context).trans('notice'),
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
              Text(Translations.of(context).trans('notice1'),),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: Translations.of(context).trans('notice21'),
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
                    ),
                  ],
                ),
              ),
              Text(Translations.of(context).trans('notice3')),
              Text(''),
              Text(Translations.of(context).trans('notice4')),
              Text(Translations.of(context).trans('notice5')),
              Text(''),
              Text('Copyright (C) 2020. dc-koromo. All rights reserved.'),
              Padding(
                padding: EdgeInsets.all(10),
              ),
              Text('Violet 0.3'),
              Text(
                'Thanks to Flutter developers.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
