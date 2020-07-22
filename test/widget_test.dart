// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:violet/component/download/gelbooru.dart';
import 'package:violet/component/download/instagram.dart';
import 'package:http/http.dart' as http;

// import 'package:violet/main.dart';
import 'package:violet/component/download/pixiv.dart';
import 'package:violet/component/downloadable.dart';

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

  test('Instagram Test', () async {
    var url = 'https://www.instagram.com/ravi.me/?hl=ko';

    // var html = (await http.get(url)).body;
    var im = InstagramManager();
    await im.createTask(
        url,
        GeneralDownloadProgress(
          progressCallback: (a, b) {
            print(a.toString() + '/' + b.toString());
          },
          simpleInfoCallback: (a) {
            print(a);
          },
          thumbnailCallback: (a, b) {
            print(a);
          },
        ));
  });
}
