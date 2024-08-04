// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/downloadable.dart';
import 'package:violet/downloader/isolate_downloader.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });

  test('Test Downloader Isolate', () async {
    var downloader = IsolateDownloader();
    await downloader.init();

    // while (!downloader.isReady()) {}

    await Future.delayed(const Duration(seconds: 1));

    var task = DownloadTask(
      downloadPath: 't1.db',
      url:
          'https://search.naver.com/search.naver?where=nexearch&sm=top_sug.mbk&fbm=1&acr=1&acq=%EC%95%88%EC%B2%A1%EC%88%98+&qdt=0&ie=utf8&query=%EC%95%88%EC%B2%A0%EC%88%98+%EC%A7%80%EC%A7%80%EC%9C%A8',
      headers: {},
    );
    task.taskId = 0;
    // task.startCallback = () => print('start');
    // task.completeCallback = () => print('complete');
    // task.errorCallback = (e) => print(e);
    // task.sizeCallback = (sz) => print('sz $sz');
    // task.downloadCallback = (a) => print('d $a');

    downloader.appendTask(task);

    // downloader.appendTask(DownloadTask(
    //   taskId: 0,
    //   filename: 't2.db',
    //   url:
    //       'https://github.com/violet-dev/sync-data/releases/download/db_1642381015/data.db',
    //   headers: {},
    // ));

    // downloader.appendTask(DownloadTask(
    //   taskId: 0,
    //   filename: 't3.db',
    //   url:
    //       'https://github.com/violet-dev/sync-data/releases/download/db_1642375243/data.db',
    //   headers: {},
    // ));

    await Future.delayed(const Duration(seconds: 10));
    sleep(const Duration(seconds: 10));
  });
}
