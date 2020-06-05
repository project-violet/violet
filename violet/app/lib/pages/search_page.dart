// This source code is a part of Project Violet.
// Copyright (C) 2020. rollrat. Licensed under the MIT Licence.

import 'dart:ui';

import 'package:flare_flutter/flare.dart';
import 'package:flare_dart/math/mat2d.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:violet/other/flare_artboard.dart';
// import 'package:keyboard_visibility/keyboard_visibility.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Color color = Colors.green;
  //double radius = 0;
  bool into = false;

  TextEditingController _controller = new TextEditingController();
  //FocusNode _focus = new FocusNode();
  final FlareControls heroFlareControls = FlareControls();
  FlutterActorArtboard artboard;

  @override
  void initState() {
    super.initState();

    (() async {
      var asset =
          await cachedActor(rootBundle, 'assets/flare/search_close.flr');
      asset.ref();
      artboard = asset.actor.artboard.makeInstance() as FlutterActorArtboard;
      artboard.initializeGraphics();
      artboard.advance(0);
    })();
    // KeyboardVisibilityNotification().addNewListener(
    //   onChange: (bool visible) {
    //     //print('asd');
    //     setState(() {
    //       into = visible;
    //     });
    //   },
    // );
    //_focus.addListener(_onFocusChange);
  }

  // void _onFocusChange(){
  //   print("Focus: "+_focus.hasFocus.toString());
  // }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    double _sigmaX = 8.0; // from 0-10
    double _sigmaY = 8.0; // from 0-10
    //color = Colors.green;

    return Container(
      //color: Colors.white,// Colors.black.withOpacity(0.1),
      padding: EdgeInsets.fromLTRB(8, statusBarHeight + 4, 8, 0),
      //child: BackdropFilter(
      //   filter: ImageFilter.blur(sigmaX: _sigmaX, sigmaY: _sigmaY),
      child: Stack(
        children: <Widget>[
          // GestureDetector(
          //     onTap: () {
          //       setState(() {
          //         into = !into;
          //       });
          //     },
          SizedBox(
              height: 64,
              child: Hero(
                tag: "searchbar",
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(8.0),
                    ),
                  ),
                  elevation: 100,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: Stack(
                    children: <Widget>[
                      Column(
                        children: <Widget>[
                          // AspectRatio(
                          //   aspectRatio: 485.0 / 384.0,
                          //   child: Image.network(
                          //       ""),
                          // ),
                          Material(
                            child: ListTile(
                              title: TextFormField(
                                cursorColor: Colors.black,
                                //keyboardType: inputType,
                                decoration: new InputDecoration(
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.only(
                                        left: 15,
                                        bottom: 11,
                                        top: 11,
                                        right: 15),
                                    hintText: '검색'),
                              ), //Text("검색"),
                              leading: SizedBox(
                                width: 25,
                                height: 25,
                                child: FlareArtboard(artboard,
                                        controller: heroFlareControls),
                                    // FlareActor(
                                    //   "assets/flare/search_close.flr",
                                    //   color: Colors.grey,
                                    //   snapToEnd: false,
                                    //   //alignment: Alignment.center,
                                    //   //fit: BoxFit.cover,
                                    //   animation: "close2search",
                                    //   //controller: this
                                    // ),
                              ),
                              //Icon(Icons.search),
                              //subtitle: Text("This is item #2"),
                            ),
                          )
                          //Text('zxcv')
                        ],
                      ),
                      Positioned(
                        left: 0.0,
                        top: 0.0,
                        bottom: 0.0,
                        right: 0.0,
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: () async {
                              await Future.delayed(Duration(milliseconds: 200));
                              heroFlareControls.play('search2close');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    return new SearchBar(artboard: artboard, heroController: heroFlareControls,);
                                  },
                                  fullscreenDialog: true,
                                ),

                                //PageRouteBuilder(
                                //    transitionDuration: Duration(seconds: 2),
                                //    pageBuilder: (_, __, ___) => SearchBar()),
                              ).then((value) => {
                                setState(() {
                                  heroFlareControls.play('close2search'); 
                                })
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                //   AnimatedContainer(
                //     duration: Duration(milliseconds: 5000),
                //     //color: Colors.green,
                //     curve: Curves.easeInOut,
                //     // decoration: BoxDecoration(
                //     //   color: Colors.white, // added
                //     //   border: Border.all(color: Colors.orange, width: 5), // added
                //     //   borderRadius: BorderRadius.circular(into ? 25 : 0),
                //     // ),
                //     child: Card(
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(into ? 0 : 4),
                //       ),
                //       elevation: 3,
                //       //child: Expanded(
                //       //mainAxisAlignment: MainAxisAlignment.start,
                //       child: into ? Column(
                //         children: <Widget>[
                //           TextField(
                //             controller: _controller,
                //             decoration: new InputDecoration.collapsed(
                //               hintText: '입력',
                //               border: InputBorder.none,
                //             ),
                //             //focusNode: _focus,
                //             onSubmitted: (str) {
                //               setState(() {
                //                 //color = Colors.red;
                //                 into = false;
                //               });
                //             },
                //             onTap: () {
                //               setState(() {
                //                 //color = Colors.red;
                //                 into = true;
                //               });
                //             },
                //           ),
                //           Expanded(child: Container()),
                //           //into ? SizedBox(height: 100,) : Container()
                //         ],
                //       ) : TextField(
                //             controller: _controller,
                //             decoration: new InputDecoration.collapsed(
                //               hintText: '입력',
                //               border: InputBorder.none,
                //             ),
                //             //focusNode: _focus,
                //             onSubmitted: (str) {
                //               setState(() {
                //                 //color = Colors.red;
                //                 into = false;
                //               });
                //             },
                //             onTap: () {
                //               setState(() {
                //                 //color = Colors.red;
                //                 into = true;
                //               });
                //             },
                //           ),
                //       //),
                //     ),
                //   ),
                //   //),
                // ],
              )
              // child: Padding(
              //   padding: EdgeInsets.fromLTRB(8, statusBarHeight, 8, 0),
              //   child: Center(
              //     child: Column(
              //       children: <Widget>[
              //         AnimatedContainer(
              //           duration: Duration(microseconds: 15000),
              //           color: color,
              //           child: TextField(
              //             onTap: () {
              //               setState(() {
              //                 print('asdf');
              //                 color = Colors.red;
              //               });
              //             },
              //           ),
              //         )
              //       ],
              //     ),
              //   ),
              // ),
              )
        ],
      ),
      //),
    );
  }
}

