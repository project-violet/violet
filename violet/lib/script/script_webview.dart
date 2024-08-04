// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:violet/log/log.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';

class ScriptWebViewProxy {
  static VoidCallback? reload;
}

class ScriptWebView extends StatefulWidget {
  const ScriptWebView({super.key});

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

  String? ggM;
  String? ggB;

  bool isCurrentReload = false;
  int retryCount = 0;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(minutes: 1), timerCallback);

    // run script readiness probe
    Future.delayed(const Duration(seconds: 10))
        .then((value) => v4FailCheckProbe());

    ScriptWebViewProxy.reload = () => webViewController?.reload();
  }

  Future<void> timerCallback(timer) async {
    webViewController?.reload();
  }

  Future<void> v4FailCheckProbe() async {
    if (ScriptManager.enableV4) return;
    if (Settings.routingRule.first != 'Hitomi' &&
        Settings.routingRule.first != 'Hiyobi') return;

    // showOkDialog(
    //     context,
    //     '내부 스크립트 동기화 로직을 실행할 수 없습니다. https://hitomi.la 에서 정상적인 응답을 받을 수 없었습니다. '
    //     'VPN이나 DPI Bypass Tool을 사용해주시고, 그래도 이 메시지가 계속 표시된다면 개발자에게 알려주세요.');
  }

  bool reloadWaitAlreadyPending = false;
  Future<void> reloadIfScriptNotLoaded() async {
    if (ScriptManager.enableV4) return;

    isCurrentReload = true;
    await webViewController?.reload();
    reloadWaitAlreadyPending = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Visibility(
      visible: false,
      maintainState: true,
      child: SizedBox(
        height: 1,
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: Uri.parse('https://hitomi.la/'),
          ),
          initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                  useOnLoadResource: true,
                  userAgent:
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36')),
          onWebViewCreated: (controller) {
            webViewController = controller;

            controller.addJavaScriptHandler(
                handlerName: 'gg',
                callback: (args) {
                  ggM = args[0];
                  ggB = args[1];

                  return {};
                });
          },
          onLoadResource: (controller, resource) async {
            if (resource.url == null) return;
            if (resource.url!.toString().contains('ltn.hitomi.la/gg.js')) {
              controller.stopLoading();
              doUpdateSync(controller);
            }
          },
          onLoadError: ((controller, url, code, message) {
            // net::ERR_CONNECTION_RESET
            // NSURLErrorDomain -999 (Connection Reset)
            // An SSL error has occurred and a secure connection to the server cannot be made.
            if (code == -6 || code == -999 || code == -1200) {
              if (!ScriptManager.enableV4 && !reloadWaitAlreadyPending) {
                reloadWaitAlreadyPending = true;
                Future.delayed(const Duration(seconds: 1))
                    .then((value) => reloadIfScriptNotLoaded());
              }

              return;
            }

            Logger.error('[Script Webview] Error $code\n$message');
          }),
          onLoadHttpError: (controller, url, statusCode, description) {
            if (!(url.toString() == 'https://hitomi.la' ||
                url.toString() == 'https://hitomi.la/')) return;

            if (statusCode >= 500) {
              isCurrentReload = true;
              if (retryCount > 10) {
                Logger.error('[Script Viewer] Many Retry');
                return;
              }
              controller.reload();
              retryCount++;
              Logger.warning('[Script Viewer] Retry ($statusCode)');
              return;
            }

            Logger.error(
                '[Script Webview] Http Error $statusCode\n$description');
          },
          onLoadStop: (controller, url) async {
            if (isCurrentReload) {
              isCurrentReload = false;
              return;
            }

            retryCount = 0;

            doUpdateSync(controller);
          },
        ),
      ),
    );
  }

  doUpdateSync(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
              var r = "";
              for (var i = 0; i < 4096; i++) {
                r += gg.m(i).toString();
                r += ",";
              }
              console.log(gg);
              window.flutter_inappwebview.callHandler('gg', ...[r, gg.b]);
              ''');

    if (ggM == null || !(ggM!.startsWith('0') || ggM!.startsWith('1'))) {
      Logger.error('[Script Webview] Update Fail!\ngg_m: $ggM\ngg_b: $ggB');
      return;
    }

    print(ggB);

    await ScriptManager.setV4(ggM!, ggB!);
  }
}
