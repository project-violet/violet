// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:flare_flutter/flare.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/flare_artboard.dart';
import 'package:violet/settings/settings.dart';

class SearchBarPage extends StatefulWidget {
  final FlareControls heroController;
  final FlutterActorArtboard artboard;
  const SearchBarPage({Key key, this.artboard, this.heroController})
      : super(key: key);

  @override
  _SearchBarPageState createState() => _SearchBarPageState();
}

class _SearchBarPageState extends State<SearchBarPage>
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
    final mediaQuery = MediaQuery.of(context);
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
        padding: EdgeInsets.fromLTRB(2, statusBarHeight + 2, 0,
            (mediaQuery.padding + mediaQuery.viewInsets).bottom),
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
                          // leading: SizedBox(
                          //   width: 25,
                          //   height: 25,
                          //   child: RawMaterialButton(
                          //       onPressed: () {
                          //         Navigator.pop(context);
                          //       },
                          //       shape: CircleBorder(),
                          //         child: FlareArtboard(widget.artboard,
                          //             controller: widget.heroController),
                          // ),
                          leading: Container(
                            transform: Matrix4.translationValues(-4, 0, 0),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: RawMaterialButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  shape: CircleBorder(),
                                  child: Transform.scale(
                                    scale: 0.65,
                                    child: FlareArtboard(widget.artboard,
                                        controller: widget.heroController),
                                  )),
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
                                // final query = HitomiManager.translate2query(
                                //     _searchController.text +
                                //         ' ' +
                                //         Settings.includeTags +
                                //         ' ' +
                                //         Settings.excludeTags
                                //             .where((e) => e.trim() != '')
                                //             .map((e) => '-$e')
                                //             .join(' ')
                                //             .trim());
                                // final result =
                                //     QueryManager.queryPagination(query);
                                // Navigator.pop(
                                //     context,
                                //     Tuple2<QueryManager, String>(
                                //         result, _searchController.text));
                                // final searchInfo = await HentaiManager.search(
                                //     _searchController.text);
                                Navigator.pop(context, _searchController.text
                                    // Tuple2<Tuple2<List<QueryResult>, int>,
                                    //         String>(
                                    //     searchInfo, _searchController.text
                                    // )
                                    );
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
                                        leading: Icon(MdiIcons.chartBubble,
                                            color: Settings.majorColor),
                                        title: Text(Translations.of(context)
                                            .trans('fuzzysearch')),
                                        trailing: Switch(
                                          value: useFuzzy,
                                          onChanged: (value) {
                                            setState(() {
                                              useFuzzy = value;
                                            });
                                          },
                                          activeTrackColor: Settings.majorColor,
                                          activeColor:
                                              Settings.majorAccentColor,
                                        ),
                                      ),
                                      // Container(
                                      //   margin: const EdgeInsets.symmetric(
                                      //     horizontal: 8.0,
                                      //   ),
                                      //   width: double.infinity,
                                      //   height: 1.0,
                                      //   color: Colors.grey.shade400,
                                      // ),
                                      // ListTile(
                                      //   leading: Icon(
                                      //       MdiIcons.viewGridPlusOutline,
                                      //       color: Settings.majorColor),
                                      //   title: Slider(
                                      //     activeColor: Settings.majorColor,
                                      //     inactiveColor: Settings.majorColor
                                      //         .withOpacity(0.2),
                                      //     min: 60.0,
                                      //     max: 2000.0,
                                      //     divisions: (2000 - 60) ~/ 30,
                                      //     label:
                                      //         '$_searchResultMaximum${Translations.of(context).trans('tagdisplay')}',
                                      //     onChanged: (double value) {
                                      //       setState(() {
                                      //         _searchResultMaximum =
                                      //             value.toInt();
                                      //       });
                                      //     },
                                      //     value:
                                      //         _searchResultMaximum.toDouble(),
                                      //   ),
                                      // ),

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
      latestToken = '';
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

    if (pos != target.length && (target[pos] == '-' || target[pos] == '(')) {
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
    latestToken = token;
    if (!useFuzzy) {
      final result = (await HitomiManager.queryAutoComplete(token))
          .take(_searchResultMaximum)
          .toList();
      if (result.length == 0) _nothing = true;
      setState(() {
        _searchLists = result;
      });
    } else {
      final result = (await HitomiManager.queryAutoCompleteFuzzy(token))
          .take(_searchResultMaximum)
          .toList();
      if (result.length == 0) _nothing = true;
      setState(() {
        _searchLists = result;
      });
    }
  }

  String latestToken = '';
  bool useFuzzy = false;

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

    var ts = List<TextSpan>();
    var accColor = Colors.pink;

    if (color == Colors.pink) accColor = Colors.orange;

    if (!useFuzzy && latestToken != '' && tagRaw.contains(latestToken)) {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken)[0]));
      ts.add(TextSpan(
          style: new TextStyle(
            color: accColor,
            fontWeight: FontWeight.bold,
          ),
          text: latestToken));
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken)[1]));
    } else if (!useFuzzy &&
        latestToken.contains(':') &&
        latestToken.split(':')[1] != '' &&
        tagRaw.contains(latestToken.split(':')[1])) {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken.split(':')[1])[0]));
      ts.add(TextSpan(
          style: new TextStyle(
            color: accColor,
            fontWeight: FontWeight.bold,
          ),
          text: latestToken.split(':')[1]));
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw.split(latestToken.split(':')[1])[1]));
    } else if (!useFuzzy) {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw));
    } else if (latestToken != '') {
      var route = Distance.levenshteinDistanceRoute(
          tagRaw.runes.toList(), latestToken.runes.toList());
      for (int i = 0; i < tagRaw.length; i++) {
        ts.add(TextSpan(
            style: new TextStyle(
              color: route[i + 1] == 1 ? accColor : Colors.white,
              fontWeight:
                  route[i + 1] == 1 ? FontWeight.bold : FontWeight.normal,
            ),
            text: tagRaw[i]));
      }
    } else {
      ts.add(TextSpan(
          style: new TextStyle(
            color: Colors.white,
          ),
          text: tagRaw));
    }

    var fc = RawChip(
      labelPadding: EdgeInsets.all(0.0),
      avatar: CircleAvatar(
        backgroundColor: Colors.grey.shade600,
        child: Text(info.item1[0].toUpperCase()),
      ),
      label: RichText(
          text: new TextSpan(
              style: new TextStyle(
                color: Colors.white,
              ),
              children: [
            new TextSpan(text: ' '),
            new TextSpan(children: ts),
            new TextSpan(text: count),
          ])),
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
