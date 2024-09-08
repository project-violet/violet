// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/displayed_tag.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';

class TagSelectorDialog extends StatefulWidget {
  final String what;
  final bool onlyFMT;

  const TagSelectorDialog(
      {super.key, required this.what, this.onlyFMT = false});

  @override
  State<TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<TagSelectorDialog> {
  @override
  void initState() {
    super.initState();
    if (widget.what == 'include') {
      _searchController = TextEditingController(text: Settings.includeTags);
    } else if (widget.what == 'exclude') {
      _searchController =
          TextEditingController(text: Settings.excludeTags.join(' '));
    } else if (widget.what == 'blurred') {
      _searchController =
          TextEditingController(text: Settings.blurredTags.join(' '));
    } else {
      _searchController = TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).viewInsets.bottom;

    if (MediaQuery.of(context).viewInsets.bottom < 1) height = 400;

    if (_searchLists.isEmpty && !_nothing) {
      _searchLists.add((DisplayedTag(group: 'prefix', name: 'female'), 0));
      _searchLists.add((DisplayedTag(group: 'prefix', name: 'male'), 0));
      _searchLists.add((DisplayedTag(group: 'prefix', name: 'tag'), 0));
      if (!widget.onlyFMT) {
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'lang'), 0));
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'series'), 0));
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'artist'), 0));
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'group'), 0));
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'uploader'), 0));
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'character'), 0));
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'type'), 0));
        _searchLists.add((DisplayedTag(group: 'prefix', name: 'class'), 0));
      }
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: Stack(
        clipBehavior: Clip.none,
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
                  contentPadding: const EdgeInsets.all(0),
                  leading: Text('${Translations.instance!.trans('tag')}:'),
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
                  child: _searchLists.isEmpty || _nothing
                      ? Center(
                          child: Text(_nothing
                              ? Translations.instance!.trans('nosearchresult')
                              : Translations.instance!
                                  .trans('inputsearchtoken')))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
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
                    ? Text(Translations.instance!.trans('tagmsgdefault'),
                        style: const TextStyle(fontSize: 14.0))
                    : Container()
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Settings.majorColor,
          ),
          child: Text(Translations.instance!.trans('ok')),
          onPressed: () {
            Navigator.pop(context, (1, _searchController.text));
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Settings.majorColor,
          ),
          child: Text(Translations.instance!.trans('cancel')),
          onPressed: () {
            Navigator.pop(context, (0, _searchController.text));
          },
        ),
      ],
    );
  }

  List<(DisplayedTag, int)> _searchLists = <(DisplayedTag, int)>[];

  late final TextEditingController _searchController;
  int? _insertPos, _insertLength;
  String? _searchText;
  bool _nothing = false;
  final bool _tagTranslation = false;
  final bool _showCount = true;
  final int _searchResultMaximum = 60;

  Future<void> searchProcess(String target, TextSelection selection) async {
    _nothing = false;
    if (target.trim() == '') {
      setState(() {
        _searchLists.clear();
      });
      return;
    }

    int pos = selection.base.offset - 1;
    for (; pos > 0; pos--) {
      if (target[pos] == ' ') {
        pos++;
        break;
      }
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
    if (result.isEmpty) _nothing = true;
    setState(() {
      if (!widget.onlyFMT) {
        _searchLists = result;
      } else {
        _searchLists = result
            .where((element) =>
                ['female', 'male', 'tag'].contains(element.$1.group))
            .toList();
      }
    });
  }

  // Create tag-chip
  // group, name, counts
  Widget chip((DisplayedTag, int) info) {
    var tagDisplayed = info.$1.name!.split(':').last;
    var count = '';
    Color color = Colors.grey;

    if (_tagTranslation) {
      tagDisplayed = info.$1.getTranslated();
    }

    if (info.$2 > 0 && _showCount) count = ' (${info.$2})';

    if (info.$1.group == 'female') {
      color = Colors.pink;
    } else if (info.$1.group == 'male') {
      color = Colors.blue;
    } else if (info.$1.group == 'prefix') {
      color = Colors.orange;
    } else if (info.$1.group == 'language') {
      color = Colors.teal;
    } else if (info.$1.group == 'series') {
      color = Colors.cyan;
    } else if (info.$1.group == 'artist' || info.$1.group == 'group') {
      color = Colors.green.withOpacity(0.6);
    } else if (info.$1.group == 'type') {
      color = Colors.orange;
    }

    final fc = RawChip(
      labelPadding: const EdgeInsets.all(0.0),
      avatar: CircleAvatar(
        backgroundColor: Colors.grey.shade600,
        child: Text(info.$1.group![0].toUpperCase()),
      ),
      label: Text(
        ' $tagDisplayed$count',
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      elevation: 6.0,
      shadowColor: Colors.grey[60],
      padding: const EdgeInsets.all(6.0),
      onPressed: () async {
        // Insert text to cursor.
        if (info.$1.group != 'prefix') {
          final insert = info.$1.getTag().replaceAll(' ', '_');

          _searchController.text = _searchText!.substring(0, _insertPos) +
              insert +
              _searchText!
                  .substring(_insertPos! + _insertLength!, _searchText!.length);
          _searchController.selection = TextSelection(
            baseOffset: _insertPos! + insert.length,
            extentOffset: _insertPos! + insert.length,
          );
        } else {
          var offset = _searchController.selection.baseOffset;
          if (offset != -1) {
            _searchController.text =
                '${_searchController.text.substring(0, _searchController.selection.base.offset)}${info.$1.name!}:${_searchController.text.substring(_searchController.selection.base.offset)}';
            _searchController.selection = TextSelection(
              baseOffset: offset + info.$1.name!.length + 1,
              extentOffset: offset + info.$1.name!.length + 1,
            );
          } else {
            _searchController.text = '${info.$1.name!}:';
            _searchController.selection = TextSelection(
              baseOffset: info.$1.name!.length + 1,
              extentOffset: info.$1.name!.length + 1,
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
