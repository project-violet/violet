// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/component/downloadable.dart';
import 'package:violet/database/user/download.dart';
import 'package:violet/component/downloadable.dart' as violetd;
import 'package:violet/downloader/native_downloader.dart';
import 'package:violet/settings/settings.dart';

class DownloadRoutine {
  DownloadItemModel item;
  Map<String, dynamic> result;
  VoidCallback setStateCallback;
  Downloadable extractor;
  List<violetd.DownloadTask> tasks;

  DownloadRoutine(this.item, this.setStateCallback) {
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

  Future<bool> checkValidUrl() async {
    if (!ExtractorManager.instance.existsExtractor(item.url())) {
      await _setState(8);
      return false;
    }
    return true;
  }

  Future<void> selectExtractor() async {
    extractor = ExtractorManager.instance.getExtractor(item.url());
    result['Extractor'] = extractor.name();
    await _setState(2);
  }

  Future<void> setToStop() async {
    await _setState(6);
  }

  Future<bool> checkLoginRequire() async {
    if (extractor.loginRequire()) {
      if (!extractor.logined()) {
        if (!await extractor.tryLogin()) {
          await _setState(9);
          return true;
        }
      }
    }
    return false;
  }

  Future<void> createTasks({DoubleIntCallback progressCallback}) async {
    try {
      tasks = await extractor.createTask(
        item.url(),
        GeneralDownloadProgress(
          simpleInfoCallback: (info) async {
            result['Info'] = info;
            setStateCallback.call();
          },
          thumbnailCallback: (url, header) async {
            result['Thumbnail'] = url;
            result['ThumbnailHeader'] = header;
            setStateCallback.call();
          },
          progressCallback: progressCallback,
        ),
      );
    } catch (e) {
      _setState(7);
      return;
    }
  }

  Future<bool> checkNothingToDownload() async {
    if (tasks == null || tasks.length == 0) {
      await _setState(11);
      return true;
    }
    return false;
  }

  Future<void> extractFilePath() async {
    var files = tasks
        .map((e) => join(Settings.downloadBasePath,
            e.format.formatting(extractor.defaultFormat())))
        .toList();
    result['Files'] = jsonEncode(files);
    // Extract Super Path
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
    var pp = cp.take(vp).join('/');
    result['Path'] = pp;
    await _updateItem();
  }

  Future<void> appendDownloadTasks({
    VoidCallback completeCallback,
    DoubleCallback downloadCallback,
    VoidStringCallback errorCallback,
  }) async {
    var downloader = await NativeDownloader.getInstance();
    // var downloader = FlutterDonwloadDonwloader.getInstance();
    var basepath = Settings.downloadBasePath;
    if (Settings.useInnerStorage)
      basepath = (await getApplicationDocumentsDirectory()).path;
    await downloader.addTasks(tasks.map((e) {
      e.downloadPath = join(basepath,
          e.format.formatting(extractor.defaultFormat()));

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
