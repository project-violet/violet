// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/component/downloadable.dart' as violetd;
import 'package:violet/component/downloadable.dart';
import 'package:violet/component/hentai_download_manager.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/downloader/isolate_downloader.dart';
import 'package:violet/settings/path.dart';
import 'package:violet/settings/settings.dart';

class DownloadRoutine {
  DownloadItemModel item;
  late Map<String, dynamic> result;
  VoidCallback setStateCallback;
  VoidCallback thumbnailCallback;
  List<violetd.DownloadTask>? tasks;

  DownloadRoutine(this.item, this.setStateCallback, this.thumbnailCallback) {
    result = Map<String, dynamic>.from(item.result);
  }

  Future<bool> checkValidState() async {
    if (item.state() != 1) {
      if (item.state() == 2 || item.state() == 3) {
        await _setState(6);
      }
      return false;
    }
    return true;
  }

  Future<void> selectExtractor() async {
    await _setState(2);
  }

  Future<void> setToStop() async {
    await _setState(6);
  }

  Future<void> createTasks(
      {required DoubleIntCallback progressCallback}) async {
    try {
      final generalDownloadProgress = GeneralDownloadProgress(
        simpleInfoCallback: (info) async {
          result['Info'] = info;
          setStateCallback.call();
        },
        thumbnailCallback: (url, header) async {
          result['Thumbnail'] = url;
          result['ThumbnailHeader'] = header;
          thumbnailCallback.call();
        },
        progressCallback: progressCallback,
      );

      if (item.queryResult != null) {
        tasks =
            await HentaiDonwloadManager.instance().createTaskFromQueryResult(
          item.queryResult!,
          generalDownloadProgress,
        );
      } else {
        tasks = await HentaiDonwloadManager.instance().createTask(
          item.url(),
          generalDownloadProgress,
        );
      }
    } catch (e) {
      _setState(7);
      return;
    }
  }

  Future<bool> checkNothingToDownload() async {
    if (tasks == null || tasks!.isEmpty) {
      await _setState(11);
      return true;
    }
    return false;
  }

  Future<void> extractFilePath() async {
    final inner = (await DefaultPathProvider.getDocumentsDirectory());
    final files = tasks!
        .map((e) => join(
            Settings.useInnerStorage ? inner : Settings.downloadBasePath,
            e.format!
                .formatting(HentaiDonwloadManager.instance().defaultFormat())))
        .toList();
    result['Files'] = jsonEncode(files);
    result['Path'] = _extractSuperPath(files);
    await _updateItem();
  }

  String _extractSuperPath(List<String> files) {
    var cp = dirname(files[0]).split('/');
    var vp = cp.length;
    for (int i = 1; i < files.length; i++) {
      var tp = dirname(files[i]).split('/');
      for (int i = 0; i < vp; i++) {
        if (cp[i] != tp[i]) {
          vp = i;
          break;
        }
      }
    }
    return cp.take(vp).join('/');
  }

  Future<void> appendDownloadTasks({
    required VoidCallback completeCallback,
    required DoubleCallback downloadCallback,
    required VoidStringCallback errorCallback,
  }) async {
    final downloader = await IsolateDownloader.getInstance();
    var basepath = Settings.downloadBasePath;

    if (Settings.useInnerStorage) {
      basepath = (await DefaultPathProvider.getDocumentsDirectory());
    }

    downloader.appendTasks(tasks!.map((e) {
      e.downloadPath = join(
          basepath,
          e.format!
              .formatting(HentaiDonwloadManager.instance().defaultFormat()));

      e.startCallback = () {};
      e.completeCallback = completeCallback;

      e.sizeCallback = (byte) {};
      e.downloadCallback = downloadCallback;

      e.errorCallback = errorCallback;

      return e;
    }).toList());

    await _setState(3);
  }

  Future<List<int>> checkDownloadFiles() async {
    var basepath = Settings.downloadBasePath;

    if (Settings.useInnerStorage) {
      basepath = (await DefaultPathProvider.getDocumentsDirectory());
    }

    final filenames = tasks!
        .map((e) => join(
            basepath,
            e.format!
                .formatting(HentaiDonwloadManager.instance().defaultFormat())))
        .toList();

    final invalidIndex = <int>[];

    for (var i = 0; i < filenames.length; i++) {
      var file = File(filenames[i]);

      if (!await file.exists()) {
        invalidIndex.add(i);
        continue;
      }

      if (await file.length() < 5) {
        invalidIndex.add(i);
        await file.delete();
        continue;
      }
    }

    return invalidIndex;
  }

  Future<void> retryInvalidDownloadFiles(
    List<int> invalidIndex, {
    required VoidCallback completeCallback,
    required DoubleCallback downloadCallback,
    required VoidStringCallback errorCallback,
  }) async {
    final downloader = await IsolateDownloader.getInstance();
    var basepath = Settings.downloadBasePath;

    if (Settings.useInnerStorage) {
      basepath = (await DefaultPathProvider.getDocumentsDirectory());
    }

    downloader.appendTasks(invalidIndex.map((e) => tasks![e]).map((e) {
      e.downloadPath = join(
          basepath,
          e.format!
              .formatting(HentaiDonwloadManager.instance().defaultFormat()));

      e.startCallback = () {};
      e.completeCallback = completeCallback;

      e.sizeCallback = (byte) {};
      e.downloadCallback = downloadCallback;

      e.errorCallback = errorCallback;

      return e;
    }).toList());

    await _setState(3);
  }

  Future<void> setDownloadComplete() async {
    (await Download.getInstance())
        .appendDownloaded(int.parse(item.url()), item);
    await _setState(0);
  }

  Future<void> _setState(int state) async {
    result['State'] = state;
    await _updateItem();
  }

  Future<void> _updateItem() async {
    item.result = result;
    await item.update();
    setStateCallback.call();
  }
}
