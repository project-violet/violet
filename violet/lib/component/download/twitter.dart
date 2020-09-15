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
  static String csrf;
  static Map<String, dynamic> header;
  static Map<String, dynamic> param;
  static Map<String, dynamic> cookie;

  static Future<void> init() async {
    if (param != null) return;

    csrf = md5
        .convert(utf8.encode(
            (DateTime.now().microsecondsSinceEpoch / 1000000).toString()))
        .toString();
    var hheader = {
      'authorization':
          'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA',
      'x-twitter-client-language': 'en',
      'x-twitter-active-user': 'yes',
      "x-guest-token": null,
      "x-csrf-token": csrf,
      'Origin': 'https://twitter.com',
      'Referer': 'https://twitter.com',
    };
    var url = 'https://api.twitter.com/1.1/guest/activate.json';
    var result = await http.post(url, headers: hheader);
    hheader['x-guest-token'] = jsonDecode(result.body)['guest_token'];
    header = hheader;

    cookie = {
      'ct0': csrf,
      'gt': hheader['x-guest-token'],
    };

    hheader['cookie'] = cookie.entries
            .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
            .join('; ') +
        ';';

    param = {
      "include_profile_interstitial_type": "1",
      "include_blocking": "1",
      "include_blocked_by": "1",
      "include_followed_by": "1",
      "include_want_retweets": "1",
      "include_mute_edge": "1",
      "include_can_dm": "1",
      "include_can_media_tag": "1",
      "skip_status": "1",
      "cards_platform": "Web-12",
      "include_cards": "1",
      "include_composer_source": "true",
      "include_ext_alt_text": "true",
      "include_reply_count": "1",
      "tweet_mode": "extended",
      "include_entities": "true",
      "include_user_entities": "true",
      "include_ext_media_color": "true",
      "include_ext_media_availability": "true",
      "send_error_codes": "true",
      "simple_quoted_tweet": "true",
      "count": "100",
      // "cursor": null,
      "ext": "mediaStats,highlightedLabel,cameraMoment",
      "include_quote_count": "true",
    };
  }

  static Future<dynamic> userByScreenName(String name) async {
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

    return jsonDecode(result.body)['data']['user'];
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

  static Stream<dynamic> pagination(String postfix) async* {
    var params = Map<String, dynamic>.from(param);
    var tweet;
    var cursor;

    while (true) {
      tweet = cursor = null;

      var url = 'https://api.twitter.com/' + postfix;
      url += '?' +
          params.entries
              .map((e) =>
                  '${e.key}=${e.value != null ? Uri.encodeQueryComponent(e.value) : ''}')
              .join('&');
      var res = (await http.get(
        url,
        headers: header,
      ))
          .body;
      var data = jsonDecode(res);

      var instr = data['timeline']['instructions'];

      if (instr == false) break;
      var tweets = data['globalObjects']['tweets'];
      var users = data['globalObjects']['users'];

      for (var entry in instr[0]['addEntries']['entries']) {
        if (entry['entryId'].startsWith('tweet-')) {
          try {
            tweet = tweets[entry['content']['item']['content']['tweet']['id']];
          } catch (e) {
            continue;
          }

          if (tweet == null) continue;

          tweet['user'] = users[tweet['user_id_str']];

          if (tweet.containsKey('retweeted_status_id_str')) {
            var retweet = tweets[tweet['retweeted_status_id_str']];
            if (retweet != null) {
              tweet['author'] = users[retweet['user_id_str']];
            }
          }

          yield tweet;

          if (tweet.containsKey("quoted_status_id_str")) {
            var quoted = tweets[tweet['quoted_status_id_str']];
            if (quoted != null) {
              quoted['author'] = users[quoted['user_id_str']];
              quoted['user'] = tweet['user'];
              quoted['quoted'] = true;
              yield quoted;
            }
          }
        } else if (entry['entryId'].startsWith('cursor-bottom-')) {
          cursor = entry['content']['operation']['cursor'];
          if (!cursor.containsKey('stopOnEmptyResponse')) {
            tweet = true;
          }
          cursor = cursor['value'];
        }
      }

      if (instr.last.containsKey('replaceEntry')) {
        cursor = (instr.last['replaceEntry']['entry']['content']['operation']
            ['cursor']['value']);
      }

      print(cursor);
      print(tweet);

      if (cursor == null || tweet == null) return;

      params['cursor'] = cursor;
    }
  }
}

class TwitterManager extends Downloadable {
  RegExp urlMatcher;

