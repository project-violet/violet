// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:html/parser.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/duckduckgo/search.dart';
import 'package:violet/log/log.dart';
import 'package:violet/network/wrapper.dart' as http;

class EHSession {
  static Map<String, String> exEhashs = <String, String>{};
  static Map<String, String> ehEhashs = <String, String>{};
  static Map<String, bool> ehashLock = <String, bool>{};
  static Map<String, bool> ehEhashCouldNotFound = <String, bool>{};
  static Map<String, bool> exEhashCouldNotFound = <String, bool>{};
  static EHSession? tryLogin(String id, String pass) {
    return null;
  }

  static Future<String> requestString(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('eh_cookies');
    return (await http.get(url, headers: {'Cookie': cookie ?? ''})).body;
  }

  static Future<String?> requestRedirect(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('eh_cookies');
    Request req = Request('Get', Uri.parse(url))..followRedirects = false;
    req.headers['Cookie'] = cookie ?? '';
    Client baseClient = Client();
    StreamedResponse response = await baseClient.send(req);
    return response.headers['location'];
  }

  static Future<String> postComment(String url, String content) async {
    final prefs = await SharedPreferences.getInstance();
    var cookie = prefs.getString('eh_cookies');
    return (await http.post(url,
            headers: {'Cookie': cookie ?? ''},
            body: 'commenttext_new=${Uri.encodeFull(content)}'))
        .body;
  }

  static Future<String> getEhashByIdFromEhentai(String id) async {
    if(ehEhashCouldNotFound[id] == true){
      throw 'EHASH_NOT_FOUND e-hentai.org $id';
    }
    if(ehashLock[id] == true){
      bool isLocked = true;
      do {
        await Future.delayed(Duration.zero,() {
          isLocked = ehashLock[id] ?? false;
        });
      } while (isLocked == true);
      return await EHSession.getEhashByIdFromEhentai(id);
      // throw 'EHASH_LOCK e-hentai.org $id';
    }
    if(ehEhashs[id]?.isNotEmpty ?? false){
      return ehEhashs[id]!;
    }
    try {
      final listHtml = await EHSession.requestString(
          'https://e-hentai.org/?next=${(int.parse(id) + 1)}');
      final doc = parse(listHtml);
      final tmpUrl =
          doc.querySelector('a[href*="/g/$id"]')?.attributes['href'] ?? '';
      final tmpEhash = Uri.parse(tmpUrl)
          .path
          .split('/')
          .lastWhere((e) => e.trim().isNotEmpty)
          .trim();
      if (tmpEhash.isNotEmpty) {
        ehEhashCouldNotFound[id] = false;
        ehEhashs[id] = tmpEhash;
        return tmpEhash;
      }
    } catch(e,st){
      Logger.error('[getEhashByIdFromEhentai] $e\n'
        '$st');
    } finally {
      ehashLock[id] = false;
    }
    throw 'EHASH_NOT_FOUND e-hentai.org $id';
  }
  static Future<String> getEhashByIdFromExhentai(String id) async {
    if(exEhashCouldNotFound[id] == true){
      throw 'EHASH_NOT_FOUND exhentai.org $id';
    }
    if(ehEhashs[id]?.isNotEmpty ?? false){
      return ehEhashs[id]!;
    }
    if(exEhashs[id]?.isNotEmpty ?? false){
      return exEhashs[id]!;
    }
    if(ehashLock[id] == true){
      bool isLocked = true;
      do {
        await Future.delayed(Duration.zero,() {
          isLocked = ehashLock[id] ?? false;
        });
      } while (isLocked == true);
      return await EHSession.getEhashByIdFromExhentai(id);
      // throw 'EHASH_LOCK exhentai.org $id';
    }
    ehashLock[id] = true;
    try{
      final listHtml = await EHSession.requestString(
          'https://exhentai.org/?next=${(int.parse(id) + 1)}');
      final doc = parse(listHtml);
      final tmpUrl =
          doc.querySelector('a[href*="/g/$id"]')?.attributes['href'] ?? '';
      final tmpEhash = Uri.parse(tmpUrl)
          .path
          .split('/')
          .lastWhere((e) => e.trim().isNotEmpty)
          .trim();
      if (tmpEhash.isNotEmpty) {
        exEhashCouldNotFound[id] = false;
        exEhashs[id] = tmpEhash;
        return tmpEhash;
      }
    }catch(e,st){
      Logger.error('[getEhashByIdFromExhentai] $e\n'
        '$st');
    } finally {
      ehashLock[id] = false;
    }
    throw 'EHASH_NOT_FOUND exhentai.org $id';
  }
  static Future<String> getEhashByIdFromDuckduckgo(String id) async {
    try{
      if(ehashLock[id] == true){
        bool isLocked = true;
        do {
          await Future.delayed(Duration.zero,() {
            isLocked = ehashLock[id] ?? false;
          });
        } while (isLocked == true);
        return await EHSession.getEhashByIdFromDuckduckgo(id);
        // throw 'EHASH_LOCK duckduckgo.com $id';
      }
      if(ehEhashs[id]?.isNotEmpty ?? false){
        return ehEhashs[id]!;
      }
      if(exEhashs[id]?.isNotEmpty ?? false){
        return exEhashs[id]!;
      }
      final ddg = DuckDuckGoSearch();
      final searchRes =
          await ddg.searchProxied('site:e-hentai.org in-url:/g/$id/');
      var foundEncodedUrls = parse(searchRes.body)
          .querySelectorAll('a[href*="${Uri.encodeComponent('/g/$id')}"]')
          .map((encodedUrl) => encodedUrl.attributes['href']?.trim() ?? '')
          .where((encodedUrl) => encodedUrl.trim().isNotEmpty);
      var url = '';
      foundEncodedUrls
          .map((url) => Uri.parse(url).queryParameters)
          .forEach((element) {
        element.forEach((key, value) {
          if (value.contains('/g/$id/')) {
            url = value;
          }
        });
      });
      exEhashs[id] = url.split('/').lastWhere((e) => e.isNotEmpty);
      ehEhashs[id] = url.split('/').lastWhere((e) => e.isNotEmpty);
      if(exEhashs[id]?.isEmpty ?? true){
        throw 'EHASH_NOT_FOUND duckduckgo.com $id';
      }
      ehEhashCouldNotFound[id] = false;
      exEhashCouldNotFound[id] = false;
      ehashLock[id] = false;
      return exEhashs[id]!;
    } catch(e,st){
      Logger.error('[getEhashByIdFromDuckduckgo] $e\n'
      '$st');
    } finally {
      ehashLock[id] = false;
    }
    throw 'EHASH_NOT_FOUND duckduckgo.com $id';
  }

  static Future<String> getEhashById(String id) async {
    try {
      return await getEhashByIdFromDuckduckgo(id);
    } catch(_){
      try {
        return await getEhashByIdFromEhentai(id);
      } catch(_){
        return await getEhashByIdFromExhentai(id);
      }
    }
  }
}
