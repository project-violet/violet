// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:synchronized/synchronized.dart' as sync;
import 'package:violet/component/downloadable.dart' as violetd;

class FlutterDonwloadDonwloader {
  static FlutterDonwloadDonwloader _instance;
  sync.Lock lock = sync.Lock();
  List<violetd.DownloadTask> tasks = List<violetd.DownloadTask>();
  ReceivePort _port = ReceivePort();
  Map<String, int> id = Map<String, int>();
  Queue<violetd.DownloadTask> queue = Queue<violetd.DownloadTask>();

  FlutterDonwloadDonwloader() {
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port1');
    _port.listen(receive);
    FlutterDownloader.registerCallback(downloadCallback);
  }

  static FlutterDonwloadDonwloader getInstance() {
    if (_instance == null) {
      _instance = FlutterDonwloadDonwloader();
    }
    return _instance;
  }

  Future<void> addTask(violetd.DownloadTask task) async {
    tasks.add(task);
    var header = Map<String, String>();
    header['Referer'] = task.referer;
    header['Accept'] = task.accept;
    header['User-Agent'] = task.userAgent;
    if (task.headers != null) {
      task.headers.entries.forEach((element) {
        header[element.key] = element.value;
      });
    }
    var id = await FlutterDownloader.enqueue(
      url: task.url,
      savedDir:
          task.downloadPath.substring(0, task.downloadPath.lastIndexOf('/')),
      fileName: task.downloadPath.split('/').last,
      headers: header,
      showNotification: false,
      openFileFromNotification: false,
    );
    this.id[id] = tasks.length - 1;
    await notify();
  }

  Future<void> addTasks(List<violetd.DownloadTask> tasks) async {
    // await lock.synchronized(() {
    //   tasks.addAll(task);
    // });
    // await notify();
    for (int i = 0; i < tasks.length; i++) {
      var task = tasks[i];

      var dir = Directory(
          task.downloadPath.substring(0, task.downloadPath.lastIndexOf('/')));
      if (!await dir.exists()) await dir.create();
      queue.add(task);
    }

    await notify();
  }

  int nowSize = 0;

  Future<void> notify() async {
    await lock.synchronized(() async {
      if (queue.length == 0) return;
      for (; nowSize < 16; nowSize++) {
        var task = queue.removeFirst();
        var header = Map<String, String>();
        header['Referer'] = task.referer;
        header['Accept'] = task.accept;
        header['User-Agent'] = task.userAgent;
        if (task.headers != null) {
          task.headers.entries.forEach((element) {
            header[element.key] = element.value;
          });
        }

        this.tasks.add(task);
        var id = await FlutterDownloader.enqueue(
          url: task.url,
          savedDir: task.downloadPath
              .substring(0, task.downloadPath.lastIndexOf('/')),
          fileName: task.downloadPath.split('/').last,
          headers: header,
          showNotification: false,
          openFileFromNotification: false,
        );
        this.id[id] = this.tasks.length - 1;
      }
    });
  }

  void receive(dynamic data) async {
    String id = data[0];
    DownloadTaskStatus status = data[1];
    int progress = data[2];

    if (status == DownloadTaskStatus.enqueued) {
      tasks[this.id[id]].startCallback();
    }
    if (status == DownloadTaskStatus.complete) {
      tasks[this.id[id]].completeCallback();
      nowSize--;
      await notify();
    }
    if (status == DownloadTaskStatus.failed) {
      tasks[this.id[id]].errorCallback('error');
      nowSize--;
      await notify();
    }
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port1');
    send.send([id, status, progress]);
  }
}
