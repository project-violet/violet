// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Files {
  static Future<List<FileSystemEntity>> dirContents(Directory dir) {
    var files = <FileSystemEntity>[];
    var completer = Completer<List<FileSystemEntity>>();
    var lister = dir.list(recursive: false);
    lister.listen((file) => files.add(file),
        // should also register onError
        onDone: () => completer.complete(files));
    return completer.future;
  }

  static Future<void> enumeratePath(String path) async {
    (await Directory(path).list(recursive: true, followLinks: true).toList())
        .forEach((element) async {
      print(element.path);
      // if (await FileSystemEntity.isDirectory(element.path))
      //   await enumeratePath(element.path);
    });
  }

  static Future<List<String>> enumerate() async {
    var dir = await getApplicationDocumentsDirectory();
    print(dir.path);
    enumeratePath(dir.path);
    // print(await dir.path.list(recursive: true, followLinks: true).toList());
    return null;
  }
}
