// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class SearchFilter extends StatefulWidget {
  bool ignoreBookmark;
  bool blurred;
  bool isOr;
  bool isSearch;
  bool isPopulationSort;
  List<Tuple3<String, String, int>> tags = [];
  Map<String, bool> tagStates = Map<String, bool>();
  Map<String, bool> groupStates = Map<String, bool>();
  Map<String, int> groupCount = Map<String, int>();
  List<Tuple2<String, int>> groups = [];
  final List<QueryResult> queryResult;

  SearchFilter({
    this.ignoreBookmark,
    this.blurred,
    this.queryResult,
    this.tagStates,
    this.groupStates,
    this.isOr,
    this.isSearch,
    this.isPopulationSort,
  });

  @override
  _SearchFilterState createState() => _SearchFilterState();
}

class _SearchFilterState extends State<SearchFilter> {
  TextEditingController _searchController = TextEditingController();

  bool test = false;

  @override
  void initState() {
    super.initState();
    Map<String, int> tags = Map<String, int>();
    widget.queryResult.forEach((element) {
      if (element.tags() != null) {
        element.tags().split('|').forEach((element) {
          if (element == '') return;
          if (!tags.containsKey(element)) tags[element] = 0;
          tags[element] += 1;
        });
      }
    });
    widget.groupCount['tag'] = 0;
    widget.groupCount['female'] = 0;
    widget.groupCount['male'] = 0;
    tags.forEach((key, value) {
      var group = 'tag';
      var name = key;
      if (key.startsWith('female:')) {
        group = 'female';
        widget.groupCount['female'] += 1;
        name = key.split(':')[1];
      } else if (key.startsWith('male:')) {
        group = 'male';
        widget.groupCount['male'] += 1;
        name = key.split(':')[1];
      } else
        widget.groupCount['tag'] += 1;
      widget.tags.add(Tuple3<String, String, int>(group, name, value));
      if (!widget.tagStates.containsKey(group + '|' + name))
        widget.tagStates[group + '|' + name] = false;
    });
    if (!widget.groupStates.containsKey('tag'))
      widget.groupStates['tag'] = false;
    if (!widget.groupStates.containsKey('female'))
      widget.groupStates['female'] = false;
    if (!widget.groupStates.containsKey('male'))
      widget.groupStates['male'] = false;
    append('language', 'Language');
    append('character', 'Characters');
    append('series', 'Series');
    append('artist', 'Artists');
    append('group', 'Groups');
    append('class', 'Class');
    append('type', 'Type');
    append('uploader', 'Uploader');
    widget.groupCount.forEach((key, value) {
      widget.groups.add(Tuple2<String, int>(key, value));
    });
    widget.groups.sort((a, b) => b.item2.compareTo(a.item2));
    widget.tags.sort((a, b) => b.item3.compareTo(a.item3));
  }

