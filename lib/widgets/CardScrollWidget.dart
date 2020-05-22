import 'package:flutter/material.dart';
import 'dart:math';

List<String> images = [
  "assets/test/001.jpg",
  "assets/test/001.png",
  "assets/test/001.webp",
  "assets/test/001.webp",
  "assets/test/001.png",
];

List<String> title = [
  "Hounted Ground",
  "Fallen In Love",
  "The Dreaming Moon",
  "Jack the Persian and the Black Castel",
  "Jack the Persian and the Black Castel",
];

class CardScrollWidget extends StatelessWidget {
  var currentPage;
  var padding = 20.0;
  var verticalInset = 20.0;

  final cardAspectRatio = 12.0 / 16.0;
  double widgetAspectRatio;

  CardScrollWidget(this.currentPage) {
    widgetAspectRatio = cardAspectRatio * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    return new AspectRatio(
      aspectRatio: widgetAspectRatio,
      child: LayoutBuilder(builder: (context, contraints) {
        var width = contraints.maxWidth;
        var height = contraints.maxHeight;

        var safeWidth = width - 2 * padding;
        var safeHeight = height - 2 * padding;

        var heightOfPrimaryCard = safeHeight;
        var widthOfPrimaryCard = heightOfPrimaryCard * cardAspectRatio;

        var primaryCardLeft = safeWidth - widthOfPrimaryCard;
        var horizontalInset = primaryCardLeft / 2;

        List<Widget> cardList = new List();

        for (var i = 0; i < images.length; i++) {
          var delta = i - currentPage;
          bool isOnRight = delta > 0;

          var start = padding +
              max(
                  primaryCardLeft -
                      horizontalInset * -delta * (isOnRight ? 15 : 1),
                  0.0);

          var cardItem = Positioned.directional(
            top: padding + verticalInset * max(-delta, 0.0),
            bottom: padding + verticalInset * max(-delta, 0.0),
            //width: width - 150,
            start: start,
            textDirection: TextDirection.rtl,
            child: Container(
              decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black54,
                            offset: Offset(0, 4),
                            blurRadius: 6)
                      ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Container(
                  // decoration: BoxDecoration(color: Colors.white, boxShadow: [
                  //   BoxShadow(
                  //       color: Colors.black12,
                  //       offset: Offset(3.0, 6.0),
                  //       blurRadius: 10.0)
                  // ]),
                  //margin: EdgeInsets.only(top: 10),
                  // decoration: BoxDecoration(
                  //     borderRadius: BorderRadius.circular(16),
                  //     boxShadow: [
                  //       BoxShadow(
                  //           color: Colors.black54,
                  //           offset: Offset(0, 4),
                  //           blurRadius: 6)
                  //     ]),
                  child: AspectRatio(
                    aspectRatio: cardAspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.asset(images[i], fit: BoxFit.cover),
                        // Align(
                        //   alignment: Alignment.bottomLeft,
                        //   child: Column(
                        //     mainAxisSize: MainAxisSize.min,
                        //     crossAxisAlignment: CrossAxisAlignment.start,
                        //     children: <Widget>[
                        //       Padding(
                        //         padding: EdgeInsets.symmetric(
                        //             horizontal: 16.0, vertical: 8.0),
                        //         child: Text(title[i],
                        //             style: TextStyle(
                        //                 color: Colors.white,
                        //                 fontSize: 25.0,
                        //                 fontFamily: "SF-Pro-Text-Regular")),
                        //       ),
                        //       SizedBox(
                        //         height: 10.0,
                        //       ),
                        //       Padding(
                        //         padding: const EdgeInsets.only(
                        //             left: 12.0, bottom: 12.0),
                        //         child: Container(
                        //           padding: EdgeInsets.symmetric(
                        //               horizontal: 22.0, vertical: 6.0),
                        //           decoration: BoxDecoration(
                        //               color: Colors.blueAccent,
                        //               borderRadius: BorderRadius.circular(20.0)),
                        //           child: Text("Read Later",
                        //               style: TextStyle(color: Colors.white)),
                        //         ),
                        //       )
                        //     ],
                        //   ),
                        // )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          cardList.add(cardItem);
        }
        return Stack(
          children: cardList,
        );
      }),
    );
  }
}
