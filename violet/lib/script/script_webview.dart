// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:violet/log/log.dart';
import 'package:violet/script/script_manager.dart';

class ScriptWebView extends StatefulWidget {
  const ScriptWebView({Key? key}) : super(key: key);

  @override
  State<ScriptWebView> createState() => _ScriptWebViewState();
}

class _ScriptWebViewState extends State<ScriptWebView>
    with AutomaticKeepAliveClientMixin<ScriptWebView> {
  @override
  bool get wantKeepAlive => true;

  late HeadlessInAppWebView headlessWebView;
  InAppWebViewController? webViewController;

  Timer? timer;

  String? gg_m;
  String? gg_b;

  @override
  void initState() {
    super.initState();

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: Uri.parse('https://hitomi.la'),
      ),
      onWebViewCreated: (controller) {
        webViewController = controller;

        controller.addJavaScriptHandler(
            handlerName: 'gg',
            callback: (args) {
              gg_m = args[0];
              gg_b = args[1];

              return {};
            });
      },
      onLoadStart: (controller, url) async {
        Future.delayed(const Duration(milliseconds: 300))
            .then((value) => controller.stopLoading());
      },
      onLoadStop: (controller, url) async {
        await controller.evaluateJavascript(source: '''
          var r = "";
          for (var i = 0; i < 4096; i++) {
            r += gg.m(i).toString();
            r += ",";
          }
          console.log(gg);
          window.flutter_inappwebview.callHandler('gg', ...[r, gg.b]);
          ''');

        if (gg_m == null || !(gg_m!.startsWith('0') || gg_m!.startsWith('1'))) {
          Logger.error(
              '[Script Webview] Update Fail!\ngg_m: $gg_m\ngg_b: $gg_b');
          return;
        }

        Logger.info('[Script Webview] Update Sync!');

        await ScriptManager.setV4(gg_m!, gg_b!);
      },
    );

    headlessWebView.run();

    timer = Timer.periodic(const Duration(minutes: 1), timerCallback);
  }

  Future<void> timerCallback(timer) async {
    webViewController?.reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox.shrink();
  }
}
