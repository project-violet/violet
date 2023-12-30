import 'dart:convert';

import 'package:html/parser.dart';
import 'package:violet/log/log.dart';
import 'package:http/http.dart' as http;

class ProxyHttpRequest {
  String host = 'proxy.myvipwebtools.com';
  Map<String, String> cookies = <String, String>{};

  Future<String> getCSRF(String host) async {
    var res = await http.get(
      Uri.parse('https://www-$host/'),
    );
    while (true) {
      if (res.headers['location']?.isNotEmpty ?? false) {
        res = await http.get(Uri.parse(res.headers['location'] ?? ''));
      } else {
        break;
      }
    }
    final doc = parse(res.body);
    final csrf =
        doc.querySelector('input[name=csrf]')?.attributes['value'] ?? '';
    if (csrf.isEmpty) {
      Logger.error('csrf is missing');
      throw Error();
    }
    return csrf;
  }

  Future<void> setCookie(String? host, Map<String, String>? headers) async {
    if (host == null) {
      throw Error();
    }
    var ck = (cookies[host] ?? '')
        .split(';')
        .where((c) => c.trim().isNotEmpty)
        .join(';');
    if (headers?.isNotEmpty ?? false) {
      headers?.forEach((key, value) {
        if (key == 'set-cookie') {
          final setCookie = value
              .split(',')
              .where((c) => c.trim().split(';')[0].contains('='));
          if (setCookie == null) return;
          setCookie.forEach((v) {
            final cookieKeyVal = v.split(';')[0].trim(); // ignores expire etc
            final cookieKey =
                cookieKeyVal.substring(0, cookieKeyVal.indexOf('=')).trim();
            final cookieVal =
                cookieKeyVal.substring(cookieKeyVal.indexOf('=') + 1).trim();
            if (cookieVal.isEmpty) return;
            final ckTmp = ck
                .split(';')
                .where((c) => c.trim().startsWith('$cookieKey='));

            if (ckTmp.isNotEmpty) {
              // when old cookie is exist
              ck = ck.split(';').where((c) => c.trim().isNotEmpty).map((c) {
                final cKey = c.substring(0, c.indexOf('=')).trim();
                final cVal = c.substring(c.indexOf('=') + 1).trim();
                if (cKey != cookieKey) return '$cKey=$cVal';
                // Set new cookie where exist
                return '$cookieKey=$cookieVal';
              }).join(';');
            } else {
              // Set new cookie where not exist
              var ckArr =
                  ck.split(';').where((c) => c.trim().isNotEmpty).toList();
              ckArr.add('$cookieKey=$cookieVal');
              ck = ckArr.join(';');
            }
            ck = ck.split(';').where((c) => c.trim().isNotEmpty).join(';');
          });
        }
      });
      cookies[host] = ck;
    }
  }

  Future<String> _requests(
    String target, {
    String? csrf,
  }) async {
    if (host == null) {
      throw Error();
    }
    final resRequests = await http.post(
        Uri.parse('https://www-$host/requests'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'url=${Uri.encodeComponent((target))}&csrf=$csrf');
    await setCookie(host, resRequests.headers);
    return resRequests.headers['location'] ?? '';
  }

  Future<void> _cpi(String location) async {
    if (host == null) {
      throw Error();
    }
    final cpiUrl = location;
    if (cpiUrl == null) {
      Logger.error('cpiUrl is null');
      throw Error();
    }
    final resCpi = await http
        .get(Uri.parse(cpiUrl), headers: {'Cookie': cookies[host] ?? ''});
    await setCookie(host, resCpi.headers);
  }

  Future<http.Response> _get(String target,
      {Map<String, String>? headers}) async {
    if (host == null) {
      throw Error();
    }
    final targetHost = Uri.parse(target).host;
    final targetPath = Uri.parse(target).path;
    final targetProtocol = target.startsWith('http:') ? 'http' : 'https';
    final cpo =
        base64.encode(utf8.encode('$targetProtocol://$targetHost'));
    var targetQuery = '?';
    Uri.parse(target).queryParameters.forEach((key, value) {
      if (targetQuery != '?') {
        targetQuery += '&';
      }
      targetQuery += '$key=${Uri.encodeComponent(value)}';
    });
    if (targetQuery != '?') {
      targetQuery += '&';
    }
    targetQuery += '__cpo=$cpo';

    var headersTmp = headers ?? {};
    var cookieStr = headers?['Cookie'] ?? '';
    if (headers?['Cookie']?.isNotEmpty ?? false) {
      cookieStr = cookieStr.split(';').where((e) => e.trim().isNotEmpty).map((cookieKeyVal) {
            final cKV = cookieKeyVal.trim();
            final cK = cKV.substring(0, cKV.indexOf('=')).trim();
            final cV = cKV.substring(cKV.indexOf('=') + 1).trim();
            return '$cK@$targetHost=$cV';
          }).join(';');
    }
    headersTmp['Cookie'] = [(cookieStr), (cookies[host] ?? '')]
        .where((c) => c.trim().isNotEmpty)
        .join(';');
    final res = await http.get(
        Uri.parse('https://$host$targetPath$targetQuery'),
        headers: headersTmp);
    return res;
  }

  Future<http.Response> get(String target,
      {Map<String, String>? headers}) async {
    final csrf = await getCSRF(host);
    final cpiUrl = await _requests(target, csrf: csrf);
    await _cpi(cpiUrl);
    final res = await _get(target, headers: headers);
    return res;
  }
}
