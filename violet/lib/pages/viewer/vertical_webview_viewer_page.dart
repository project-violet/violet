// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';

class VerticalWebviewViewerPage extends StatefulWidget {
  final String getxId;
  const VerticalWebviewViewerPage({
    super.key,
    required this.getxId,
  });

  @override
  State<VerticalWebviewViewerPage> createState() =>
      _VerticalWebviewViewerPageState();
}

class _VerticalWebviewViewerPageState extends State<VerticalWebviewViewerPage> {
  late final ViewerController c;

  late InAppWebViewController webViewController;
  late String beforeScript;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);
    initBeforeScript();
  }

  initBeforeScript() {
    var uris = <String>[];

    if (c.provider.useProvider) {
      for (var i = 0; i < c.provider.uris.length; i++) {
        uris.add('"${c.provider.provider!.getImageUrlSync(i)!}"');
      }
    } else if (c.provider.useFileSystem) {
      for (var i = 0; i < c.provider.uris.length; i++) {
        print(c.provider.uris[i]);
        if (c.provider.uris[i].startsWith('/')) {
          uris.add('"file://${c.provider.uris[i]}"');
        } else {
          uris.add('"file:///${c.provider.uris[i]}"');
        }
      }
    }

    beforeScript = '''Object.defineProperty(window, "imageset", {
                  value: [${uris.join(',')}],
                  writable: false,
                });''';

    print(beforeScript);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36',
              useShouldOverrideUrlLoading: true,
            ),
          ),
          initialUserScripts: UnmodifiableListView([
            UserScript(
              source: beforeScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            )
          ]),
          onWebViewCreated: (controller) async {
            webViewController = controller;

            webViewController.loadData(
                data: await rootBundle.loadString('assets/webview/index.html'),
                baseUrl: Uri.parse('https://hitomi.la/'));
          },
          onLoadStop: (controller, url) async {
            final manifest = jsonDecode(await rootBundle
                .loadString('assets/webview/asset-manifest.json', cache: true));
            final css = '/${manifest['index.css']['file'].toString()}';
            final js = '/${manifest['index.html']['file'].toString()}';

            controller.injectCSSFileFromAsset(
                assetFilePath: 'assets/webview$css');
            controller.injectJavascriptFileFromAsset(
                assetFilePath: 'assets/webview$js');
          },
          onConsoleMessage: (controller, consoleMessage) {
            print(consoleMessage);
          },
          onLoadError: (controller, url, code, message) {
            print(message);
          },
          onLoadHttpError: (controller, url, statusCode, description) {
            print(description);
          },
          onDownloadStartRequest: (controller, downloadStartRequest) {
            print(downloadStartRequest);
          },
          shouldOverrideUrlLoading: (
            controller,
            NavigationAction shouldOverrideUrlLoadingRequest,
          ) async {
            print('shouldOverrideUrlLoading: $shouldOverrideUrlLoadingRequest');
            return NavigationActionPolicy.ALLOW;
          },
        ),
        GestureDetector(
          onTap: (() => c.middleButton()),
        )
      ],
    );
  }
}
