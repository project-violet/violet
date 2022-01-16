// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:flare_flutter/flare.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/algorithm/distance.dart';
import 'package:violet/component/hitomi/displayed_tag.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/database/user/search.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/flare_artboard.dart';
import 'package:violet/pages/bookmark/group/group_article_list_page.dart';
import 'package:violet/settings/settings.dart';

class SearchBarPage extends StatefulWidget {
  final FlareControls heroController;
  final FlutterActorArtboard artboard;
  final String initText;
  const SearchBarPage(
      {Key key, this.artboard, this.initText, this.heroController})
      : super(key: key);

  @override
  _SearchBarPageState createState() => _SearchBarPageState();
}

class _SearchBarPageState extends State<SearchBarPage>
    with SingleTickerProviderStateMixin {
  PageController _bottomController = PageController(
    initialPage: 0,
  );
  PageController _topController = PageController(
    initialPage: 0,
  );
  static const _kDuration = const Duration(milliseconds: 300);
  static const _kCurve = Curves.ease;

  AnimationController controller;
  List<Tuple2<DisplayedTag, int>> _searchLists = <Tuple2<DisplayedTag, int>>[];
  List<Tuple2<DisplayedTag, int>> _relatedLists = <Tuple2<DisplayedTag, int>>[];

  TextEditingController _searchController;
  int _insertPos, _insertLength;
  String _searchText;
  bool _nothing = false;

  int _searchResultMaximum = 60;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
      reverseDuration: Duration(milliseconds: 400),
    );
    _searchController = TextEditingController(text: widget.initText ?? '');
  }

  @override
  void dispose() {
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  double _initBottomPadding;

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final mediaQuery = MediaQuery.of(context);
    controller.forward();

    if (_searchLists.length == 0 && !_nothing) {
      const prefixList = [
        'female',
        'male',
        'tag',
        'lang',
        'series',
        'artist',
        'group',
        'uploader',
        'character',
        'type',
        'class',
        'recent',
        'random'
      ];

      prefixList.forEach(
        (element) => _searchLists.add(
          Tuple2<DisplayedTag, int>(
              DisplayedTag(group: 'prefix', name: element), 0),
        ),
      );
    }

    if (_initBottomPadding == null)
      _initBottomPadding = (mediaQuery.padding + mediaQuery.viewInsets).bottom;

    return Container(
      color: Settings.themeWhat
          ? Settings.themeBlack
              ? const Color(0xFF141414)
              : Colors.grey.shade900
          : Colors.white,
      padding:
          EdgeInsets.fromLTRB(2, statusBarHeight + 2, 0, _initBottomPadding),
      child: Stack(
        children: <Widget>[
          Hero(
            tag: "searchbar",
            child: Card(
              elevation: 100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              color: Settings.themeBlack ? const Color(0xFF141414) : null,
              child: Material(
                color: Settings.themeBlack ? const Color(0xFF141414) : null,
                child: Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _searchBar(),
                      _seperator(),
                      _searchButton(),
                      _seperator(),
                      Expanded(
                        child: _searchTopPanel(),
                      ),
                      _seperator(),
                      Expanded(
                        child: _searchBottomPanel(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _seperator() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.0),
      child: Container(
        height: 1.0,
        color: Colors.black12,
      ),
    );
  }

  _searchBar() {
    return Material(
      child: ListTile(
        title: TextFormField(
          cursorColor: Colors.black,
          onChanged: (String str) async {
            await searchProcess(str, _searchController.selection);
          },
          controller: _searchController,
          decoration: InputDecoration(
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            suffixIcon: IconButton(
              onPressed: () async {
                _searchController.clear();
                _searchController.selection =
                    TextSelection(baseOffset: 0, extentOffset: 0);
                await searchProcess('', _searchController.selection);
              },
              icon: Icon(Icons.clear),
            ),
            contentPadding:
                EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
            hintText: Translations.of(context).trans('search'),
          ),
        ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  _searchButton() {
    return Container(
      height: 40,
      padding: EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: Settings.majorColor,
        ),
        child: Text(Translations.of(context).trans('search')),
        onPressed: () async {
          var search = _searchController.text;
          if (search.split(' ').any((x) => x == 'random')) {
            search = search.split(' ').where((x) => x != 'random').join(' ');
            search += ' random:${new Random().nextDouble() + 1}';
          }
          Navigator.pop(context, search);
        },
      ),
    );
  }

  _searchTopPanel() {
    return Stack(children: [
      PageView(
        controller: _topController,
        children: [
          _searchAutoCompletePanel(),
          _searchRelatedPanel(),
        ],
      ),
      FutureBuilder(
        future: Future.value(1),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Container();

          return Positioned(
            bottom: 0.0,
            left: 0.0,
            right: 0.0,
            child: Container(
              color: null,
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: DotsIndicator(
                  controller: _topController,
                  itemCount: 2,
                  onPageSelected: (int page) {
                    _topController.animateToPage(
                      page,
                      duration: _kDuration,
                      curve: _kCurve,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ]);
  }

  _searchAutoCompletePanel() {
    if (_searchLists.length == 0 || _nothing)
      return Center(
          child: Text(_nothing
              ? Translations.of(context).trans('nosearchresult')
              : Translations.of(context).trans('inputsearchtoken')));
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 8),
      physics: BouncingScrollPhysics(),
      children: [
        Wrap(
          spacing: 4.0,
          runSpacing: -10.0,
          children: _searchLists.map((item) => chip(item)).toList(),
        ),
      ],
    );
  }

  _searchRelatedPanel() {
    if (_relatedLists.length == 0)
      return Center(
          child: Text(Translations.of(context).trans('nosearchresult')));
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 8),
      physics: BouncingScrollPhysics(),
      children: [
        Wrap(
          spacing: 4.0,
          runSpacing: -10.0,
          children: _relatedLists.map((item) => chip(item, true)).toList(),
        ),
      ],
    );
  }

  _searchBottomPanel() {
    return Stack(
      children: [
        PageView(
          controller: _bottomController,
          children: [
            _searchOptionPage(),
            _searchHistory(),
          ],
        ),
        FutureBuilder(
          future: Future.value(1),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Container();
            return Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: Container(
                color: null,
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: DotsIndicator(
                    controller: _bottomController,
                    itemCount: 2,
                    onPageSelected: (int page) {
                      _bottomController.animateToPage(
                        page,
                        duration: _kDuration,
                        curve: _kCurve,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  _searchOptionPage() {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.translate, color: Settings.majorColor),
                    title:
                        Text(Translations.of(context).trans('tagtranslation')),
                    trailing: Switch(
                      value: Settings.searchTagTranslation,
                      onChanged: (newValue) async {
                        await Settings.setSearchTagTranslation(newValue);
                        setState(() {});
                      },
                      activeTrackColor: Settings.majorColor,
                      activeColor: Settings.majorAccentColor,
                    ),
                    onTap: () async {
                      await Settings.setSearchTagTranslation(
                          !Settings.searchTagTranslation);
                      setState(() {});
                    },
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
                    leading:
                        Icon(MdiIcons.layersSearch, color: Settings.majorColor),
                    title: Text('한글 검색'),
                    trailing: Switch(
                      value: Settings.searchUseTranslated,
                      onChanged: (newValue) async {
                        await Settings.setSearchUseTranslated(newValue);
                        setState(() {});
                      },
                      activeTrackColor: Settings.majorColor,
                      activeColor: Settings.majorAccentColor,
                    ),
                    onTap: () async {
                      await Settings.setSearchUseTranslated(
                          !Settings.searchUseTranslated);
                      setState(() {});
                    },
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
                    leading: Icon(MdiIcons.counter, color: Settings.majorColor),
                    title: Text(Translations.of(context).trans('showcount')),
                    trailing: Switch(
                      value: Settings.searchShowCount,
                      onChanged: (newValue) async {
                        await Settings.setSearchShowCount(newValue);
                        setState(() {});
                      },
                      activeTrackColor: Settings.majorColor,
                      activeColor: Settings.majorAccentColor,
                    ),
                    onTap: () async {
                      await Settings.setSearchShowCount(
                          !Settings.searchShowCount);
                      setState(() {});
                    },
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
                    leading:
                        Icon(MdiIcons.chartBubble, color: Settings.majorColor),
                    title: Text(Translations.of(context).trans('fuzzysearch')),
                    trailing: Switch(
                      value: Settings.searchUseFuzzy,
                      onChanged: (newValue) async {
                        await Settings.setSearchUseFuzzy(newValue);
                        setState(() {});
                      },
                      activeTrackColor: Settings.majorColor,
                      activeColor: Settings.majorAccentColor,
                    ),
                    onTap: () async {
                      await Settings.setSearchUseFuzzy(
                          !Settings.searchUseFuzzy);
                      setState(() {});
                    },
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  primary: Settings.themeWhat
                                      ? Colors.grey.shade800
                                      : Colors.grey,
                                  onPrimary: Colors.black,
                                ),
                                child: Icon(MdiIcons.keyboardBackspace),
                                onPressed: () {
                                  deleteProcess();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  primary: Settings.themeWhat
                                      ? Colors.grey.shade800
                                      : Colors.grey,
                                  onPrimary: Colors.black,
                                ),
                                child: Icon(MdiIcons.keyboardSpace),
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
    );
  }

  _searchHistory() {
    return FutureBuilder(
      future: SearchLogDatabase.getInstance()
          .then((value) async => await value.getSearchLog()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        var logs = (snapshot.data as List<SearchLog>)
            .where((element) => element.searchWhat() != null)
            .toList();
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemExtent: 50.0,
          itemBuilder: (context, index) {
            if (index == 0)
              return Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Search Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              );
            return InkWell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        logs[index - 1].searchWhat(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      logs[index - 1].datetime().toString(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  _searchController.text = logs[index - 1].searchWhat();
                });
              },
            );
          },
          itemCount: logs.length + 1,
        );
      },
    );
  }

  Future<void> searchProcess(String target, TextSelection selection) async {
    _nothing = false;
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

    if (token.startsWith('female:') ||
        token.startsWith('male:') ||
        token.startsWith('tag:')) {
      _relatedLists = HitomiIndexs.getRelatedTag(token.startsWith('tag:')
              ? token.split(':').last.replaceAll('_', ' ')
              : token.replaceAll('_', ' '))
          .map((e) => Tuple2<DisplayedTag, int>(
              DisplayedTag(group: 'tag', name: e.item1),
              (e.item2 * 100).toInt()))
          .toList();
    } else if (token.startsWith('series:')) {
      _relatedLists = HitomiIndexs.getRelatedCharacters(
              token.split(':').last.replaceAll('_', ' '))
          .map((e) => Tuple2<DisplayedTag, int>(
              DisplayedTag(group: 'character', name: e.item1), e.item2.toInt()))
          .toList();
    } else if (token.startsWith('character:')) {
      _relatedLists = HitomiIndexs.getRelatedSeries(
              token.split(':').last.replaceAll('_', ' '))
          .map((e) => Tuple2<DisplayedTag, int>(
              DisplayedTag(group: 'series', name: e.item1), e.item2.toInt()))
          .toList();
    } else {
      _relatedLists.clear();
    }

    _insertPos = pos;
    _insertLength = token.length;
    _searchText = target;
    latestToken = token;
    if (!Settings.searchUseFuzzy) {
      final result = (await HitomiManager.queryAutoComplete(
              token, Settings.searchUseTranslated))
          .take(_searchResultMaximum)
          .toList();
      if (result.length == 0) _nothing = true;
      setState(() {
        _searchLists = result;
      });
    } else {
      final result = (await HitomiManager.queryAutoCompleteFuzzy(
              token, Settings.searchUseTranslated))
          .take(_searchResultMaximum)
          .toList();
      if (result.length == 0) _nothing = true;
      setState(() {
        _searchLists = result;
      });
    }
  }

  String latestToken = '';

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
  Widget chip(Tuple2<DisplayedTag, int> info, [bool related = false]) {
    var tagDisplayed = info.item1.name.split(':').last;
    var count = '';
    Color color = Colors.grey;

    if (Settings.searchTagTranslation || Settings.searchUseTranslated)
      tagDisplayed = info.item1.getTranslated();

    if (info.item2 > 0 && Settings.searchShowCount)
      count =
          ' (${info.item2.toString() + (related && info.item1.group == 'tag' ? '%' : '')})';

    if (info.item1.group == 'tag' && info.item1.name.startsWith('female:'))
      color = Colors.pink;
    else if (info.item1.group == 'tag' && info.item1.name.startsWith('male:'))
      color = Colors.blue;
    else if (info.item1.group == 'prefix')
      color = Colors.orange;
    else if (info.item1.group == 'language')
      color = Colors.teal;
    else if (info.item1.group == 'series')
      color = Colors.cyan;
    else if (info.item1.group == 'artist' || info.item1.group == 'group')
      color = Colors.green.withOpacity(0.6);
    else if (info.item1.group == 'type') color = Colors.orange;

    var ts = <TextSpan>[];
    var accColor = Colors.pink;

    if (color == Colors.pink) accColor = Colors.orange;

    if (!Settings.searchUseFuzzy &&
        latestToken != '' &&
        tagDisplayed.contains(latestToken) &&
        !related) {
      ts.add(TextSpan(
          style: TextStyle(
            color: Colors.white,
          ),
          text: tagDisplayed.split(latestToken)[0]));
      ts.add(TextSpan(
          style: TextStyle(
            color: accColor,
            fontWeight: FontWeight.bold,
          ),
          text: latestToken));
      ts.add(TextSpan(
          style: TextStyle(
            color: Colors.white,
          ),
          text: tagDisplayed.split(latestToken)[1]));
    } else if (!Settings.searchUseFuzzy &&
        latestToken.contains(':') &&
        latestToken.split(':')[1] != '' &&
        tagDisplayed.contains(latestToken.split(':')[1]) &&
        !related) {
      ts.add(TextSpan(
          style: TextStyle(
            color: Colors.white,
          ),
          text: tagDisplayed.split(latestToken.split(':')[1])[0]));
      ts.add(TextSpan(
          style: TextStyle(
            color: accColor,
            fontWeight: FontWeight.bold,
          ),
          text: latestToken.split(':')[1]));
      ts.add(TextSpan(
          style: TextStyle(
            color: Colors.white,
          ),
          text: tagDisplayed.split(latestToken.split(':')[1])[1]));
    } else if (!Settings.searchUseFuzzy &&
        !Settings.searchUseTranslated &&
        !related) {
      ts.add(TextSpan(
          style: TextStyle(
            color: Colors.white,
          ),
          text: tagDisplayed));
    } else if (latestToken != '' && !related) {
      var route = Distance.levenshteinDistanceRoute(
          tagDisplayed.runes.toList(), latestToken.runes.toList());
      for (int i = 0; i < tagDisplayed.length; i++) {
        ts.add(TextSpan(
            style: TextStyle(
              color: route[i + 1] == 1 ? accColor : Colors.white,
              fontWeight:
                  route[i + 1] == 1 ? FontWeight.bold : FontWeight.normal,
            ),
            text: tagDisplayed[i]));
      }
    } else {
      ts.add(TextSpan(
          style: TextStyle(
            color: Colors.white,
          ),
          text: tagDisplayed));
    }

    var fc = RawChip(
      labelPadding: EdgeInsets.all(0.0),
      avatar: CircleAvatar(
        backgroundColor: Colors.grey.shade600,
        child: Text(info.item1.group == 'tag' &&
                (info.item1.name.startsWith('female:') ||
                    info.item1.name.startsWith('male:'))
            ? info.item1.name[0].toUpperCase()
            : info.item1.group[0].toUpperCase()),
      ),
      label: RichText(
          text: TextSpan(
              style: TextStyle(
                color: Colors.white,
              ),
              children: [
            TextSpan(text: ' '),
            TextSpan(children: ts),
            TextSpan(text: count),
          ])),
      backgroundColor: color,
      elevation: 6.0,
      shadowColor: Colors.grey[60],
      padding: EdgeInsets.all(6.0),
      onPressed: () async {
        // Insert text to cursor.
        if (info.item1.group != 'prefix') {
          var insert = (info.item1.group == 'tag' &&
                      (info.item1.name.startsWith('female') ||
                          info.item1.name.startsWith('male'))
                  ? info.item1.name
                  : info.item1.getTag())
              .replaceAll(' ', '_');

          _searchController.text = _searchText.substring(0, _insertPos) +
              insert +
              _searchText.substring(
                  _insertPos + _insertLength, _searchText.length);
          _searchController.selection = TextSelection(
            baseOffset: _insertPos + insert.length,
            extentOffset: _insertPos + insert.length,
          );

          if (info.item1.group == 'tag') {
            _relatedLists =
                HitomiIndexs.getRelatedTag(info.item1.name.replaceAll('_', ' '))
                    .map((e) => Tuple2<DisplayedTag, int>(
                        DisplayedTag(group: 'tag', name: e.item1),
                        (e.item2 * 100).toInt()))
                    .toList();
            setState(() {});
          } else if (info.item1.group == 'series') {
            _relatedLists = HitomiIndexs.getRelatedCharacters(
                    info.item1.name.replaceAll('_', ' '))
                .map((e) => Tuple2<DisplayedTag, int>(
                    DisplayedTag(group: 'character', name: e.item1),
                    e.item2.toInt()))
                .toList();
            setState(() {});
          } else if (info.item1.group == 'character') {
            _relatedLists = HitomiIndexs.getRelatedSeries(
                    info.item1.name.replaceAll('_', ' '))
                .map((e) => Tuple2<DisplayedTag, int>(
                    DisplayedTag(group: 'series', name: e.item1),
                    e.item2.toInt()))
                .toList();
            setState(() {});
          }
        } else {
          var offset = _searchController.selection.baseOffset;
          if (offset != -1) {
            _searchController.text = _searchController.text
                    .substring(0, _searchController.selection.base.offset) +
                info.item1.name +
                (info.item1.name == 'random' ? ' ' : ':') +
                _searchController.text
                    .substring(_searchController.selection.base.offset);
            _searchController.selection = TextSelection(
              baseOffset: offset + info.item1.name.length + 1,
              extentOffset: offset + info.item1.name.length + 1,
            );
          } else {
            _searchController.text =
                info.item1.name + (info.item1.name == 'random' ? '' : ':');
            _searchController.selection = TextSelection(
              baseOffset: info.item1.name.length + 1,
              extentOffset: info.item1.name.length + 1,
            );
          }
          await searchProcess(
              _searchController.text, _searchController.selection);
        }
      },
    );
    return fc;
  }
}
