// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:ui';

import 'package:auto_animated/auto_animated.dart';
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
import 'package:infinite_listview/infinite_listview.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:tuple/tuple.dart';
import 'package:vibration/vibration.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database.dart';
import 'package:violet/locale.dart';
import 'package:violet/other/flare_artboard.dart';
import 'package:violet/settings.dart';
import 'package:violet/syncfusion/slider.dart';
import 'package:violet/widgets/article_list_item_widget.dart';

bool searchPageBlur = false;

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin<SearchPage> {
  @override
  bool get wantKeepAlive => true;

  Color color = Colors.green;
  bool into = false;

  TextEditingController _controller = new TextEditingController();
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => heroFlareControls.play('close2search'));
  }

  Tuple2<QueryManager, String> latestQuery;

  @override
  Widget build(BuildContext context) {
    final InfiniteScrollController _infiniteController =
        InfiniteScrollController(
      initialScrollOffset: 0.0,
    );
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    double width = MediaQuery.of(context).size.width;

    return Container(
      child: Column(
        children: <Widget>[
          Stack(children: <Widget>[
            Container(
              padding: EdgeInsets.fromLTRB(8, statusBarHeight + 8, 72, 0),
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
                              Material(
                                color: Settings.themeWhat
                                    ? Colors.grey.shade900.withOpacity(0.4)
                                    : Colors.grey.shade100.withOpacity(0.4),
                                child: ListTile(
                                  title: TextFormField(
                                    cursorColor: Colors.black,
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
                                        hintText: latestQuery != null &&
                                                latestQuery.item2.trim() != ''
                                            ? latestQuery.item2
                                            : Translations.of(context)
                                                .trans('search')),
                                  ),
                                  leading: SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: FlareArtboard(artboard,
                                        controller: heroFlareControls),
                                  ),
                                ),
                              )
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
                                  await Navigator.push(
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
                                  ).then((value) async {
                                    setState(() {
                                      heroFlareControls.play('close2search');
                                    });
                                    if (value == null) return;
                                    latestQuery = value;
                                    queryResult = List<QueryResult>();
                                    await loadNextQuery();
                                  });
                                  // print(latestQuery);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  width - 8 - 64, statusBarHeight + 8, 8, 0),
              child: SizedBox(
                height: 64,
                child: Hero(
                  tag: "searchtype",
                  child: Card(
                    color: Settings.themeWhat
                        ? Color(0xFF353535)
                        : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(8.0),
                      ),
                    ),
                    elevation: 100,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: InkWell(
                      child: SizedBox(
                        height: 64,
                        width: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Icon(
                              MdiIcons.formatListText,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(context)
                            .push(PageRouteBuilder(
                          opaque: false,
                          transitionDuration: Duration(milliseconds: 500),
                          transitionsBuilder: (BuildContext context,
                              Animation<double> animation,
                              Animation<double> secondaryAnimation,
                              Widget wi) {
                            return new FadeTransition(
                                opacity: animation, child: wi);
                          },
                          pageBuilder: (_, __, ___) => SearchType(),
                        ))
                            .then((value) async {
                          await Future.delayed(Duration(milliseconds: 50), () {
                            setState(() {});
                          });
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ]),
          Expanded(
            child: GestureDetector(
              child: makeResult(),
              onScaleStart: (detail) {
                scaleOnce = false;
              },
              onScaleUpdate: (detail) async {
                if ((detail.scale > 1.2 || detail.scale < 0.8) &&
                    scaleOnce == false) {
                  scaleOnce = true;
                  setState(() {
                    searchPageBlur = !searchPageBlur;
                  });
                  await Vibration.vibrate(duration: 50, amplitude: 50);
                  Scaffold.of(context).showSnackBar(SnackBar(
                    duration: Duration(milliseconds: 600),
                    content: new Text(
                      searchPageBlur ? '화면 블러가 적용되었습니다.' : '화면 블러가 해제되었습니다.',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.grey.shade800,
                  ));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  bool scaleOnce = false;
  List<QueryResult> queryResult = List<QueryResult>();

  Future<void> loadNextQuery() async {
    var nn = await latestQuery.item1.next();
    setState(() {
      queryResult.addAll(nn);
    });
  }

  Widget makeResult() {
    switch (Settings.searchResultType) {
      case 0:
      case 1:
        return LiveGrid(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(16),
          showItemInterval: Duration(milliseconds: 50),
          showItemDuration: Duration(milliseconds: 150),
          visibleFraction: 0.001,
          itemCount: queryResult.length,
          shrinkWrap: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Settings.searchResultType == 0 ? 3 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3 / 4,
          ),
          itemBuilder: (context, index, animation) {
            return FadeTransition(
              opacity: Tween<double>(
                begin: 0,
                end: 1,
              ).animate(animation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, -0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      child: ArticleListItemVerySimpleWidget(
                        queryResult: queryResult[index],
                        addBottomPadding: false,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case 2:
        return ListView.builder(
          physics: const BouncingScrollPhysics(), // new
          itemCount: queryResult.length,
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.center,
              child: ArticleListItemVerySimpleWidget(
                addBottomPadding: true,
                queryResult: queryResult[index],
              ),
            );
          },
        );

      default:
        return Container(
          child: Center(
            child: Text('Error :('),
          ),
        );
    }
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

class _SearchBarState extends State<SearchBar>
    with SingleTickerProviderStateMixin {
  AnimationController controller;
  List<Tuple3<String, String, int>> _searchLists =
      List<Tuple3<String, String, int>>();

  TextEditingController _searchController = TextEditingController();
  int _insertPos, _insertLength;
  String _searchText;
  bool _nothing = false;
  bool _onChip = false;
  bool _tagTranslation = false;
  bool _showCount = true;
  int _searchResultMaximum = 60;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
      reverseDuration: Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    controller.forward();

    if (_searchLists.length == 0 && !_nothing) {
      _searchLists.add(Tuple3<String, String, int>('prefix', 'female', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'male', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'tag', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'lang', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'series', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'artist', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'group', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'uploader', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'character', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'type', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'class', 0));
      _searchLists.add(Tuple3<String, String, int>('prefix', 'recent', 0));
    }

    return Container(
        color: Settings.themeWhat ? Colors.grey.shade900 : Colors.white,
        padding: EdgeInsets.fromLTRB(2, statusBarHeight + 2, 0, 0),
        child: Stack(children: <Widget>[
          Hero(
            tag: "searchbar",
            child: Card(
              elevation: 100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              child: Material(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Material(
                        child: ListTile(
                          title: TextFormField(
                            cursorColor: Colors.black,
                            onChanged: (String str) async {
                              await searchProcess(
                                  str, _searchController.selection);
                            },
                            controller: _searchController,
                            decoration: new InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              suffixIcon: IconButton(
                                onPressed: () async {
                                  _searchController.clear();
                                  _searchController.selection = TextSelection(
                                      baseOffset: 0, extentOffset: 0);
                                  await searchProcess(
                                      '', _searchController.selection);
                                },
                                icon: Icon(Icons.clear),
                              ),
                              contentPadding: EdgeInsets.only(
                                  left: 15, bottom: 11, top: 11, right: 15),
                              hintText:
                                  Translations.of(context).trans('search'),
                            ),
                          ),
                          leading: SizedBox(
                            width: 25,
                            height: 25,
                            child: RawMaterialButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                shape: CircleBorder(),
                                child: FlareArtboard(widget.artboard,
                                    controller: widget.heroController)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
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
                              color: Settings.majorColor,
                              textColor: Colors.white,
                              child: Text(
                                  Translations.of(context).trans('search')),
                              onPressed: () async {
                                final query = HitomiManager.translate2query(
                                    _searchController.text);
                                final result =
                                    QueryManager.queryPagination(query);
                                Navigator.pop(
                                    context,
                                    Tuple2<QueryManager, String>(
                                        result, _searchController.text));
                              },
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          color: Colors.black12,
                        ),
                      ),
                      Expanded(
                        child: _searchLists.length == 0 || _nothing
                            ? Center(
                                child: Text(_nothing
                                    ? Translations.of(context)
                                        .trans('nosearchresult')
                                    : Translations.of(context)
                                        .trans('inputsearchtoken')))
                            : Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: FadingEdgeScrollView
                                    .fromSingleChildScrollView(
                                  child: SingleChildScrollView(
                                    controller: ScrollController(),
                                    child: Wrap(
                                      spacing: 4.0,
                                      runSpacing: -10.0,
                                      children: _searchLists
                                          .map((item) => chip(item))
                                          .toList(),
                                    ),
                                  ),
                                  gradientFractionOnEnd: 0.1,
                                  gradientFractionOnStart: 0.1,
                                ),
                              ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Container(
                          height: 1.0,
                          color: Colors.black12,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
                          child: LayoutBuilder(builder: (BuildContext context,
                              BoxConstraints constraints) {
                            return SingleChildScrollView(
                              controller: ScrollController(),
                              child: ConstrainedBox(
                                constraints: constraints.copyWith(
                                  minHeight: constraints.maxHeight,
                                  maxHeight: double.infinity,
                                ),
                                child: IntrinsicHeight(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      ListTile(
                                        leading: Icon(Icons.translate,
                                            color: Settings.majorColor),
                                        title: Text(Translations.of(context)
                                            .trans('tagtranslation')),
                                        trailing: Switch(
                                          value: _tagTranslation,
                                          onChanged: (value) {
                                            setState(() {
                                              _tagTranslation = value;
                                            });
                                          },
                                          activeTrackColor: Settings.majorColor,
                                          activeColor:
                                              Settings.majorAccentColor,
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
                                            color: Settings.majorColor),
                                        title: Text(Translations.of(context)
                                            .trans('showcount')),
                                        trailing: Switch(
                                          value: _showCount,
                                          onChanged: (value) {
                                            setState(() {
                                              _showCount = value;
                                            });
                                          },
                                          activeTrackColor: Settings.majorColor,
                                          activeColor:
                                              Settings.majorAccentColor,
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
                                        leading: Icon(
                                            MdiIcons.viewGridPlusOutline,
                                            color: Settings.majorColor),
                                        title: Slider(
                                          min: 60.0,
                                          max: 2000.0,
                                          divisions: (2000 - 60) ~/ 10,
                                          label:
                                              '$_searchResultMaximum${Translations.of(context).trans('tagdisplay')}',
                                          onChanged: (double value) {
                                            print(value);
                                            setState(() {
                                              _searchResultMaximum =
                                                  value.toInt();
                                            });
                                          },
                                          value:
                                              _searchResultMaximum.toDouble(),
                                        ),
                                      ),

                                      // GradientRangeSlider(),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                              vertical: 8,
                                            ),
                                            width: double.infinity,
                                            height: 60,
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: <Widget>[
                                                Expanded(
                                                  child: RaisedButton(
                                                    color: Settings.themeWhat
                                                        ? Colors.grey.shade800
                                                        : Colors.grey,
                                                    child: Icon(MdiIcons
                                                        .keyboardBackspace),
                                                    onPressed: () {
                                                      deleteProcess();
                                                    },
                                                  ),
                                                ),
                                                Container(
                                                  width: 8,
                                                ),
                                                Expanded(
                                                  child: RaisedButton(
                                                    color: Settings.themeWhat
                                                        ? Colors.grey.shade800
                                                        : Colors.grey,
                                                    child: Icon(
                                                        MdiIcons.keyboardSpace),
                                                    onPressed: () {
                                                      spaceProcess();
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]));
  }

  Future<void> searchProcess(String target, TextSelection selection) async {
    _nothing = false;
    _onChip = false;
    if (target.trim() == '') {
      setState(() {
        _searchLists.clear();
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
        _searchLists.clear();
      });
      return;
    }

    _insertPos = pos;
    _insertLength = token.length;
    _searchText = target;
    final result = (await HitomiManager.queryAutoComplete(token))
        .take(_searchResultMaximum)
        .toList();
    if (result.length == 0) _nothing = true;
    setState(() {
      _searchLists = result;
    });
  }

  Future<void> deleteProcess() async {
    var text = _searchController.text;
    var selection = _searchController.selection;

    if (text == null || text.trim() == '') return;

    // Delete one token
    int fpos = selection.base.offset - 1;
    for (; fpos < text.length; fpos++)
      if (text[fpos] == ' ') {
        break;
      }

    int pos = fpos - 1;
    for (; pos > 0; pos--)
      if (text[pos] == ' ') {
        pos++;
        break;
      }

    text = text.substring(0, pos) + text.substring(fpos);
    _searchController.text = text;
    _searchController.selection = TextSelection(
      baseOffset: pos,
      extentOffset: pos,
    );
    await searchProcess(_searchController.text, _searchController.selection);
  }

  Future<void> spaceProcess() async {
    var text = _searchController.text;
    var selection = _searchController.selection;

    _searchController.text = text.substring(0, selection.base.offset) +
        ' ' +
        text.substring(selection.base.offset + 1);
    _searchController.selection = TextSelection(
      baseOffset: selection.baseOffset + 1,
      extentOffset: selection.baseOffset + 1,
    );
    await searchProcess(_searchController.text, _searchController.selection);
  }

  // Create tag-chip
  // group, name, counts
  Widget chip(Tuple3<String, String, int> info) {
    var tagRaw = info.item2;
    var count = '';
    var color = Colors.grey;

    if (_tagTranslation) // Korean
      tagRaw =
          HitomiManager.mapSeries2Kor(HitomiManager.mapTag2Kor(info.item2));

    if (info.item3 > 0 && _showCount) count = ' (${info.item3})';

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
        ' ' + tagRaw + count,
        style: TextStyle(
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      elevation: 6.0,
      shadowColor: Colors.grey[60],
      padding: EdgeInsets.all(6.0),
      onPressed: () async {
        // Insert text to cursor.
        if (info.item1 != 'prefix') {
          var insert = info.item2.replaceAll(' ', '_');
          if (info.item1 != 'female' && info.item1 != 'male')
            insert = info.item1 + ':' + insert;

          _searchController.text = _searchText.substring(0, _insertPos) +
              insert +
              _searchText.substring(
                  _insertPos + _insertLength, _searchText.length);
          _searchController.selection = TextSelection(
            baseOffset: _insertPos + insert.length,
            extentOffset: _insertPos + insert.length,
          );
        } else {
          var offset = _searchController.selection.baseOffset;
          if (offset != -1) {
            _searchController.text = _searchController.text
                    .substring(0, _searchController.selection.base.offset) +
                info.item2 +
                ': ' +
                _searchController.text
                    .substring(_searchController.selection.base.offset);
            _searchController.selection = TextSelection(
              baseOffset: offset + info.item2.length + 1,
              extentOffset: offset + info.item2.length + 1,
            );
          } else {
            _searchController.text = info.item2 + ': ';
            _searchController.selection = TextSelection(
              baseOffset: info.item2.length + 1,
              extentOffset: info.item2.length + 1,
            );
          }
          _onChip = true;
          await searchProcess(
              _searchController.text, _searchController.selection);
        }
      },
    );
    return fc;
  }
}

class SearchType extends StatefulWidget {
  @override
  _SearchTypeState createState() => _SearchTypeState();
}

class _SearchTypeState extends State<SearchType> {
  Color getColor(int i) {
    return Settings.themeWhat
        ? Settings.searchResultType == i
            ? Colors.grey.shade200
            : Colors.grey.shade400
        : Settings.searchResultType == i
            ? Colors.grey.shade900
            : Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Hero(
            tag: "searchtype",
            child: Card(
              color:
                  Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
              child: SizedBox(
                child: SizedBox(
                  width: 280,
                  height: 240,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        ListTile(
                          leading: Icon(Icons.grid_on, color: getColor(0)),
                          title: Text(Translations.of(context).trans('srt0'),
                              style: TextStyle(color: getColor(0))),
                          onTap: () async {
                            Settings.setSearchResultType(0);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.gridLarge, color: getColor(1)),
                          title: Text(Translations.of(context).trans('srt1'),
                              style: TextStyle(color: getColor(1))),
                          onTap: () async {
                            Settings.setSearchResultType(1);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(MdiIcons.viewAgendaOutline,
                              color: getColor(2)),
                          title: Text(
                            Translations.of(context).trans('srt2'),
                            style: TextStyle(color: getColor(2)),
                          ),
                          onTap: () async {
                            Settings.setSearchResultType(2);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading:
                              Icon(MdiIcons.formatListText, color: getColor(3)),
                          title: Text(
                            Translations.of(context).trans('srt3'),
                            style: TextStyle(color: getColor(3)),
                          ),
                          onTap: () async {
                            Settings.setSearchResultType(3);
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                          child: Container(),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(1)),
        boxShadow: [
          BoxShadow(
            color: Settings.themeWhat
                ? Colors.black.withOpacity(0.4)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
    );
  }
}
