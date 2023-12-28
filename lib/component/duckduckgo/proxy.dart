import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;
import 'package:http/http.dart' as _http;

class ProxyHttpRequest {
  List<String> hosts = [ 'proxy.myvipwebtools.com' ];
  Map<String,String> cookies = Map<String,String>();

  Future<String> getCSRF(String host) async {
    var res = await http.get('https://www-${host}/',
    );
    while(true){
      if(res?.headers?['location']?.isNotEmpty ?? false){
        res = await http.get(res.headers['location'] ?? '');
      } else {
        break;
      }
    }
    final doc = parse(res.body);
    final csrf = doc.querySelector('input[name=csrf]')?.attributes['value'] ?? '';
    if(csrf.isEmpty){
      Logger.error('csrf is missing');
      throw Error();
    }
    return csrf;
  }

  Future<void> setCookie(String? host,Map<String,String>? headers) async {
    if(host == null){
      throw Error();
    }
    var ck = (cookies[host] ?? '').split(';').where((c) => c.trim().isNotEmpty).join(';');
    if(headers?.isNotEmpty ?? false){
        headers?.forEach((key, value) {
          if(key == 'set-cookie'){
            final setCookie = value.split(',').where((c) => c?.trim()?.split(';')[0]?.contains('=') ?? false);
            if(setCookie == null) return;
            setCookie?.forEach((v) {
              final cookieKeyVal = v.split(';')[0].trim(); // ignores expire etc
              final cookieKey = cookieKeyVal.substring(0,cookieKeyVal.indexOf('=')).trim();
              final cookieVal = cookieKeyVal.substring(cookieKeyVal.indexOf('=') + 1).trim();
              if(cookieVal.isEmpty) return;
              final ck_tmp = ck.split(';').where((c) => c.trim().startsWith('${cookieKey}='));

              if(ck_tmp.isNotEmpty){ // when old cookie is exist
                ck = ck.split(';')
                  .where((c) => c.trim().isNotEmpty)
                  .map((c) {
                    final cKey = c.substring(0,c.indexOf('=')).trim();
                    final cVal = c.substring(c.indexOf('=') + 1).trim();
                    if(cKey != cookieKey) return '${cKey}=${cVal}';
                    // Set new cookie where exist
                    return '${cookieKey}=${cookieVal}';
                  })
                  .join(';');
              } else {
                // Set new cookie where not exist
                var ck_arr = ck.split(';').where((c) => c.trim().isNotEmpty).toList();
                ck_arr.add('${cookieKey}=${cookieVal}');
                ck = ck_arr.join(';');
              }
              ck = ck.split(';').where((c) => c.trim().isNotEmpty).join(';');
            });
          }
        });
      cookies[host] = ck;
    }
  }

  Future<String> _requests(String target,{
    String? host,
    String? csrf,
  }) async {
    if(host == null){
      throw Error();
    }
    final res_requests = await http.post('https://www-${host}/requests',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: 'url=${Uri.encodeComponent((target))}&csrf=${csrf}'
    );
    await setCookie(host, res_requests.headers);
    return res_requests.headers['location'] ?? '';
  }
  Future<void> _cpi(String location,{
    String? host,
  }) async {
    if(host == null){
      throw Error();
    }
    final cpi_url = location;
    if(cpi_url == null){
      Logger.error('cpi_url is null');
      throw Error();
    }
    final res_cpi = await http.get(
      cpi_url,
      headers: {
        'Cookie': cookies[host] ?? ''
      }
    );
    await setCookie(host, res_cpi.headers);
  }
  Future<_http.Response> _get(String target,{
    String? host,
    Map<String,String>? headers
  }) async {
    if(host == null){
      throw Error();
    }
    final target_host = Uri.parse(target).host;
    final target_path = Uri.parse(target).path;
    final target_protocol = target.startsWith('http:') ? 'http' : 'https';
    final __cpo = base64.encode(utf8.encode('${target_protocol}://${target_host}'));
    var target_query = '?';
    Uri.parse(target).queryParameters.forEach((key, value) {
      if(target_query != '?'){
        target_query += '&';
      }
      target_query += '${key}=${Uri.encodeComponent(value)}';
    });
    if(target_query != '?'){
      target_query += '&';
    }
    target_query += '__cpo=${__cpo}';

    var _headers = headers ?? {};
    _headers['Cookie'] = cookies[host] ?? '';
    if(headers?['Cookie']?.isNotEmpty ?? false){
      _headers['Cookie'] = [cookies[host] ?? '', (headers?['Cookie']??'')
        ?.split(';')
        .where((c) => c.trim().isNotEmpty)
        .map((_cKV) {
          final cKV = _cKV.trim();
          final cK = cKV.substring(0,cKV.indexOf('=')).trim();
          final cV = cKV.substring(cKV.indexOf('=') + 1);
          return '${cK}@${target_host}=${cV}';
        }).join(';')].join(';');
    }
    final res = await http.get('https://${host}${target_path}${target_query}',
      headers: _headers
    );
    return res;
  }
  Future<_http.Response> get(String target,{
    String? host,
    Map<String,String>? headers
  }) async {
    final csrf = await getCSRF(host ?? hosts[0]);
    final cpi_url = await _requests(target, host: host, csrf: csrf);
    await _cpi(cpi_url, host: host);
    final res = await _get(target, host: host, headers: headers);
    return res;
  }
}