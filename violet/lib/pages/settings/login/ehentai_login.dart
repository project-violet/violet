// Source code from
// https://github.com/tommy351/eh-redux/blob/master/lib/screens/login/screen.dart
// https://github.com/tommy351/eh-redux/blob/master/lib/utils/cookie.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

Map<String, String> parseCookies(String cookies) {
  final result = HashMap<String, String>();

  for (final cookie in cookies.split(';')) {
    final index = cookie.indexOf('=');

    if (index > -1) {
      final key = cookie.substring(0, index).trim();
      final value = cookie.substring(index + 1).trim();
      result[key] = value;
    }
  }

  return result;
}

// Input id-pwd login?
// Or cookie?

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _loginUrl = 'https://e-hentai.org/bounce_login.php';

  final _webViewController = Completer<WebViewController>();

  @override
  void initState() {
    super.initState();
    // Enable virtual display.
    if (Platform.isAndroid) WebView.platform = AndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
      ),
      body: WebView(
        initialUrl: _loginUrl,
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) {
          _webViewController.complete(controller);
        },
        onPageFinished: (url) {
          _checkCookie();
        },
      ),
    );
  }

  Future<void> _checkCookie() async {
    final controller = await _webViewController.future;
    final cookieString = jsonDecode(
            await controller.runJavascriptReturningResult('document.cookie'))
        as String;
    final cookies = parseCookies(cookieString);
    developer.log('Get cookies: $cookies');

    if (cookies.containsKey('ipb_member_id') &&
        cookies.containsKey('igneous') &&
        cookies.containsKey('ipb_pass_hash')) {
      // await sessionStore.setSession(cookieString);
      // await _cookieManager.clearCookies();
      Navigator.pop(context, cookieString);
    } else if (cookies.containsKey('ipb_member_id')) {
      controller.loadUrl('https://exhentai.org');
    }
  }
}
