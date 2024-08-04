// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart' as trans;
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/segment/filter_page_controller.dart';
import 'package:violet/settings/settings.dart';

class FilterPage extends StatefulWidget {
  final List<QueryResult> queryResult;

  const FilterPage({
    super.key,
    required this.queryResult,
  });

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  late FilterController c;

  final _searchController = TextEditingController();

  bool test = false;

  final _tags = <Tuple3<String, String, int>>[];
  final _groupCount = <String, int>{};
  final _groups = <Tuple2<String, int>>[];

  _initTagPad() {
    Map<String, int> tags = <String, int>{};
    for (var element in widget.queryResult) {
      if (element.tags() != null) {
        element.tags().split('|').forEach((element) {
          if (element == '') return;
          if (!tags.containsKey(element)) tags[element] = 0;
          tags[element] = tags[element]! + 1;
        });
      }
    }
    _groupCount['tag'] = 0;
    _groupCount['female'] = 0;
    _groupCount['male'] = 0;
    tags.forEach((key, value) {
      var group = 'tag';
      var name = key;
      if (key.startsWith('female:') || key.startsWith('male:')) {
        group = key.split(':')[0];
        name = key.split(':')[1];
      }
      _groupCount[group] = _groupCount[group]! + 1;
      _tags.add(Tuple3<String, String, int>(group, name, value));
      if (!c.tagStates.containsKey('$group|$name')) {
        c.tagStates['$group|$name'] = false;
      }
    });
    if (!c.groupStates.containsKey('tag')) c.groupStates['tag'] = false;
    if (!c.groupStates.containsKey('female')) c.groupStates['female'] = false;
    if (!c.groupStates.containsKey('male')) c.groupStates['male'] = false;
    append('language', 'Language');
    append('character', 'Characters');
    append('series', 'Series');
    append('artist', 'Artists');
    append('group', 'Groups');
    append('class', 'Class');
    append('type', 'Type');
    append('uploader', 'Uploader');
    _groupCount
        .forEach((key, value) => _groups.add(Tuple2<String, int>(key, value)));
    _groups.sort((a, b) => b.item2.compareTo(a.item2));
    _tags.sort((a, b) => b.item3.compareTo(a.item3));
  }

  void append(String group, String vv) {
    if (!c.groupStates.containsKey(group)) c.groupStates[group] = false;
    _groupCount[group] = 0;
    Map<String, int> tags = <String, int>{};
    for (var element in widget.queryResult) {
      if (element.result[vv] != null) {
        element.result[vv].split('|').forEach((element) {
          if (element == '') return;
          if (!tags.containsKey(element)) tags[element] = 0;
          tags[element] = tags[element]! + 1;
        });
      }
    }
    _groupCount[group] = _groupCount[group]! + tags.length;
    tags.forEach((key, value) {
      _tags.add(Tuple3<String, String, int>(group, key, value));
      if (!c.tagStates.containsKey('$group|$key')) {
        c.tagStates['$group|$key'] = false;
      }
    });
  }

