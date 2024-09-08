// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:violet/pages/segment/card_panel.dart';

class SearchMessageRankPageMemory {
  static String latestSearch = '';
  static List<(String, String, int)> rawSearchLists = <(String, String, int)>[];
}

class SearchMessageRankPage extends StatefulWidget {
  const SearchMessageRankPage({super.key});

  @override
  State<SearchMessageRankPage> createState() => _SearchMessageRankPageState();
}

class _SearchMessageRankPageState extends State<SearchMessageRankPage> {
  List<(String, String, int)> searchLists = <(String, String, int)>[];
  TextEditingController text =
      TextEditingController(text: SearchMessageRankPageMemory.latestSearch);

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      if (SearchMessageRankPageMemory.rawSearchLists.isEmpty) {
        const url =
            'https://raw.githubusercontent.com/project-violet/violet-message-search/master/SORT-COMBINE.json';

        var m = jsonDecode((await http.get(url)).body) as Map<String, dynamic>;

        SearchMessageRankPageMemory.rawSearchLists = m.entries
            .map(
                (e) => (e.key, TagTranslate.disassembly(e.key), e.value as int))
            .toList();
      }

      if (text.text != '') {
        searchLists = SearchMessageRankPageMemory.rawSearchLists
            .where((element) =>
                element.$2.contains(TagTranslate.disassembly(text.text)))
            .toList();
        searchLists.sort((x, y) => y.$1.length.compareTo(x.$1.length));
      } else {
        searchLists = SearchMessageRankPageMemory.rawSearchLists.toList();
        searchLists.sort((x, y) => y.$1.length.compareTo(x.$1.length));
      }

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(0),
              itemBuilder: (BuildContext ctxt, int index) {
                var e = searchLists[index];
                return ListTile(
                  title: Text(e.$1),
                  dense: true,
                  onTap: () {
                    Navigator.pop(context, e.$1);
                  },
                );
              },
              itemCount: searchLists.length,
            ),
          ),
          Row(
            children: [
              TextField(
                controller: text,
                onEditingComplete: () async {
                  SearchMessageRankPageMemory.latestSearch = text.text;

                  searchLists = SearchMessageRankPageMemory.rawSearchLists
                      .where((element) => element.$2
                          .contains(TagTranslate.disassembly(text.text)))
                      .toList();
                  searchLists
                      .sort((x, y) => y.$1.length.compareTo(x.$1.length));

                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
