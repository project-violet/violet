// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/settings/settings.dart';

class SearchPageModifyPage extends StatefulWidget {
  final int curPage;
  final int maxPage;

  const SearchPageModifyPage({
    super.key,
    required this.curPage,
    required this.maxPage,
  });

  @override
  State<SearchPageModifyPage> createState() => _SearchPageModifyPageState();
}

class _SearchPageModifyPageState extends State<SearchPageModifyPage> {
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = TextEditingController(text: widget.curPage.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Item Jump'),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(children: [
            Text('${Translations.instance!.trans('position')}: '),
            Expanded(
              child: TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ], // Only numbers can be entered
              ),
            ),
            Text(' / ${widget.maxPage}'),
          ]),
          Container(
            height: 16,
          ),
          Row(
            children: <Widget>[
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Settings.majorColor,
                ),
                child: Text(Translations.instance!.trans('ok')),
                onPressed: () async {
                  if (_pageController.text == '') {
                    Navigator.pop(context, [
                      1,
                      0,
                    ]);
                    return;
                  }
                  if (int.parse(_pageController.text.trim()) >=
                      widget.maxPage) {
                    await showOkDialog(
                        context,
                        Translations.instance!
                            .trans('setlowerthanmaxitemposition'));
                    return;
                  }
                  Navigator.pop(context, [
                    1,
                    int.parse(_pageController.text),
                  ]);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Settings.majorColor,
                ),
                child: Text(Translations.instance!.trans('cancel')),
                onPressed: () {
                  Navigator.pop(context, [0]);
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