  bool _initOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initOnce) {
      _initOnce = true;
      c = Provider.of<FilterController>(context);
      _initTagPad();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      heroTag: c.heroKey,
      enableBackgroundColor: true,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildTagsPanel(),
                ],
              ),
            ),
            c.isSearch ? Container() : _buildSelectPanel(),
            c.isSearch
                ? _buildSearchControlPanel()
                : _buildSelectControlPanel(),
            _buildOptionButtons()
          ],
        ),
      ),
    );
  }

  /*@override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Container(
      color: Settings.themeWhat ? Color(0xFF353535) : Palette.lightThemeBackground,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          bottom: (mediaQuery.padding + mediaQuery.viewInsets).bottom),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Hero(tag: c.heroKey, child: _buildPanel()),
        ],
      ),
    );
  }

  _buildPanel() {
    final width = MediaQuery.of(context).size.width;
    final mediaQuery = MediaQuery.of(context);
    final height = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        (mediaQuery.padding + mediaQuery.viewInsets).bottom;
    return Card(
      color: Settings.themeWhat ? Color(0xFF353535) : Palette.lightThemeBackground,
      child: SizedBox(
        child: SizedBox(
          width: width - 16,
          height: height - 16,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: BouncingScrollPhysics(),
                    children: [
                      _buildTagsPanel(),
                    ],
                  ),
                ),
                c.isSearch ? Container() : _buildSelectPanel(),
                c.isSearch
                    ? _buildSearchControlPanel()
                    : _buildSelectControlPanel(),
                _buildOptionButtons()
              ],
            ),
          ),
        ),
      ),
    );
  }*/

  _buildOptionButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4.0,
      runSpacing: -10.0,
      children: <Widget>[
        FilterChip(
          label: const Text('Population'),
          selected: c.isPopulationSort,
          onSelected: (bool value) {
            setState(() {
              c.isPopulationSort = value;
            });
          },
        ),
        FilterChip(
          label: const Text('OR'),
          selected: c.isOr,
          onSelected: (bool value) {
            setState(() {
              c.isOr = value;
            });
          },
        ),
        FilterChip(
          label: const Text('Search'),
          selected: c.isSearch,
          onSelected: (bool value) {
            setState(() {
              c.isSearch = value;
            });
          },
        ),
      ],
    );
  }

  _buildTagsPanel() {
    var tags = _tags
        .where((element) => c.tagStates['${element.item1}|${element.item2}']!)
        .toList();

    if (c.isSearch) {
      tags += _tags
          .where((element) =>
              ('${element.item1}:${element.item2}')
                  .contains(_searchController.text) &&
              !c.tagStates['${element.item1}|${element.item2}']!)
          .toList();
    } else {
      tags += _tags
          .where((element) =>
              c.groupStates[element.item1]! &&
              !c.tagStates['${element.item1}|${element.item2}']!)
          .toList();
    }

    return Wrap(
        // alignment: WrapAlignment.center,
        spacing: -7.0,
        runSpacing: -13.0,
        children: tags.take(100).map(
          (element) {
            return _Chip(
              selected: c.tagStates['${element.item1}|${element.item2}']!,
              group: element.item1,
              name: element.item2,
              count: element.item3,
              callback: (selected) {
                c.tagStates['${element.item1}|${element.item2}'] = selected;
              },
            );
          },
        ).toList());
  }

  _buildSelectPanel() {
    return Wrap(
        alignment: WrapAlignment.center,
        spacing: -7.0,
        runSpacing: -13.0,
        children: _groups
            .map((element) => _Chip(
                  count: element.item2,
                  group: element.item1,
                  name: element.item1,
                  selected: c.groupStates[element.item1]!,
                  callback: (value) {
                    c.groupStates[element.item1] = value;
                    setState(() {});
                  },
                ))
            .toList());
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
                const TextSelection(baseOffset: 0, extentOffset: 0);
            // await searchProcess('', _searchController.selection);
          },
          icon: const Icon(Icons.clear),
        ),
        contentPadding:
            const EdgeInsets.only(left: 15, bottom: 11, top: 11, right: 15),
        hintText: trans.Translations.of(context).trans('search'),
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
          label: Text(trans.Translations.of(context).trans('selectall')),
          onSelected: (bool value) {
            _tags
                .where((element) => c.groupStates[element.item1]!)
                .forEach((element) {
              c.tagStates['${element.item1}|${element.item2}'] = true;
            });
            setState(() {});
          },
        ),
        FilterChip(
          label: Text(trans.Translations.of(context).trans('deselectall')),
          onSelected: (bool value) {
            _tags
                .where((element) => c.groupStates[element.item1]!)
                .forEach((element) {
              c.tagStates['${element.item1}|${element.item2}'] = false;
            });
            setState(() {});
          },
        ),
        FilterChip(
          label: Text(trans.Translations.of(context).trans('inverse')),
          onSelected: (bool value) {
            _tags
                .where((element) => c.groupStates[element.item1]!)
                .forEach((element) {
              c.tagStates['${element.item1}|${element.item2}'] =
                  !c.tagStates['${element.item1}|${element.item2}']!;
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
  final bool selected;
  final String group;
  final String name;
  final int count;
  final ChipCallback callback;

  const _Chip({
    required this.selected,
    required this.group,
    required this.name,
    required this.count,
    required this.callback,
  });

  @override
  State<_Chip> createState() => __ChipState();
}

class __ChipState extends State<_Chip> {
  bool selected = false;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    var tagDisplayed = widget.name;
    var group = widget.group;
    Color color = Colors.grey;

    if (Settings.translateTags) {
      tagDisplayed =
          TagTranslate.ofAny(tagDisplayed).split(':').last.split('|').first;
    }

    if (group == 'female') {
      color = Colors.pink;
    } else if (group == 'male') {
      color = Colors.blue;
    } else if (group == 'language') {
      color = Colors.teal;
    } else if (group == 'series') {
      color = Colors.cyan;
    } else if (group == 'artist' || group == 'group') {
      color = Colors.green.withOpacity(0.6);
    } else if (group == 'type') {
      color = Colors.orange;
    }

    Widget avatar = Text(group[0].toUpperCase());

    if (group == 'female') {
      avatar = const Icon(MdiIcons.genderFemale, size: 18.0);
    } else if (group == 'male') {
      avatar = const Icon(MdiIcons.genderMale, size: 18.0);
    } else if (group == 'language') {
      avatar = const Icon(Icons.language, size: 18.0);
    } else if (group == 'artist') {
      avatar = const Icon(MdiIcons.account, size: 18.0);
    } else if (group == 'group') {
      avatar = const Icon(MdiIcons.accountGroup, size: 15.0);
    } else if (group == 'type') {
      avatar = const Icon(MdiIcons.bookOpenPageVariant, size: 15.0);
    } else if (group == 'series') {
      avatar = const Icon(MdiIcons.notebook, size: 15.0);
    }

    var fc = Transform.scale(
        scale: 0.90,
        child: RawChip(
          selected: selected,
          labelPadding: const EdgeInsets.all(0.0),
          avatar: CircleAvatar(
            backgroundColor: Colors.grey.shade600,
            child: avatar,
          ),
          label: Text(
            ' ${HtmlUnescape().convert(tagDisplayed)} (${widget.count})',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          elevation: 6.0,
          padding: const EdgeInsets.all(6.0),
          onSelected: (value) async {
            widget.callback(value);
            setState(() {
              selected = value;
            });
          },
        ));
    return fc;
  }
}
