import 'package:flutter/cupertino.dart';
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
  late String body;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);

    loadBody();
  }

  loadBody() async {
    var body = '''
    <style> 
      img {
        width: 100%;
        padding: 0;
        margin: 0;
        display: block;
      }
    </style>
    ''';
    for (var i = 0; i < c.provider.uris.length; i++) {
      body += '<img src="${await c.provider.provider!.getImageUrl(i)}"/>\n';
    }
    print(body);
    this.body = body;
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
          onWebViewCreated: (controller) {
            webViewController = controller;

            webViewController.loadData(
                data: body, baseUrl: Uri.parse('https://hitomi.la/'));
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
