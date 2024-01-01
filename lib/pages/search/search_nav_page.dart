// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/pages/segment/card_panel.dart';

class SearchNavPage extends StatefulWidget {
  const SearchNavPage({super.key});

  @override
  State<SearchNavPage> createState() => _SearchNavPageState();
}

class _SearchNavPageState extends State<SearchNavPage> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      child: Container(),
    );
  }
}
