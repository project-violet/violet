// This source code is a part of Project Violet.
// Copyright (C) 2020. rollrat. Licensed under the MIT Licence.

import 'dart:ui';

import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flare_flutter/flare.dart';
import 'package:flare_dart/math/mat2d.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
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
    Future.delayed(Duration(milliseconds: 500),
        () => heroFlareControls.play('close2search'));
    // SchedulerBinding.instance.addPostFrameCallback((_) async => {
    //       heroFlareControls.play('close2search')
    //     });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => heroFlareControls.play('close2search'));
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
    double width = MediaQuery.of(context).size.width;
    double _sigmaX = 8.0; // from 0-10
    double _sigmaY = 8.0; // from 0-10
    //color = Colors.green;

    return Container(
      //color: Colors.white,// Colors.black.withOpacity(0.1),
      //padding: EdgeInsets.fromLTRB(8, statusBarHeight + 4, 60, 0),
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
          Container(
            //color: Colors.white,// Colors.black.withOpacity(0.1),
            padding: EdgeInsets.fromLTRB(8, statusBarHeight + 4, 8, 0),
            child: SizedBox(
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
                                await Future.delayed(
                                    Duration(milliseconds: 200));
                                heroFlareControls.play('search2close');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return new SearchBar(
                                        artboard: artboard,
                                        heroController: heroFlareControls,
                                      );
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
                ),
          ),
          // Container(
          //   padding:
          //       EdgeInsets.fromLTRB(width - 8 - 64, statusBarHeight + 4, 8, 0),
          //   child: SizedBox(
          //     height: 64,
          //     child: Hero(
          //       tag: "searchmenu",
          //       child: Card(
          //         color: Colors.grey.shade200,
          //         shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.all(
          //             Radius.circular(8.0),
          //           ),
          //         ),
          //         elevation: 100,
          //         clipBehavior: Clip.antiAliasWithSaveLayer,
          //         child: SizedBox(
          //           height: 64,
          //           width: 64,
          //           child: Stack(Icon(Icons.star),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
      //),
    );
  }
}

class SearchBar extends StatefulWidget {
  final FlareControls heroController;
  final FlutterActorArtboard artboard;
  const SearchBar({Key key, this.artboard, this.heroController})
      : super(key: key);

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
  List<Tuple3<String, String, int>> search_lists =
      List<Tuple3<String, String, int>>();

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