  TwitterManager() {
    urlMatcher = RegExp(
        r'^https?://(www\.|mobile\.)?twitter.com/(?<id>.*?)(/(?<what>\w+)?(/(?<x>.*?)?)?)?$');
  }

  @override
  bool acceptURL(String url) {
    return urlMatcher.stringMatch(url) == url;
  }

  @override
  String defaultFormat() {
    return "%(extractor)s/%(user)s (%(account)s)/%(file)s.%(ext)s";
  }

  @override
  String saveOneFormat() {}

  @override
  String fav() {
    return 'https://abs.twimg.com/responsive-web/client-web/icon-ios.8ea219d5.png';
  }

  @override
  bool loginRequire() {
    return false;
  }

  @override
  bool logined() {
    return false;
  }

  @override
  String name() {
    return 'twitter';
  }

  @override
  Future<void> setSession(String id, String pwd) async {}

  @override
  Future<bool> tryLogin() async {
    return true;
  }

  @override
  bool supportCommunity() {
    return false;
  }

  @override
  bool acceptCommunity(String url) {
    return false;
  }

  @override
  Future<List<DownloadTask>> createTask(
      String url, GeneralDownloadProgress gdp) async {
    var match = urlMatcher.allMatches(url);

    var result = List<DownloadTask>();

    var id = match.first.namedGroup('id');

    await TwitterAPI.init();

    var info = await TwitterAPI.userByScreenName(id);
    var name = info['legacy']['name'];
    var profile = (info['legacy']['profile_image_url_https'] as String)
        .replaceAll('_normal.', '_400x400.');
    var ss = TwitterAPI.pagination('2/timeline/media/${info['rest_id']}.json');
    const retweets = false;
    const replies = false;
    const quoted = false;

    gdp.simpleInfoCallback('$name ($id)');
    gdp.thumbnailCallback(profile, jsonEncode({'Referer': url}));

    var i = 0;

    await ss.forEach((element) {
      if (!retweets && element.containsKey('retweeted_status_id_str')) return;
      if (!replies && element.containsKey('in_reply_to_user_id_str')) return;
      if (!quoted && element.containsKey('quoted')) return;

      // extract twitpic
      // https://github.com/mikf/gallery-dl/blob/2b88c90f6f128fe421e9e2bb25d85e1f798b73ca/gallery_dl/extractor/twitter.py#L62
      if (!element.containsKey('extended_entities')) return;

      for (var media in element['extended_entities']['media']) {
        if (media.containsKey('video_info')) {
          var info = media['video_info']['variants'];
          var ll = (info as List<dynamic>)
              .where((element) => element.containsKey('bitrate'))
              .toList();
          ll.sort((x, y) => y['bitrate'].compareTo(x['bitrate']));

          if (ll[0]['url'].contains('.mp4')) {
            result.add(
              DownloadTask(
                url: ll[0]['url'],
                referer: url,
                format: FileNameFormat(
                  user: name,
                  account: id,
                  filenameWithoutExtension: intToString(i, pad: 3),
                  extension: 'mp4',
                  extractor: 'twitter',
                ),
              ),
            );
            i++;
          }

          // m3u8 is not support ㅠㅠ
        } else if (media.containsKey('media_url_https')) {
          var url = media['media_url_https'] + ':orig';
          result.add(
            DownloadTask(
              url: url,
              referer: url,
              format: FileNameFormat(
                user: name,
                account: id,
                filenameWithoutExtension: intToString(i, pad: 3),
                extension: media['media_url'].split('.').last,
                extractor: 'twitter',
              ),
            ),
          );
          i++;
        } else {
          var url = media['media_url'] + ':orig';
          result.add(
            DownloadTask(
              url: url,
              referer: url,
              format: FileNameFormat(
                user: name,
                account: id,
                filenameWithoutExtension: intToString(i, pad: 3),
                extension: media['media_url'].split('.').last,
                extractor: 'twitter',
              ),
            ),
          );
          i++;
        }
      }
      gdp.progressCallback(result.length, 0);
    });

    result.forEach((element) {
      print(element.url);
    });

    return result;
  }

  // https://stackoverflow.com/questions/15193983/is-there-a-built-in-method-to-pad-a-string
  static String intToString(int i, {int pad: 0}) {
    var str = i.toString();
    var paddingToAdd = pad - str.length;
    return (paddingToAdd > 0)
        ? "${new List.filled(paddingToAdd, '0').join('')}$i"
        : str;
  }

  @override
  String communityName() {
    return null;
  }
}
