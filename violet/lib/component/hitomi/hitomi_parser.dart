// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:violet/database/query.dart';

class HitomiParser {
  // Extract only title
  static Future<String> parseGalleryBlock(String html) async {
    var doc = (await compute(parse, html)).querySelector('div');

    var title = doc.querySelector('h1').text.trim();

    return title;
  }
}