    if (search_lists.length == 0 && !nothing) {
      search_lists.add(Tuple3<String, String, int>('prefix', 'female', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'male', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'tag', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'lang', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'series', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'artist', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'group', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'uploader', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'character', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'type', 0));
      search_lists.add(Tuple3<String, String, int>('prefix', 'class', 0));
    }

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
                            onChanged: (String str) async {
                              await searchProcess(
                                  str, search_controller.selection);
                            },
                            controller: search_controller,
                            decoration: new InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              suffixIcon: IconButton(
                                onPressed: () async {
                                  search_controller.clear();
                                  search_controller.selection = TextSelection(
                                      baseOffset: 0, extentOffset: 0);
                                  await searchProcess(
                                      '', search_controller.selection);
                                },
                                icon: Icon(Icons.clear),
                              ),
                              contentPadding: EdgeInsets.only(
                                  left: 15, bottom: 11, top: 11, right: 15),
                              hintText: '검색',
                            ),
                          ), //Text("검색"),
                          leading: SizedBox(
                            width: 25,
                            height: 25,
                            child: RawMaterialButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                //elevation: 2.0,
                                //fillColor: Colors.white,
                                //padding: EdgeInsets.all(15.0),
                                shape: CircleBorder(),
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
                      SizedBox(
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(8, 2, 8, 2),
                          child: ButtonTheme(
                            minWidth: double.infinity,
                            height: 30,
                            child: RaisedButton(
                              color: Colors.purple,
                              textColor: Colors.white,
                              child: Text('검색'),
                              onPressed: () {},
                            ),
                          ),
                        ),
                      ),
                      // Divider(
                      //   color: Colors.grey,
                      //   indent: 10,
                      //   endIndent: 10,
                      // ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          //width: 130.0,
                          color: Colors.black12,
                        ),
                      ),
                      Expanded(
                        child: search_lists.length == 0 || nothing
                            ? Center(
                                child: Text(nothing
                                    ? '검색 결과가 없습니다 :('
                                    : "검색어를 입력해 주세요!"))
                            : Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: FadingEdgeScrollView
                                    .fromSingleChildScrollView(
                                  child: SingleChildScrollView(
                                    controller: ScrollController(),
                                    child: Wrap(
                                      spacing: 4.0,
                                      runSpacing: -10.0,
                                      children: search_lists
                                          .map((item) => chip(item))
                                          .toList(),
                                    ),
                                  ),
                                  gradientFractionOnEnd: 0.1,
                                  gradientFractionOnStart: 0.1,
                                ),
                              ),
                      ),
                      // Divider(
                      //   color: Colors.grey,
                      //   indent: 10,
                      //   endIndent: 10,
                      // ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          //width: 130.0,
                          color: Colors.black12,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
                          child: FadingEdgeScrollView.fromSingleChildScrollView(
                            child: SingleChildScrollView(
                              controller: ScrollController(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  ListTile(
                                    leading: Icon(Icons.translate,
                                        color: Colors.purple),
                                    title: Text("태그 한글화"),
                                    trailing: Switch(
                                      value: tag_translation,
                                      onChanged: (value) {
                                        setState(() {
                                          tag_translation = value;
                                        });
                                      },
                                      activeTrackColor: Colors.purple,
                                      activeColor: Colors.purpleAccent,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    width: double.infinity,
                                    height: 1.0,
                                    color: Colors.grey.shade400,
                                  ),
                                  ListTile(
                                    leading: Icon(MdiIcons.counter,
                                        color: Colors.purple),
                                    title: Text("카운트 표시"),
                                    trailing: Switch(
                                      value: show_count,
                                      onChanged: (value) {
                                        setState(() {
                                          show_count = value;
                                        });
                                      },
                                      activeTrackColor: Colors.purple,
                                      activeColor: Colors.purpleAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          //Center(child: Text("검색창 소환!")),
                        ),
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

  TextEditingController search_controller = TextEditingController();
  int insert_pos, insert_length;
  String search_text;
  bool nothing = false;

  Future<void> searchProcess(String target, TextSelection selection) async {
    nothing = false;
    if (target.trim() == '') {
      setState(() {
        search_lists.clear();
      });
      return;
    }

    int pos = selection.base.offset - 1;
    for (; pos > 0; pos--)
      if (target[pos] == ' ') {
        pos++;
        break;
      }

    var last = target.indexOf(' ', pos);
    var token =
        target.substring(pos, last == -1 ? target.length : last + 1).trim();

    if (pos != target.length && target[pos] == '-') {
      token = token.substring(1);
      pos++;
    }
    if (token == '') {
      setState(() {
        search_lists.clear();
      });
      return;
    }

    insert_pos = pos;
    insert_length = token.length;
    search_text = target;
    final result = (await HitomiManager.queryAutoComplete(token))
        .take(search_result_maximum)
        .toList();
    setState(() {
      if (result.length == 0) nothing = true;
      search_lists = result;
    });
  }

  bool tag_translation = false;
  bool show_count = true;
  int search_result_maximum = 60;

  // Create tag-chip
  // group, name, counts
  Widget chip(Tuple3<String, String, int> info) {
    var tag_raw = info.item2;
    var count = '';
    var color = Colors.grey;

    if (tag_translation) // Korean
      tag_raw =
          HitomiManager.mapSeries2Kor(HitomiManager.mapTag2Kor(info.item2));

    if (info.item3 > 0 && show_count) count = ' (${info.item3})';

    if (info.item1 == 'female')
      color = Colors.pink;
    else if (info.item1 == 'male')
      color = Colors.blue;
    else if (info.item1 == 'prefix') color = Colors.orange;

    var fc = RawChip(
      labelPadding: EdgeInsets.all(0.0),
      avatar: CircleAvatar(
        backgroundColor: Colors.grey.shade600,
        child: Text(info.item1[0].toUpperCase()),
      ),
      label: Text(
        ' ' + tag_raw + count,
        style: TextStyle(
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      elevation: 6.0,
      shadowColor: Colors.grey[60],
      padding: EdgeInsets.all(6.0),
      onPressed: () async {
        if (info.item1 != 'prefix') {
          var insert = info.item2.replaceAll(' ', '_');
          if (info.item1 != 'female' && info.item1 != 'male')
            insert = info.item1 + ':' + insert;

          search_controller.text = search_text.substring(0, insert_pos) +
              insert +
              search_text.substring(
                  insert_pos + insert_length, search_text.length);
          search_controller.selection = TextSelection(
            baseOffset: insert_pos + insert.length,
            extentOffset: insert_pos + insert.length,
          );
        } else {
          var offset = search_controller.selection.baseOffset;
          if (offset != -1) {
            search_controller.text = search_controller.text
                    .substring(0, search_controller.selection.base.offset) +
                info.item2 +
                ': ' +
                search_controller.text
                    .substring(search_controller.selection.base.offset);
            search_controller.selection = TextSelection(
              baseOffset: offset + info.item2.length + 1,
              extentOffset: offset + info.item2.length + 1,
            );
          } else {
            search_controller.text = info.item2 + ': ';
            search_controller.selection = TextSelection(
              baseOffset: info.item2.length + 1,
              extentOffset: info.item2.length + 1,
            );
          }
          await searchProcess(
              search_controller.text, search_controller.selection);
        }
      },
    );
    return fc;
  }
}