class SearchBar extends StatefulWidget {
  final FlareControls heroController;
  final FlutterActorArtboard artboard;
  const SearchBar({Key key, this.artboard, this.heroController}) : super(key: key);

  @override
  _SearchBarState createState() => _SearchBarState();
}

// class _SearchBarState extends State<SearchBar> {
//   @override
//   Widget build(BuildContext context) {
//     return Container(

//     );
//   }
// }

class _SearchBarState extends State<SearchBar>
    with SingleTickerProviderStateMixin {
  //final int num;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
      reverseDuration: Duration(milliseconds: 400),
    );
    
    SchedulerBinding.instance.addPostFrameCallback((_) async => {
      //widget.heroController.play('search2close')
    });
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    AppBar appBar = new AppBar(
      primary: false,
      leading: IconTheme(
          data: IconThemeData(color: Colors.white), child: CloseButton()),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.4),
              Colors.black.withOpacity(0.1),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    controller.forward();

    return Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(2, statusBarHeight + 2, 0, 0),
        child: Stack(children: <Widget>[
          Hero(
            tag: "searchbar",
            child: Card(
              //margin: EdgeInsets.fromLTRB(0, statusBarHeight, 0, 0),
              elevation: 100,
              //margin: EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              child: Material(
                child: Container(
                  //padding: EdgeInsets.fromLTRB(10, 8, 0, 0),
                  child: Column(
                    children: <Widget>[
                      // AspectRatio(
                      //   aspectRatio: 485.0 / 384.0,
                      //   child: Image.network(
                      //       ""),
                      // ),
                      Material(
                        child: ListTile(
                          title: TextFormField(
                            cursorColor: Colors.black,
                            //keyboardType: inputType,
                            decoration: new InputDecoration(
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.only(
                                    left: 15, bottom: 11, top: 11, right: 15),
                                hintText: '검색'),
                          ), //Text("검색"),
                          leading: SizedBox(
                              width: 25,
                              height: 25,
                              child: FlareArtboard(widget.artboard,
                                  controller: widget.heroController)
                              // FlareActor(
                              //   "assets/flare/search_close.flr",
                              //   color: Colors.grey,
                              //   //alignment: Alignment.center,
                              //   //fit: BoxFit.cover,
                              //   animation: "search2close",
                              //   //controller: this
                              // ),
                              ),
                          // AnimatedIcon(
                          //   icon: AnimatedIcons.search_ellipsis,
                          //   progress: controller,
                          //   semanticLabel: 'Search',
                          // )
                          //Icon(Icons.arrow_back),
                          //subtitle: Text("This is item #2"),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          //width: 130.0,
                          color: Colors.black12,
                        ),
                      ),
                      Expanded(
                        child: Center(child: Text("검색창 소환!")),
                      ),
                      //Text('zxcv')
                    ],
                  ),
                ),
              ),
              //child: Material(
              //  child: Column(
              //    children: <Widget>[
              //      AspectRatio(
              //        aspectRatio: 485.0 / 384.0,
              //        child: Image.network(""),
              //      ),
              //      Material(
              //        child: ListTile(
              //          title: Text("Item "),
              //          subtitle: Text("This is item "),
              //        ),
              //      ),
              //      Expanded(
              //        child: Center(child: Text("Some more content goes here!")),
              //      )
              //    ],
              //  ),
              //),
            ),
          ),
          // Column(
          //   children: <Widget>[
          //     Container(
          //       height: mediaQuery.padding.top,
          //     ),
          //     ConstrainedBox(
          //       constraints:
          //           BoxConstraints(maxHeight: appBar.preferredSize.height),
          //       child: appBar,
          //     )
          //   ],
          // ),
        ]));
  }

  ActorAnimation _rock;
  double _rockAmount = 0.5;
  double _speed = 1.5;
  double _rockTime = 0.0;

  @override
  bool advance(FlutterActorArtboard artboard, double elapsed) {
    _rockTime += elapsed * _speed;
    _rock.apply(_rockTime % _rock.duration, artboard, _rockAmount);
    return true;
  }

  @override
  void initialize(FlutterActorArtboard artboard) {
    _rock = artboard.getAnimation("search2close");
  }

  @override
  void setViewTransform(Mat2D viewTransform) {}
}
