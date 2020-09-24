// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/database/query.dart';

abstract class VioletImageProvider {
  int length();
  Future<String> getThumbnailUrl();
  Future<List<String>> getSmallImagesUrl();
  Future<String> getImageUrl(int page);
  Future<Map<String, String>> getHeader(int page);
}