  void append(String group, String vv) {
    if (!widget.groupStates.containsKey(group))
      widget.groupStates[group] = false;
    widget.groupCount[group] = 0;
    Map<String, int> tags = Map<String, int>();
    widget.queryResult.forEach((element) {
      if (element.result[vv] != null) {
        element.result[vv].split('|').forEach((element) {
          if (element == '') return;
          if (!tags.containsKey(element)) tags[element] = 0;
          tags[element] += 1;
        });
      }
    });
    widget.groupCount[group] += tags.length;
    tags.forEach((key, value) {
      widget.tags.add(Tuple3<String, String, int>(group, key, value));
      if (!widget.tagStates.containsKey(group + '|' + key))
        widget.tagStates[group + '|' + key] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mediaQuery = MediaQuery.of(context);
    final height = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        (mediaQuery.padding + mediaQuery.viewInsets).bottom;
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, [
          widget.ignoreBookmark,
          widget.blurred,
          widget.tagStates,
          widget.groupStates,
          widget.isOr,
        ]);
        return Future(() => false);
      },
      child: Container(
        color: Settings.themeWhat ? Color(0xFF353535) : Colors.grey.shade100,
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Hero(
              tag: "searchtype",
              child: Card(
                color: Settings.themeWhat
                    ? Color(0xFF353535)
                    : Colors.grey.shade100,
                child: SizedBox(
                  child: SizedBox(
                    width: width - 16,
                    height: height - 16,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Column(
                        // mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // Expanded(
                          //   child: ListView(
                          //     padding: EdgeInsets.zero,
                          //     physics: BouncingScrollPhysics(),
                          //     children: [
                          //       Wrap(
                          //           // alignment: WrapAlignment.center,
                          //           spacing: -7.0,
                          //           runSpacing: -13.0,
                          //           children: widget.tags
                          //               .where((element) =>
                          //                   widget.groupStates[element.item1])
                          //               .take(100)
                          //               .map((element) {
                          //             return _Chip(
                          //               selected: widget.tagStates[
                          //                   element.item1 +
                          //                       '|' +
                          //                       element.item2],
                          //               group: element.item1,
                          //               name: element.item2,
                          //               count: element.item3,
                          //               callback: (selected) {
                          //                 widget.tagStates[element.item1 +
                          //                     '|' +
                          //                     element.item2] = selected;
                          //               },
                          //             );
                          //           }).toList()
                          //           // <Widget>[
                          //           //   RawChip(
                          //           //     selected: test,
                          //           //     labelPadding: EdgeInsets.all(0.0),
                          //           //     avatar: CircleAvatar(
                          //           //       backgroundColor: Colors.grey.shade600,
                          //           //       child: Text('A'),
                          //           //     ),
                          //           //     label: Text(' ASDF'),
                          //           //     backgroundColor: Colors.orange,
                          //           //     elevation: 6.0,
                          //           //     shadowColor: Colors.grey[60],
                          //           //     padding: EdgeInsets.all(6.0),
                          //           //     onSelected: (value) {
                          //           //       setState(() {
                          //           //         test = value;
                          //           //       });
                          //           //     },
                          //           //   )
                          //           // ],
                          //           ),
                          //     ],
                          //   ),
                          // ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              physics: BouncingScrollPhysics(),
                              children: [
                                Wrap(
                                    // alignment: WrapAlignment.center,
                                    spacing: -7.0,
                                    runSpacing: -13.0,
                                    children: (
                                            // selected
                                            widget.tags
                                                    .where((element) =>
                                                        widget.tagStates[
                                                            element.item1 +
                                                                '|' +
                                                                element.item2])
                                                    .toList() +
                                                // searched or filtered
                                                (widget.isSearch
                                                    ? widget.tags
                                                        .where((element) =>
                                                            (element.item1 + ':' + element.item2).contains(_searchController.text) &&
                                                            !widget.tagStates[element
                                                                    .item1 +
                                                                '|' +
                                                                element.item2])
                                                        .toList()
                                                    : widget.tags
                                                        .where((element) =>
                                                            widget.groupStates[element.item1] &&
                                                            !widget.tagStates[element.item1 + '|' + element.item2])
                                                        .toList()))
                                        .take(100)
                                        .map((element) {
                                      return _Chip(
                                        selected: widget.tagStates[
                                            element.item1 +
                                                '|' +
                                                element.item2],
                                        group: element.item1,
                                        name: element.item2,
                                        count: element.item3,
                                        callback: (selected) {
                                          widget.tagStates[element.item1 +
                                              '|' +
                                              element.item2] = selected;
                                        },
                                      );
                                    }).toList()
                                    // <Widget>[
                                    //   RawChip(
                                    //     selected: test,
                                    //     labelPadding: EdgeInsets.all(0.0),
                                    //     avatar: CircleAvatar(
                                    //       backgroundColor: Colors.grey.shade600,
                                    //       child: Text('A'),
                                    //     ),
                                    //     label: Text(' ASDF'),
                                    //     backgroundColor: Colors.orange,
                                    //     elevation: 6.0,
                                    //     shadowColor: Colors.grey[60],
                                    //     padding: EdgeInsets.all(6.0),
                                    //     onSelected: (value) {
                                    //       setState(() {
                                    //         test = value;
                                    //       });
                                    //     },
                                    //   )
                                    // ],
                                    ),
                              ],
                            ),
                          ),
                          // Wrap(
                          //     alignment: WrapAlignment.center,
                          //     spacing: -7.0,
                          //     runSpacing: -13.0,
                          //     children: widget.groups
                          //         .map((element) => _Chip(
                          //               count: element.item2,
                          //               group: element.item1,
                          //               name: element.item1,
                          //               selected:
                          //                   widget.groupStates[element.item1],
                          //               callback: (value) {
                          //                 widget.groupStates[element.item1] =
                          //                     value;
                          //                 setState(() {});
                          //               },
                          //             ))
                          //         .toList()),
                          // Wrap(
                          //   alignment: WrapAlignment.center,
                          //   spacing: 4.0,
                          //   runSpacing: -10.0,
                          //   children: <Widget>[
                          //     FilterChip(
                          //       label: Text(Translations.of(context)
                          //           .trans('selectall')),
                          //       // selected: widget.ignoreBookmark,
                          //       onSelected: (bool value) {
                          //         widget.tags
                          //             .where((element) =>
                          //                 widget.groupStates[element.item1])
                          //             .forEach((element) {
                          //           widget.tagStates[element.item1 +
                          //               '|' +
                          //               element.item2] = true;
                          //         });
                          //         setState(() {});
                          //       },
                          //     ),
                          //     FilterChip(
                          //       label: Text(Translations.of(context)
                          //           .trans('deselectall')),
                          //       // selected: widget.blurred,
                          //       onSelected: (bool value) {
                          //         widget.tags
                          //             .where((element) =>
                          //                 widget.groupStates[element.item1])
                          //             .forEach((element) {
                          //           widget.tagStates[element.item1 +
                          //               '|' +
                          //               element.item2] = false;
                          //         });
                          //         setState(() {});
                          //       },
                          //     ),
                          //     FilterChip(
                          //       label: Text(
                          //           Translations.of(context).trans('inverse')),
                          //       // selected: widget.blurred,
                          //       onSelected: (bool value) {
                          //         widget.tags
                          //             .where((element) =>
                          //                 widget.groupStates[element.item1])
                          //             .forEach((element) {
                          //           widget.tagStates[
                          //               element.item1 +
                          //                   '|' +
                          //                   element.item2] = !widget.tagStates[
                          //               element.item1 + '|' + element.item2];
                          //         });
                          //         setState(() {});
                          //       },
                          //     ),
                          //   ],
                          // ),
                          widget.isSearch
                              ? _buildSelectedPanel()
                              : Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: -7.0,
                                  runSpacing: -13.0,
                                  children: widget.groups
                                      .map((element) => _Chip(
                                            count: element.item2,
                                            group: element.item1,
                                            name: element.item1,
                                            selected: widget
                                                .groupStates[element.item1],
                                            callback: (value) {
                                              widget.groupStates[
                                                  element.item1] = value;
                                              setState(() {});
                                            },
                                          ))
                                      .toList()),
                          widget.isSearch
                              ? _buildSearchControlPanel()
                              : _buildSelectControlPanel(),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4.0,
                            runSpacing: -10.0,
                            children: <Widget>[
                              FilterChip(
                                label: Text("Population"),
                                selected: widget.isPopulationSort,
                                onSelected: (bool value) {
                                  setState(() {
                                    widget.isPopulationSort = value;
                                  });
                                },
                              ),
                              FilterChip(
                                label: Text("OR"),
                                selected: widget.isOr,
                                onSelected: (bool value) {
                                  setState(() {
                                    widget.isOr = value;
                                  });
                                },
                              ),
                              // TODO: 북마크 블러 체크 필터
                              // FilterChip(
                              //   label: Text("북마크 제외"),
                              //   selected: widget.ignoreBookmark,
                              //   onSelected: (bool value) {
                              //     setState(() {
                              //       widget.ignoreBookmark =
                              //           !widget.ignoreBookmark;
                              //     });
                              //   },
                              // ),
                              // FilterChip(
                              //   label: Text("블러 처리"),
                              //   selected: widget.blurred,
                              //   onSelected: (bool value) {
                              //     setState(() {
                              //       widget.blurred = !widget.blurred;
                              //     });
                              //   },
                              // ),
                              FilterChip(
                                label: Text("Search"),
                                selected: widget.isSearch,
                                onSelected: (bool value) {
                                  setState(() {
                                    widget.isSearch = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // decoration: BoxDecoration(
        //   borderRadius: BorderRadius.all(Radius.circular(1)),
        //   boxShadow: [
        //     BoxShadow(
        //       color: Settings.themeWhat
        //           ? Colors.black.withOpacity(0.4)
        //           : Colors.grey.withOpacity(0.2),
        //       spreadRadius: 1,
        //       blurRadius: 1,
        //       offset: Offset(0, 3), // changes position of shadow
        //     ),
        //   ],
        // ),
      ),
    );
  }

  _buildSelectedPanel() {
    return Container();
  }

  _buildSearchControlPanel() {
    return TextFormField(
      cursorColor: Colors.black,
      onChanged: (String str) async {
        // await searchProcess(str, _searchController.selection);
        setState(() {});
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
            // await searchProcess('', _searchController.selection);
          },
          icon: Icon(Icons.clear),
        ),
        contentPadding:
            EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
        hintText: Translations.of(context).trans('search'),
      ),
    );
  }

  _buildSelectControlPanel() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4.0,
      runSpacing: -10.0,
      children: <Widget>[
        FilterChip(
          label: Text(Translations.of(context).trans('selectall')),
          // selected: widget.ignoreBookmark,
          onSelected: (bool value) {
            widget.tags
                .where((element) => widget.groupStates[element.item1])
                .forEach((element) {
              widget.tagStates[element.item1 + '|' + element.item2] = true;
            });
            setState(() {});
          },
        ),
        FilterChip(
          label: Text(Translations.of(context).trans('deselectall')),
          // selected: widget.blurred,
          onSelected: (bool value) {
            widget.tags
                .where((element) => widget.groupStates[element.item1])
                .forEach((element) {
              widget.tagStates[element.item1 + '|' + element.item2] = false;
            });
            setState(() {});
          },
        ),
        FilterChip(
          label: Text(Translations.of(context).trans('inverse')),
          // selected: widget.blurred,
          onSelected: (bool value) {
            widget.tags
                .where((element) => widget.groupStates[element.item1])
                .forEach((element) {
              widget.tagStates[element.item1 + '|' + element.item2] =
                  !widget.tagStates[element.item1 + '|' + element.item2];
            });
            setState(() {});
          },
        ),
      ],
    );
  }
}

typedef ChipCallback = void Function(bool);

class _Chip extends StatefulWidget {
  bool selected;
  final String group;
  final String name;
  final int count;
  final ChipCallback callback;

  _Chip({this.selected, this.group, this.name, this.count, this.callback});

  @override
  __ChipState createState() => __ChipState();
}

class __ChipState extends State<_Chip> {
  @override
  Widget build(BuildContext context) {
    var tagDisplayed = widget.name;
    var group = widget.group;
    Color color = Colors.grey;

    if (Settings.translateTags)
      tagDisplayed =
          TagTranslate.ofAny(tagDisplayed).split(':').last.split('|').first;

    if (group == 'female')
      color = Colors.pink;
    else if (group == 'male')
      color = Colors.blue;
    else if (group == 'language')
      color = Colors.teal;
    else if (group == 'series')
      color = Colors.cyan;
    else if (group == 'artist' || group == 'group')
      color = Colors.green.withOpacity(0.6);
    else if (group == 'type') color = Colors.orange;

    Widget avatar = Text(group[0].toUpperCase());

    if (group == 'female')
      avatar = Icon(MdiIcons.genderFemale, size: 18.0);
    else if (group == 'male')
      avatar = Icon(MdiIcons.genderMale, size: 18.0);
    else if (group == 'language')
      avatar = Icon(Icons.language, size: 18.0);
    else if (group == 'artist')
      avatar = Icon(MdiIcons.account, size: 18.0);
    else if (group == 'group')
      avatar = Icon(MdiIcons.accountGroup, size: 15.0);
    else if (group == 'type')
      avatar = Icon(MdiIcons.bookOpenPageVariant, size: 15.0);
    else if (group == 'series') avatar = Icon(MdiIcons.notebook, size: 15.0);

    var fc = Transform.scale(
        scale: 0.90,
        child: RawChip(
          selected: widget.selected,
          labelPadding: EdgeInsets.all(0.0),
          avatar: CircleAvatar(
            backgroundColor: Colors.grey.shade600,
            child: avatar,
          ),
          label: Text(
            ' ' +
                HtmlUnescape().convert(tagDisplayed) +
                ' (' +
                widget.count.toString() +
                ')',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          elevation: 6.0,
          padding: EdgeInsets.all(6.0),
          onSelected: (value) async {
            widget.callback(value);
            setState(() {
              widget.selected = value;
            });
          },
        ));
    return fc;
  }
}
