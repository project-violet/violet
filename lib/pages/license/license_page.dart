// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class LicensePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: Markdown(
            data:
                'https://raw.githubusercontent.com/project-violet/violet-public/master/LICENSE.md'));
  }
}
