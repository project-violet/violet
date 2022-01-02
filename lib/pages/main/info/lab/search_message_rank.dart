// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/pages/segment/card_panel.dart';

class SearchMessageRankPage extends StatefulWidget {
  @override
  _SearchMessageRankPageState createState() => _SearchMessageRankPageState();
}

class _SearchMessageRankPageState extends State<SearchMessageRankPage> {
  List<Tuple3<String, String, int>> rawSearchLists;
  List<Tuple3<String, String, int>> searchLists;
  TextEditingController text = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      const url =
          "https://raw.githubusercontent.com/project-violet/violet-message-search/master/SORT-COMBINE.json";

      var m = jsonDecode((await http.get(Uri.parse(url))).body)
          as Map<String, dynamic>;

      rawSearchLists = m.entries
          .map((e) => Tuple3<String, String, int>(
              e.key, TagTranslate.disassembly(e.key), e.value as int))
          .toList();

      searchLists = rawSearchLists.toList();
      searchLists.sort((x, y) => y.item1.length.compareTo(x.item1.length));

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
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(0),
              itemBuilder: (BuildContext ctxt, int index) {
                var e = searchLists[index];
                return ListTile(
                  title: Text(e.item1),
                  dense: true,
                  onTap: () {
                    Navigator.pop(context, e.item1);
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
                  searchLists = rawSearchLists
                      .where((element) => element.item2
                          .contains(TagTranslate.disassembly(text.text)))
                      .toList();
                  searchLists
                      .sort((x, y) => y.item1.length.compareTo(x.item1.length));

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
