// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/component/hentai.dart';
// import 'package:violet/component/download/hitomi.dart';
// import 'package:http/http.dart' as http;

// import 'package:violet/main.dart';
// import 'package:violet/component/download/twitter.dart';
// import 'package:violet/component/downloadable.dart';
// import 'package:violet/component/eh/eh_parser.dart';
// import 'package:violet/component/hentai.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/ldi.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/database/database.dart';
import 'package:violet/script/parse_tree.dart';
import 'package:violet/script/script_lexer.dart';
import 'package:violet/script/script_parser.dart';
import 'package:violet/script/script_runner.dart';

import 'json/json_lexer.dart';
import 'json/json_parser.dart';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:violet/database/query.dart';
// import 'package:violet/server/community/session.dart';
// import 'package:violet/server/violet.dart';

void main() {
  sqfliteFfiInit();
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();
  });
  /*test("Test Translated", () async {
    await TagTranslate.init();
    // print(
    //     TagTranslate.containsFuzzingTotal('그날그쪽에핀꽃은아무도모른다').reversed.toList());
    // print(TagTranslate.containsFuzzingTotal('잃어버린 시간을 찾아서').reversed.toList());

    // print(TagTranslate.disassembly('몸부안꽉'));
    // print(await HitomiManager.queryAutoComplete('ahaqndks', true));
    // print(await HitomiManager.queryAutoComplete('아카메가', true));
    // print(await HitomiManager.queryAutoComplete('청춘', true));

    // print(TagTranslate.disassembly('청춘'));
    // print(TagTranslate.disassembly('변덕스러운 오렌지로드'));

    // print((await HitomiManager.queryAutoCompleteFuzzy(
    //         'series:rmskfqhsrmRhcdmldlfmadmsdnflsdkwlrahfmsek', true))
    //     .reversed
    //     .toList());

    /*
        1 / 1776797.99999999999 = 5.62810178759769e-7
        0.18252033135788304, 0.7597160238656215
        0.23004168863089614, 0.6122759989812039
        0.8733094986747413, 0.5706262830644846
        0.6771197845065492, 0.07887166761793196
        0.8045709413255848, 0.039405416464433074
        0.7417691972638805, 0.026160068344324827
        0.04097878336980343, 0.020333899985416792
        0.169538690983717, 0.007062486372888088
        0.6507346370613472, 0.0016613274347037077
        0.8212334776782597, 0.0006717764772474766
        0.5090848821041828, 0.0003529477398842573
        0.8245208515776348, 0.0000414382666349411
        0.9242418102724604, 0.000008487142622470856
        0.7421006777396224, 0.000006405636668205261
        0.2055849905302829, 0.0000042255851440131664
        0.5591778018667917, 0.0000013116514310240746
        0.3167681413420316, 2.390006557106972e-7
        0.6141795522057886, 1.4062970876693726e-7
        0.5123193520029123, 7.066410034894943e-8
        0.8105479632462665, 3.9814040064811707e-8
        0.8805170874798425, 9.080395102500916e-9

        select 
        Id * 5.62810178759769e-7 - ROUND(Id * 5.62810178759769e-7 - 0.5, 0) ,
        Id from HitomiColumnModel order by
        Id * 5.62810178759769e-7 - ROUND(Id * 5.62810178759769e-7 - 0.5, 0) 
        LIMIT 100;
        -- 

        select 
        Id * 0.8805170874798425 - ROUND(Id * 0.8805170874798425 - 0.5, 0) ,
        Id from HitomiColumnModel order by
        Id * 0.8805170874798425 - ROUND(Id * 0.8805170874798425 - 0.5, 0) 
        LIMIT 100;
        --

    */

    const t = 1776798;
    var m = 99999999999.0;
    var x = 0.0;
    print('1 / 1776797.99999999999 = ' + (1 / 1776797.99999999999).toString());
    for (int i = 1; i < 100000000; i++) {
      final xx = Random().nextDouble();
      final y = (t * xx) - (t * xx).floor();
      if (y < m) {
        m = y;
        x = xx;
        print('$x, $m');
      }s
    }
  });*/

  test('test search', () async {
    await LDI.init();
    // final queryString = HitomiManager.translate2query(
    //     'female:loli female:sister (lang:korean or lang:n/a)');

    // print(queryString);

    // final db =
    //     await databaseFactoryFfi.openDatabase('/home/ubuntu/rawdata-korean.db');

    // var count = (await db.rawQuery(queryString.replaceAll(
    //         'SELECT * FROM', 'SELECT COUNT(*) AS C FROM')))
    //     .first['C'] as int;

    // print(count);
  });

  /*test('test script', () {
    // var lexer = JSonLexer();
    // var parser = JSonParser();
    // var lexer = ScriptLexer();
    // var parser = ScriptParser();
    // ParseTree tree;

    // lexer.allocateTarget("[{\"object\": \"obj\"}]");

    var runner =
        ScriptRunner("""if (or(gre(sum(x,y), sub(x,y)), iscon(x,y,z))) [
    foreach (k : arrayx) [
        print(k)]
    k[3] = 6 // Assign 6 to k[3]
] else if (not(iscon(x,y,z))) [
    k[2] = 7
]""");

    print(runner.printTree());

    runner.runScript(null);

    // var insert = (String x, String y, int a, int b) {
    //   parser.insertByTokenName(x, y);
    //   if (parser.isError())
    //     throw new Exception("[COMPILER] Parser error! L:$a, C:$b");
    //   while (parser.reduce()) {
    //     var l = parser.latestReduce();
    //     //l.action(l);
    //     parser.insertByTokenName(x, y);
    //     if (parser.isError())
    //       throw new Exception("[COMPILER] Parser error! L:$a, C:$b");
    //   }
    // };

    // while (lexer.valid()) {
    //   var tk = lexer.next();
    //   insert(tk.item1, tk.item2, tk.item3, tk.item4);
    // }

    // if (parser.isError()) throw new Exception();
    // insert("\$", "\$", -1, -1);

    // tree = parser.tree();

    // print(tree.printTree());
  });*/

  // testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  //   // Build our app and trigger a frame.
  //   // await tester.pumpWidget(MyApp());

  //   // Verify that our counter starts at 0.
  //   expect(find.text('0'), findsOneWidget);
  //   expect(find.text('1'), findsNothing);

  //   // Tap the '+' icon and trigger a frame.
  //   await tester.tap(find.byIcon(Icons.add));
  //   await tester.pump();

  //   // Verify that our counter has incremented.
  //   expect(find.text('0'), findsNothing);
  //   expect(find.text('1'), findsOneWidget);
  // });

  // test('Pixiv Test', () async {
  //   var pp = PixivManager();

  //   var tasks = await pp.createTask(
  //       'https://www.pixiv.net/users/3614038', GeneralDownloadProgress());

  //   tasks.forEach((element) {
  //     print(element.url);
  //   });
  // });

  // test('Gelbooru Test', () async {
  //   var gm = GelbooruManager();

  //   await gm.createTask(
  //       'https://gelbooru.com/index.php?page=post&s=list&tags=cura', null);
  // });

  // test('Instagram Test', () async {
  //   var url = 'https://www.instagram.com/zennyrt/?hl=ko';

  //   // var html = (await http.get(url)).body;
  //   var im = InstagramManager();
  //   await im.createTask(
  //       url,
  //       GeneralDownloadProgress(
  //         progressCallback: (a, b) {
  //           print(a.toString() + '/' + b.toString());
  //         },
  //         simpleInfoCallback: (a) {
  //           print(a);
  //         },
  //         thumbnailCallback: (a, b) {
  //           print(a);
  //         },
  //       ));
  // });

  // test('Hitomi Test', () async {
  //   var url = 'https://hitomi.la/galleries/1685671.html';

  //   // var html = (await http.get(url)).body;
  //   var im = HitomiDonwloadManager();
  //   await im.createTask(
  //       url,
  //       GeneralDownloadProgress(
  //         progressCallback: (a, b) {
  //           print(a.toString() + '/' + b.toString());
  //         },
  //         simpleInfoCallback: (a) {
  //           print(a);
  //         },
  //         thumbnailCallback: (a, b) {
  //           print(a);
  //         },
  //       ));
  // });

  // test('Twitter Test', () async {
  //   // print(await TwitterAPI.userByScreenName('WkfxjfrP'));
  //   print(await TwitterAPI.timeline('945314922065305600'));

  //   // var html = (await http.get(url)).body;
  //   // var im = HitomiDonwloadManager();
  //   // await im.createTask(
  //   //     url,
  //   //     GeneralDownloadProgress(
  //   //       progressCallback: (a, b) {
  //   //         print(a.toString() + '/' + b.toString());
  //   //       },
  //   //       simpleInfoCallback: (a) {
  //   //         print(a);
  //   //       },
  //   //       thumbnailCallback: (a, b) {
  //   //         print(a);
  //   //       },
  //   //     ));
  // });

  // test("hitomi test", () async {
  //   await VioletServer.view(1702084);
  //   await VioletServer.view(1702084);
  //   await VioletServer.view(1702084);
  //   await VioletServer.view(1702084);
  //   await VioletServer.view(1702084);
  //   await VioletServer.view(17021084);
  //   await VioletServer.view(17020184);
  //   await VioletServer.view(17020184);
  //   await VioletServer.view(17020184);
  //   // (await HitomiManager.getImageList('1702084')).item1.forEach((element) {
  //   //   print(element);
  //   // });
  // });

  // test("Violet Server", () async {
  //   // print(await VioletCommunitySession.checkUserAppId('asdf'));
  //   print(HitomiManager.translate2query(
  //       'female:loli (lang:korean) -group:zenmmai_courasi -artist:loli'));
  // });

  test("EHentai Test", () async {
    // var what = 'ahegao';

    // var search = Uri.encodeComponent(what);

    // var url =
    //     'https://e-hentai.org/?inline_set=dm_e&f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=$search&page=0&f_apply=Apply+Filter&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_srdd=2';

    // // await http.get('https://exhentai.org/?inline_set=dm_e', headers: {
    // //   'Cookie':
    // //       'igneous=30e0c0a66;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f'
    // // });
    // var html = (await http.get(url, headers: {
    //   'Cookie':
    //       'igneous=30e0c0a66;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f;sl=dm_2'
    // }))
    //     .body;

    // var result = EHParser.parseReulstPageExtendedListView(html);

    // result.forEach((element) {
    //   print(element.title);
    // });

    /*var page = 0;
    var search = Uri.encodeComponent('ahegao');
    var url =
        'https://e-hentai.org/?inline_set=dm_e&page=$page&f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=$search&page=0&f_apply=Apply+Filter&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_srdd=2';

    var html = (await http.get(url, headers: {'Cookie': 'sl=dm_2'})).body;

    var result = EHParser.parseReulstPageExtendedListView(html);

    var x = result.map(
      (element) {
        var tag = List<String>();

        if (element.descripts['female'] != null)
          tag.addAll(element.descripts['female'].map((e) => "female:" + e));
        if (element.descripts['male'] != null)
          tag.addAll(element.descripts['male'].map((e) => "male:" + e));
        if (element.descripts['misc'] != null)
          tag.addAll(element.descripts['misc']);

        var map = {
          'Id': int.parse(element.url.split('/')[4]),
          'EHash': element.url.split('/')[5],
          'Title': element.title,
          'Artists': element.descripts['artist'] != null
              ? element.descripts['artist'].join('|')
              : 'n/a',
          'Groups': element.descripts['group'] != null
              ? element.descripts['group'].join('|')
              : null,
          'Characters': element.descripts['character'] != null
              ? element.descripts['character'].join('|')
              : null,
          'Series': element.descripts['parody'] != null
              ? element.descripts['parody'].join('|')
              : 'n/a',
          'Language': element.descripts['language'] != null
              ? element.descripts['language']
                  .where((element) => !element.contains('translate'))
                  .join('|')
              : 'n/a',
          'Tags': tag.join('|'),
          'Uploader': element.uploader,
          'PublishedEH': element.published,
          'Files': element.files,
          'Thumbnail': element.thumbnail,
          'Type': element.type,
          'URL': element.url,
        };

        return map;
      },
    );

    x.forEach((element) {
      print(element);
    });*/

    // print(HitomiManager.translate2query(
    //     'artist:sody (lang:korean or lang:n/a) ' +
    //         ['female:loli', 'artist:michiking']
    //             .where((e) => e.trim() != '')
    //             .map((e) => '-$e')
    //             .join(' ')
    //             .trim()));

    // var x = result.map((element) {
    //   var tag = List<String>();

    //   if (element.descripts['female'] != null)
    //     tag.addAll(element.descripts['female'].map((e) => "female:" + e));
    //   if (element.descripts['male'] != null)
    //     tag.addAll(element.descripts['male'].map((e) => "male:" + e));
    //   if (element.descripts['misc'] != null)
    //     tag.addAll(element.descripts['misc']);

    //   var map = {
    //     'Id': element.url.split('/')[4],
    //     'EHash': element.url.split('/')[5],
    //     'Title': element.title,
    //     'Artists': element.descripts['artist'] != null
    //         ? element.descripts['artist'].join('|')
    //         : 'n/a',
    //     'Groups': element.descripts['group'] != null
    //         ? element.descripts['group'].join('|')
    //         : null,
    //     'Characters': element.descripts['character'] != null
    //         ? element.descripts['character'].join('|')
    //         : null,
    //     'Series': element.descripts['parody'] != null
    //         ? element.descripts['parody'].join('|')
    //         : 'n/a',
    //     'Language': element.descripts['language'] != null
    //         ? element.descripts['language']
    //             .where((element) => !element.contains('translate'))
    //             .join('|')
    //         : 'n/a',
    //     'Tags': tag.join('|'),
    //     'Uploader': element.uploader,
    //     'PublishedEH': element.published,
    //     'Files': element.files,
    //     'Thumbnail': element.thumbnail,
    //     'Type': element.type,
    //     'URL': element.url,
    //   };

    //   print(map);

    //   return QueryResult(result: map);
    // }).toList();

/*
{Id: 1705700, EHash: 5aa9831938, Title: [Black Pharaoh] JL Forsaken Souls (Ongoing), Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: BlackPharaoh, PublishedEH: 2020-08-12 05:04, Files: 260 pages, Thumbnail: https://ehgt.org/t/97/c5/97c5439bd4a2fe844f43c6f02a3f22b0e2493653-359924-1333-2000-jpg_250.jpg, Type: western, URL: https://e-hentai.org/g/1705700/5aa9831938/}
{Id: 1705700, EHash: 5aa9831938, Title: [Black Pharaoh] JL Forsaken Souls (Ongoing), Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: BlackPharaoh, PublishedEH: 2020-08-12 05:04, Files: 260 pages, Thumbnail: https://ehgt.org/t/97/c5/97c5439bd4a2fe844f43c6f02a3f22b0e2493653-359924-1333-2000-jpg_250.jpg, Type: western, URL: https://e-hentai.org/g/1705700/5aa9831938/}
{Id: 1705633, EHash: 8a9d33153c, Title: [Yamada Gogogo] 에로나2 오크의 음문에 몸부림치는 무녀의 영락 1화 / ERONA2 Orc no Inmon ni Modaeshi Miko no Nare no 
Hate ch1 [Korean] [팀☆데레마스], Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: felicitas759, PublishedEH: 2020-08-12 03:41, Files: 35 pages, Thumbnail: https://ehgt.org/t/a0/9d/a09dc046ccb78298514ce935ab5f3cec7ef3aca9-2505452-1747-2480-jpg_250.jpg, Type: manga, URL: https://e-hentai.org/g/1705633/8a9d33153c/}
{Id: 1705601, EHash: 3c7b28f14f, Title: にゅう工房 (にゅう)  人間操りアイテム もしもデリヘル～あの子は今日から俺専用デリヘル嬢～, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: qq824356842, PublishedEH: 2020-08-12 02:55, Files: 203 pages, Thumbnail: https://ehgt.org/t/19/5b/195b5d89c60aa3ff09fe953633c596b6408468dd-200064-560-420-jpg_250.jpg, Type: artist cg, URL: https://e-hentai.org/g/1705601/3c7b28f14f/}
{Id: 1705523, EHash: 086b26fa4b, Title: にゅう工房 (にゅう)  ヤリたい放題催眠性活～催眠で女の子を操って、変態行為を強制したりHしたりの抜きまくり生活～, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: qq824356842, PublishedEH: 2020-08-12 00:45, Files: 159 pages, Thumbnail: https://ehgt.org/t/78/4b/784bf9b63749aed2a810dad68588b25d9db7c429-421394-560-420-jpg_250.jpg, Type: manga, URL: https://e-hentai.org/g/1705523/086b26fa4b/}
{Id: 1705419, EHash: 4162e5e624, Title: [Artist] FoxyRain, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: saltcutlet, PublishedEH: 2020-08-11 23:11, Files: 706 pages, Thumbnail: https://ehgt.org/t/ce/d8/ced8a60e5edfce326aa506f31c74023ac5b47f0a-549143-778-1100-jpg_250.jpg, Type: image set, URL: https://e-hentai.org/g/1705419/4162e5e624/}
{Id: 1705471, EHash: a2b623df1b, Title: [Ankoman] Nazo no Heroine XX, Master no Shiranai Aida ni Bitch-ka suru no Maki - That time Mysterious Heroine XX became a Bitch while Master wasn't Looking (Fate/Grand Order) [español] {MetamorfosiS} [sin censura], Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: Julito arias, PublishedEH: 2020-08-11 23:06, Files: 5 pages, Thumbnail: https://ehgt.org/t/dc/83/dc8329c91488a84528e7476952bfe6c683bf12a1-435353-1280-1780-jpg_250.jpg, Type: doujinshi, URL: https://e-hentai.org/g/1705471/a2b623df1b/}
{Id: 1705448, EHash: 6c44e89078, Title: Honoka Punished, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: Ryuk83, PublishedEH: 2020-08-11 23:03, Files: 82 pages, Thumbnail: https://ehgt.org/t/b1/62/b1622a2279ae8312ed57f5f7c20536b3dbe9751e-1911655-1600-900-png_250.jpg, Type: image set, URL: https://e-hentai.org/g/1705448/6c44e89078/}
{Id: 1705450, EHash: daf65644cb, Title: [MalkiorX] Resident Evil Confidential, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: sadikus, PublishedEH: 2020-08-11 22:44, Files: 271 pages, Thumbnail: https://ehgt.org/t/e7/78/e778be34b0507f0a5403655f3b81fe54896eb54a-1018526-960-1080-png_250.jpg, Type: western, URL: https://e-hentai.org/g/1705450/daf65644cb/}
{Id: 1676374, EHash: aa1fb640d0, Title: [Pixiv] Akisora (20291650), Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: saltcutlet, PublishedEH: 2020-08-11 21:39, Files: 186 pages, Thumbnail: https://ehgt.org/t/ae/0d/ae0d153815979dd30260912549fe04ee270a249e-388511-715-1010-jpg_250.jpg, Type: image set, URL: https://e-hentai.org/g/1676374/aa1fb640d0/}
{Id: 1705358, EHash: 043bc86a73, Title: [Kurotoya (Kuroda Kuro)] Bitch Mama to Mesumusuko | Мать сучка и её сын мазохист [Russian] [Digital], Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: TAlvar, PublishedEH: 2020-08-11 18:52, Files: 24 pages, Thumbnail: https://ehgt.org/t/03/5a/035a5785697a2e46b6cd1d58277ac97705440c2c-342731-1133-1576-jpg_250.jpg, Type: doujinshi, URL: https://e-hentai.org/g/1705358/043bc86a73/}   
{Id: 1705287, EHash: 3592928311, Title: [Takeo92] Lost in the Swamp Chapter 1 - 4 (Avatar The Last Airbender) (Koikatsu!) [Ongoing], Artists: n/a, Groups: 
null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: Takeo92, PublishedEH: 2020-08-11 16:16, Files: 250 pages, Thumbnail: https://ehgt.org/t/8a/20/8a20f0b4a8addef6e182cd509ef8f2128a0dce07-2387384-1920-1080-png_250.jpg, Type: misc, URL: https://e-hentai.org/g/1705287/3592928311/}
{Id: 1705237, EHash: ba945ae51e, Title: [Warukuriya] ドスケベリンクス闇 GXレジェンド編 (Yu-Gi-Oh! GX), Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: tos91041, PublishedEH: 2020-08-11 14:55, Files: 165 pages, Thumbnail: https://ehgt.org/t/e6/50/e6508a7d294b577b93a9b3c10c936e25904e9932-1189824-1120-840-png_250.jpg, Type: artist cg, URL: https://e-hentai.org/g/1705237/ba945ae51e/}
{Id: 1703259, EHash: b76ef88399, Title: Artist Damu Otoko (ダム男), Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: nataky16, PublishedEH: 2020-08-11 13:21, Files: 198 pages, Thumbnail: https://ehgt.org/t/07/4e/074e9ede547e9ca1e2748377bef3958d6bc15e61-924903-851-1200-jpg_250.jpg, Type: misc, URL: https://e-hentai.org/g/1703259/b76ef88399/}
{Id: 1705108, EHash: 9c414fc2be, Title: [Chicke III] Houkago Devil Devil | หนุ่มทิพย์พิชิตมาร (COMIC Kairakuten 2020-08) [Thai ภาษาไทย] [Digital], Artists:
 n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: morimasaki, PublishedEH: 2020-08-11 12:48, Files: 20 pages, Thumbnail: 
https://ehgt.org/t/29/97/2997b30a20cd3875822bd192fdf61c88322435b8-1350970-1359-1920-png_250.jpg, Type: manga, URL: https://e-hentai.org/g/1705108/9c414fc2be/}
{Id: 1705028, EHash: 93ac8f3cd2, Title: [Artist] Nosekichiku, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: saltcutlet, PublishedEH: 2020-08-11 12:19, Files: 178 pages, Thumbnail: https://ehgt.org/t/e9/94/e99476e1d7dbb28a07327cede88b0b5643191a7d-1584528-1434-2024-jpg_250.jpg, Type: image set, URL: https://e-hentai.org/g/1705028/93ac8f3cd2/}
{Id: 1705074, EHash: 72cefe0336, Title: [Kunseidou (Bacon)] C97 Akane-chan Ryoujoku Copybon (Pokémon) [Digital], Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: saltcutlet, PublishedEH: 2020-08-11 11:27, Files: 15 pages, Thumbnail: https://ehgt.org/t/85/6d/856d56e10516af989f12ed4f17c793c0e9d87d13-1338098-2000-1340-jpg_250.jpg, Type: doujinshi, URL: https://e-hentai.org/g/1705074/72cefe0336/}
{Id: 1684208, EHash: 3b0d8b90ad, Title: [Artist] Torahime, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: saltcutlet, PublishedEH: 2020-08-11 10:19, Files: 795 pages, Thumbnail: https://ehgt.org/t/5c/7d/5c7d6872b39b5e6e98c7bb53a04e6c28be84c2e0-381062-868-1228-jpg_250.jpg, Type: image set, URL: https://e-hentai.org/g/1684208/3b0d8b90ad/}
{Id: 1704999, EHash: 2f5f20b999, Title: ratatatat74 [Patreon], Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: 
K-Polish, PublishedEH: 2020-08-11 08:45, Files: 685 pages, Thumbnail: https://ehgt.org/t/4d/48/4d488b83bc551ed201598455b7636934651e6afc-106907-900-1334-jpg_250.jpg, Type: image set, URL: https://e-hentai.org/g/1704999/2f5f20b999/}
{Id: 1704969, EHash: 7ce5bb0df4, Title: [Supersatanson] Moozaki-chan (Uzaki-chan wa Asobitai!), Artists: n/a, Groups: null, Characters: null, Series: n/a, 
Language: n/a, Tags: , Uploader: sadikus, PublishedEH: 2020-08-11 08:17, Files: 7 pages, Thumbnail: https://ehgt.org/t/f3/8d/f38d0cb3a34992b1dad12ab5a14b37ff845bfa76-1519435-2454-3000-jpg_250.jpg, Type: western, URL: https://e-hentai.org/g/1704969/7ce5bb0df4/}
{Id: 1704965, EHash: c69cbf23ae, Title: [JJZ-Godd] BBB, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: JJZ-Good, PublishedEH: 2020-08-11 07:55, Files: 75 pages, Thumbnail: https://ehgt.org/t/79/12/79123a93eba4a2545be8cbed017e6815e901cf08-2974545-1920-1080-png_250.jpg, Type: misc, URL: https://e-hentai.org/g/1704965/c69cbf23ae/}
{Id: 1704950, EHash: 0dba270ca1, Title: [らいおん] Yue (Arifureta) Gallery (PIxiv) (21391270), Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: Egakor, PublishedEH: 2020-08-11 07:08, Files: 51 pages, Thumbnail: https://ehgt.org/t/91/0a/910a08c961823388e62f2d93d3cad3340cb868f5-311061-1200-840-jpg_250.jpg, Type: image set, URL: https://e-hentai.org/g/1704950/0dba270ca1/}
{Id: 1700125, EHash: 5b37af9b74, Title: [Patreon | Pixiv] ReBe-111H (848141), Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: saltcutlet, PublishedEH: 2020-08-11 06:27, Files: 755 pages, Thumbnail: https://ehgt.org/t/50/0d/500d234704d716ac2f36215ec856b591ee366de6-1785147-1050-1400-png_250.jpg, Type: image set, URL: https://e-hentai.org/g/1700125/5b37af9b74/}
{Id: 1704876, EHash: 481f364acc, Title: [Furitendou] Gakuen'naka no joshi ga bitchi-ka u~irusu ni kansen shi saru-nami no chinō ni nattanode joshi seito zen'in no ma 〇 Ko o tsukaisute onaho ni shite onanī shite mita, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: 
dionysus004, PublishedEH: 2020-08-11 04:18, Files: 79 pages, Thumbnail: https://ehgt.org/t/fd/a7/fda77fed8aadedfb668dda831b36ddafdc51485e-488118-560-420-jpg_250.jpg, Type: artist cg, URL: https://e-hentai.org/g/1704876/481f364acc/}
{Id: 1704774, EHash: 4c75943786, Title: [Stormfeder] Karenvania (Ongoing) 28 pages, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: bloodfalco, PublishedEH: 2020-08-11 01:19, Files: 34 pages, Thumbnail: https://ehgt.org/t/94/27/942751e48bb195695b1d9f0d476ee7c6aaa2f298-5165764-2593-3508-png_250.jpg, Type: western, URL: https://e-hentai.org/g/1704774/4c75943786/}
{Id: 1704760, EHash: a9ddbbea96, Title: [Neone] Eva OC, Artists: n/a, Groups: null, Characters: null, Series: n/a, Language: n/a, Tags: , Uploader: kikimaru024, PublishedEH: 2020-08-11 01:07, Files: 345 pages, Thumbnail: https://ehgt.org/t/e1/6e/e16e0eb03c7eef596d03a55f87ca72e17c75fd1c-180383-500-706-png_250.jpg, Type: image set, URL: https://e-hentai.org/g/1704760/a9ddbbea96/}
*/
  });
}
