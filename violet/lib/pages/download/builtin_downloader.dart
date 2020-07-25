// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:chunked_stream/chunked_stream.dart';
import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:synchronized/synchronized.dart' as sync;
import 'package:violet/component/downloadable.dart' as violetd;

class BuiltinDownloader {
  static const int maxDownloadCount = 2;
  static const int maxDownloadFileCount = 24;

  int _curDownloadCount = 0;
  int _curDonwloadFileCount = 0;

  sync.Lock lock = sync.Lock();
  Queue<violetd.DownloadTask> tasks = Queue<violetd.DownloadTask>();
  List<SendPort> send = List<SendPort>();
  List<ReceivePort> receive = List<ReceivePort>();
  List<violetd.DownloadTask> allocatedTask = List<violetd.DownloadTask>();

  Future<void> _init() async {
    for (int i = 0; i < maxDownloadFileCount; i++) {
      var sendrp = ReceivePort();
      var receivePort = ReceivePort();
      await Isolate.spawn(
          remoteThreadHandler, [i, sendrp.sendPort, receivePort.sendPort]);
      send.add(await sendrp.first);
      receive.add(receivePort);
      receivePort.listen(messageReceive);
      allocatedTask.add(null);
      print(i);
    }
  }

  static BuiltinDownloader _instance;

  static Future<BuiltinDownloader> getInstance() async {
    if (_instance == null) {
      _instance = BuiltinDownloader();
      await _instance._init();
    }
    return _instance;
  }

  bool hasDownloadSlot() {
    return _curDownloadCount < maxDownloadCount;
  }

  Future<bool> ensureDownload() async {
    var succ = false;
    await lock.synchronized(() {
      if (hasDownloadSlot()) {
        _curDownloadCount++;
        succ = true;
      }
    });
    return succ;
  }

  Future<void> returnDownload() async {
    await lock.synchronized(() {
      _curDownloadCount--;
    });
  }

  Future<void> addTask(violetd.DownloadTask task) async {
    await lock.synchronized(() {
      tasks.add(task);
    });
  }

  Future<void> addTasks(List<violetd.DownloadTask> task) async {
    await lock.synchronized(() {
      tasks.addAll(task);
    });
    await notify();
  }

  Future<void> notify() async {
    if (_curDonwloadFileCount == maxDownloadFileCount) return;
    if (tasks.length == 0) return;

    await lock.synchronized(() {
      if (_curDonwloadFileCount == maxDownloadFileCount) return;
      if (tasks.length == 0) return;

      for (int i = 0; i < maxDownloadFileCount; i++) {
        if (allocatedTask[i] == null) {
          if (tasks.length == 0) return;
          allocatedTask[i] = tasks.removeFirst();
          var header = Map<String, String>();
          header['Referer'] = allocatedTask[i].referer;
          header['Accept'] = allocatedTask[i].accept;
          header['User-Agent'] = allocatedTask[i].userAgent;
          if (allocatedTask[i].headers != null) {
            allocatedTask[i].headers.entries.forEach((element) {
              header[element.key] = element.value;
            });
          }
          allocatedTask[i].startCallback.call();
          send[i].send([
            allocatedTask[i].url,
            allocatedTask[i].downloadPath,
            header,
          ]);
          _curDonwloadFileCount++;
        }
      }
    });
  }

  void messageReceive(dynamic object) async {
    var index = object[0] as int;
    var tt = object[1] as int;
    switch (tt) {
      case 0:
        var task = allocatedTask[index];
        allocatedTask[index] = null;
        _curDonwloadFileCount--;
        await notify();
        task.completeCallback();
        break;

      case 1:
        allocatedTask[index].sizeCallback(object[2] as double);
        break;

      case 2:
        allocatedTask[index].downloadCallback(object[2] as double);
        break;

      case 3:
        var task = allocatedTask[index];
        allocatedTask[index] = null;
        _curDonwloadFileCount--;
        await notify();
        task.errorCallback(object[2] as String);
        break;
    }
  }

  static void remoteThreadHandler(List argv) async {
    var index = argv[0] as int;
    var receive = new ReceivePort();
    var send = argv[1] as SendPort;
    send.send(receive.sendPort);
    send = argv[2] as SendPort;

    receive.listen((message) async {
      var url = message[0] as String;
      var downloadPath = message[1] as String;
      var headers = message[2] as Map<String, String>;

      Dio dio = Dio();
      int prev = 0;
      int _1mb = 1024 * 1024;
      int _nu = 0;
      int latest = 0;
      int atotal = 0;

      try {
        dio.options.headers = headers;
        bool once = false;
        await dio.download(url, downloadPath, onReceiveProgress: (rec, total) {
          if (!once) {
            send.send([index, 1, total * 1.0]);
            atotal = total;
            once = true;
          }

          _nu += rec - latest;
          latest = rec;
          if (_nu <= _1mb) return;

          send.send([index, 2, (rec - prev) * 1.0]);
          prev = rec;
        });

        send.send([index, 2, (atotal - prev) * 1.0]);

        // Complete
        send.send([index, 0]);
      } catch (e) {
        // error
        send.send([index, 3, e.toString()]);
      }
    });
  }

  static void remoteThreadHandler2(List argv) async {
    var index = argv[0] as int;
    var receive = new ReceivePort();
    var send = argv[1] as SendPort;
    var buffer = List<int>(65535);
    send.send(receive.sendPort);
    send = argv[2] as SendPort;

    receive.listen((message) async {
      var url = message[0] as String;
      var downloadPath = message[1] as String;
      var headers = message[2] as Map<String, String>;

      int prev = 0;
      int _1mb = 1024 * 1024;
      int _nu = 0;
      int latest = 0;
      int atotal = 0;

      try {
        bool once = false;
        final file = File(downloadPath);
        file.createSync(recursive: true);

        IOSink sink = file.openWrite(mode: FileMode.write);
        var client = new HttpClient();
        var request = await client.getUrl(Uri.parse(url));
        headers.entries.map((e) => request.headers.add(e.key, e.value));
        var response = await request.close();

        send.send([index, 1, response.contentLength * 1.0]);

        var reader = ChunkedStreamIterator(response);

        while (true) {
          var data = await reader.read(1024 * 512);
          if (data.length < 0) break;
          sink.add(data);
        }

        // await sink.addStream(response);

        // response.listen((event) {
        //   sink.add(event);
        // });

        // final doubler =
        //     new StreamTransformer.fromHandlers(handleData: (data, sink) {
        //   sink.add(data);
        // });

        // await sink.addStream(response);

        await sink.flush();
        await sink.close();
        await file.length();
        send.send([index, 2, (atotal - prev) * 1.0]);

        // Complete
        send.send([index, 0]);
      } catch (e) {
        // error
        send.send([index, 3, e.toString()]);
      }
    });
  }
}
