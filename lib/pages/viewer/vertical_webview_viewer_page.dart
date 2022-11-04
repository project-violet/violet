import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:violet/pages/viewer/viewer_controller.dart';

class VerticalWebviewViewerPage extends StatefulWidget {
  final String getxId;
  const VerticalWebviewViewerPage({
    Key? key,
    required this.getxId,
  }) : super(key: key);

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

    for (var i = 0; i < c.provider.uris.length; i++) {
      uris.add('"${c.provider.provider!.getImageUrlSync(i)!}"');
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
          initialFile: 'assets/webview/index.html',
          onWebViewCreated: (controller) {
            webViewController = controller;

            // webViewController.loadData(
            //     data: body, baseUrl: Uri.parse('https://hitomi.la/'));

            // webViewController.loadFile(
            //     assetFilePath: 'assets/webview/index.html');

            // webViewController.loadUrl(
            //     urlRequest: URLRequest(
            //         url: Uri(scheme: 'file', path: rootBundle.load(key))));
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
