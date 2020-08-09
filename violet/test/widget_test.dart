// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/download/gelbooru.dart';
import 'package:violet/component/download/hitomi.dart';
import 'package:violet/component/download/instagram.dart';
import 'package:http/http.dart' as http;

// import 'package:violet/main.dart';
import 'package:violet/component/download/pixiv.dart';
import 'package:violet/component/download/twitter.dart';
import 'package:violet/component/downloadable.dart';
import 'package:violet/component/eh/eh_parser.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';

void main() {
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

  test("hitomi test", () async {
    (await HitomiManager.getImageList('1702084')).item1.forEach((element) {
      print(element);
    });
  });

  test("EHentai Test", () async {
    var what = 'ahegao';

    var search = Uri.encodeComponent(what);

    var url =
        'https://e-hentai.org/?inline_set=dm_e&f_doujinshi=1&f_manga=1&f_artistcg=1&f_gamecg=1&f_western=1&f_non-h=1&f_imageset=1&f_cosplay=1&f_asianporn=1&f_misc=1&f_search=$search&page=0&f_apply=Apply+Filter&advsearch=1&f_sname=on&f_stags=on&f_sh=on&f_srdd=2';

    // await http.get('https://exhentai.org/?inline_set=dm_e', headers: {
    //   'Cookie':
    //       'igneous=30e0c0a66;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f'
    // });
    var html = (await http.get(url, headers: {
      'Cookie':
          'igneous=30e0c0a66;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f;sl=dm_2'
    }))
        .body;

    var result = EHParser.parseReulstPageExtendedListView(html);

    result.forEach((element) {
      print(element.title);
    });
  });
}
