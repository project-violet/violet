// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class TagSelectorDialog extends StatefulWidget {
  final String what;

  TagSelectorDialog({this.what});

  @override
  _TagSelectorDialogState createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<TagSelectorDialog> {
  @override
  void initState() {
    super.initState();
    if (widget.what == 'include')
      _searchController = TextEditingController(text: Settings.includeTags);
    else if (widget.what == 'exclude')
      _searchController =
          TextEditingController(text: Settings.excludeTags.join(' '));
    else if (widget.what == 'blurred')
      _searchController =
          TextEditingController(text: Settings.blurredTags.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).viewInsets.bottom;

    if (MediaQuery.of(context).viewInsets.bottom < 1) height = 400;

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
    }

    return AlertDialog(
      insetPadding: EdgeInsets.all(16),
      contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: Stack(
        overflow: Overflow.visible,
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            height: height,
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.all(0),
                  leading: Text('${Translations.of(context).trans('tag')}:'),
                  title: TextField(
                    controller: _searchController,
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (String str) async {
                      await searchProcess(str, _searchController.selection);
                    },
                  ),
                ),
                Expanded(
                  child: _searchLists.length == 0 || _nothing
                      ? Center(
                          child: Text(_nothing
                              ? Translations.of(context).trans('nosearchresult')
                              : Translations.of(context)
                                  .trans('inputsearchtoken')))
                      : Padding(
                          padding: EdgeInsets.symmetric(horizontal: 0),
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
                widget.what == 'include'
                    ? Text(Translations.of(context).trans('tagmsgdefault'),
                        style: TextStyle(fontSize: 14.0))
                    : Container()
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        RaisedButton(
          color: Settings.majorColor,
          child: Text(Translations.of(context).trans('ok')),
          onPressed: () {
            Navigator.pop(
                context, Tuple2<int, String>(1, _searchController.text));
          },
        ),
        RaisedButton(
          color: Settings.majorColor,
          child: Text(Translations.of(context).trans('cancel')),
          onPressed: () {
            Navigator.pop(
                context, Tuple2<int, String>(0, _searchController.text));
          },
        ),
      ],
    );
  }

  List<Tuple3<String, String, int>> _searchLists =
      List<Tuple3<String, String, int>>();

  TextEditingController _searchController;
  int _insertPos, _insertLength;
  String _searchText;
  bool _nothing = false;
  bool _tagTranslation = false;
  bool _showCount = true;
  int _searchResultMaximum = 60;

  Future<void> searchProcess(String target, TextSelection selection) async {
    _nothing = false;
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
    final result = (await HitomiManager.queryAutoComplete(token))
        .take(_searchResultMaximum)
        .toList();
    if (result.length == 0) _nothing = true;
    setState(() {
      _searchLists = result;
    });
  }

  // Create tag-chip
  // group, name, counts
  Widget chip(Tuple3<String, String, int> info) {
    var tagRaw = info.item2;
    var count = '';
    var color = Colors.grey;

    if (_tagTranslation) // Korean
      tagRaw = TagTranslate.ofAny(info.item2);

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
          await searchProcess(
              _searchController.text, _searchController.selection);
        }
      },
    );
    return fc;
  }
}
