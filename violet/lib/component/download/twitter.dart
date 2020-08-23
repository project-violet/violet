// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the Apache-2.0 License.

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/component/downloadable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class TwitterAPI {
  static Future<String> userByScreenName(String name) async {
    var json = {
      "screen_name": name.toLowerCase(),
      "withHighlightedLabel": true
    };
    var result = await http.get(
        'https://api.twitter.com/graphql/-xfUfZsnR_zqjFd-IfrN5A/UserByScreenName?variables=' +
            Uri.encodeFull(jsonEncode(json)),
        headers: {
          'authorization':
              'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA',
        });

    return result.body;
  }

  static Future<String> timeline(String restId) async {
    await http.post('https://api.twitter.com/1.1/jot/client_event.json',
        headers: {
          'authorization':
              'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA',
        },
        body:
            'category=perftown&log=%5B%7B%22description%22%3A%22rweb%3Ainit%3AstorePrepare%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A22%7D%2C%7B%22description%22%3A%22rweb%3Attft%3AperfSupported%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A1%7D%2C%7B%22description%22%3A%22rweb%3Attft%3Aconnect%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A92%7D%2C%7B%22description%22%3A%22rweb%3Attft%3Aprocess%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A0%7D%2C%7B%22description%22%3A%22rweb%3Attft%3Aresponse%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A0%7D%2C%7B%22description%22%3A%22rweb%3Attft%3Ainteractivity%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A401%7D%2C%7B%22description%22%3A%22rweb%3Attfmc%3Aprofile%3Arender%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A1024%2C%22metadata%22%3A%7B%22source%22%3A%22rest%22%7D%7D%2C%7B%22description%22%3A%22rweb%3Attfmc%3Aprofile%3Attfmc%22%2C%22product%22%3A%22rweb%22%2C%22duration_ms%22%3A1116%2C%22metadata%22%3A%7B%22source%22%3A%22rest%22%7D%7D%5D');
    var result = await http.get(
        'https://api.twitter.com/2/timeline/media/$restId.json?include_profile_interstitial_type=1&include_blocking=1&include_blocked_by=1&include_followed_by=1&include_want_retweets=1&include_mute_edge=1&include_can_dm=1&include_can_media_tag=1&skip_status=1&cards_platform=Web-12&include_cards=1&include_ext_alt_text=true&include_quote_count=true&include_reply_count=1&tweet_mode=extended&include_entities=true&include_user_entities=true&include_ext_media_color=true&include_ext_media_availability=true&send_error_codes=true&simple_quoted_tweet=true&count=20&ext=mediaStats%2ChighlightedLabel',
        headers: {
          // 'authorization':
          //     'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA',
          'Host': 'api.twitter.com',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:78.0) Gecko/20100101 Firefox/78.0',
          'Accept': '*/*',
          'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'TE': 'Trailers',
        });

    return result.body;
  }
}
