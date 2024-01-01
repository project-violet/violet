// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:tuple/tuple.dart';

class NHentaiManager {
  // [Thumbnail Image], [Big Thumbnails] [Image List]
  static Future<Tuple3<List<String>, List<String>, List<String>>> getImageList(
      String id, int pageCount) async {
    var bt = List<String>.generate(pageCount,
        (index) => 'https://t.nhentai.net/galleries/$id/${index + 1}t.jpg');
    var il = List<String>.generate(pageCount,
        (index) => 'https://i.nhentai.net/galleries/$id/${index + 1}.jpg');

    var ti = 'https://t.nhentai.net/galleries/$id/cover.jpg';
    var tis = <String>[];
    tis.add(ti);

    return Tuple3<List<String>, List<String>, List<String>>(tis, bt, il);
  }
}
