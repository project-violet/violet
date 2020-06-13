// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

//import 'package:explorer/pages/download_page.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flare_flutter/flare_cache.dart';
import 'package:flutter/material.dart';

//void main() => runApp(MyApp());

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Welcome to Flutter',
//       home: RandomWords(),
//       theme: ThemeData(
//         primaryColor: Colors.white,
//       ),
//     );
//   }
// }

// class RandomWords extends StatefulWidget {
//   @override
//   RandomWordsState createState() => RandomWordsState();
// }

// class RandomWordsState extends State<RandomWords> {
//   final _suggestions = <WordPair>[];
//   final Set<WordPair> _saved = Set<WordPair>();
//   final _biggerFont = const TextStyle(fontSize: 18.0);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Startup Name Generator'),
//         actions: <Widget>[
//           IconButton(icon: Icon(Icons.list), onPressed: _pushSaved),
//         ],
//       ),
//       body: _buildSuggestions(),
//       drawer: Drawer(),
//     );
//   }

//   void _pushSaved() {
//     Navigator.of(context).push(
//       MaterialPageRoute<void>(
//         builder: (BuildContext context) {
//           final Iterable<ListTile> tiles = _saved.map(
//             (WordPair pair) {
//               return ListTile(
//                 title: Text(
//                   pair.asPascalCase,
//                   style: _biggerFont,
//                 ),
//               );
//             },
//           );
//           final List<Widget> divided = ListTile.divideTiles(
//             context: context,
//             tiles: tiles,
//           ).toList();
//           return Scaffold(
//             appBar: AppBar(
//               title: Text('Saved Suggestions'),
//             ),
//             body: ListView(children: divided),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildSuggestions() {
//     return ListView.builder(
//         padding: const EdgeInsets.all(16.0),
//         itemBuilder: /*1*/ (context, i) {
//           if (i.isOdd) return Divider(); /*2*/

//           final index = i ~/ 2; /*3*/
//           if (index >= _suggestions.length) {
//             _suggestions.addAll(generateWordPairs().take(10)); /*4*/
//           }
//           return _buildRow(_suggestions[index]);
//         });
//   }

//   Widget _buildRow(WordPair pair) {
//     final bool alreadySaved = _saved.contains(pair);
//     return ListTile(
//       title: Text(
//         pair.asPascalCase,
//         style: _biggerFont,
//       ),
//       trailing: Icon(
//         alreadySaved ? Icons.favorite : Icons.favorite_border,
//         color: alreadySaved ? Colors.red : null,
//       ),
//       onTap: () {
//         setState(() {
//           if (alreadySaved)
//             _saved.remove(pair);
//           else
//             _saved.add(pair);
//         });
//       },
//     );
//   }
// }

// void main() {
//   runApp(MaterialApp(
//     home: MyApp(),
//     // Define the theme, set the primary swatch
//     theme: ThemeData(primarySwatch: Colors.green),
//   ));
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     // Declare some constants
//     final double myTextSize = 30.0;
//     final double myIconSize = 40.0;
//     final TextStyle myTextStyle =
//         TextStyle(color: Colors.grey, fontSize: myTextSize);

//     var column = Column(
//       // Makes the cards stretch in horizontal axis
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: <Widget>[
//         // Setup the card
//         MyCard(
//             // Setup the text
//             title: Text(
//               "Favorite",
//               style: myTextStyle,
//             ),
//             // Setup the icon
//             icon:
//                 Icon(Icons.favorite, size: myIconSize, color: Colors.red)),
//         MyCard(
//             title: Text(
//               "Alarm",
//               style: myTextStyle,
//             ),
//             icon: Icon(Icons.alarm, size: myIconSize, color: Colors.blue)),
//         MyCard(
//             title: Text(
//               "Airport Shuttle",
//               style: myTextStyle,
//             ),
//             icon: Icon(Icons.airport_shuttle,
//                 size: myIconSize, color: Colors.amber)),
//         MyCard(
//             title: Text(
//               "Done",
//               style: myTextStyle,
//             ),
//             icon: Icon(Icons.done, size: myIconSize, color: Colors.green)),
//       ],
//     );

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Stateless Widget"),
//       ),
//       body: Container(
//         // Sets the padding in the main container
//         padding: const EdgeInsets.only(bottom: 2.0),
//         child: SingleChildScrollView(child: column),
//       ),
//     );
//     ;
//   }
// }

// // Create a reusable stateless widget
// class MyCard extends StatelessWidget {
//   final Widget icon;
//   final Widget title;

//   // Constructor. {} here denote that they are optional values i.e you can use as: MyCard()
//   MyCard({this.title, this.icon});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.only(bottom: 1.0),
//       child: Card(
//         child: Container(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             children: <Widget>[this.title, this.icon],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: Text("Load local image"),
//         ),
//         body: Container(
//           child: Center(
//             child: Text(
//               "Hello World!",
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//           // Set the image as the background of the Container
//           decoration: BoxDecoration(
//               image: DecorationImage(
//                   // Load image from assets
//                   image: AssetImage('data_repo/bg1.jpg'),
//                   // Make the image cover the whole area
//                   fit: BoxFit.fill)),
//         ));
//   }
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         backgroundColor: Colors.grey[300],
//         body: Center(
//           child: Container(
//             width: 200,
//             height: 200,
//             child: Icon(
//               Icons.cloud,
//               size: 100,
//             ),
//             decoration: BoxDecoration(
//               color: Colors.grey[300],
//               borderRadius: BorderRadius.all(
//                 Radius.circular(40),
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey[500],
//                   offset: Offset(4.0, 4.0),
//                   blurRadius: 15.0,
//                   spreadRadius: 1.0,
//                 ),
//                 BoxShadow(
//                   color: Colors.white,
//                   offset: Offset(-4.0, -4.0),
//                   blurRadius: 15.0,
//                   spreadRadius: 1.0,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// void main() {
//   runApp(MaterialApp(
//     home: MyGetHttpData(),
//   ));
// }

// // Create a stateful widget
// class MyGetHttpData extends StatefulWidget {
//   @override
//   MyGetHttpDataState createState() => MyGetHttpDataState();
// }

// // Create the state for our stateful widget
// class MyGetHttpDataState extends State<MyGetHttpData> {
//   final String url = "https://swapi.co/api/people";
//   List data;

//   // Function to get the JSON data
//   Future<String> getJSONData() async {
//     var response = await http.get(
//         // Encode the url
//         Uri.encodeFull(url),
//         // Only accept JSON response
//         headers: {"Accept": "application/json"});

//     // Logs the response body to the console
//     print(response.body);

//     // To modify the state of the app, use this method
//     setState(() {
//       // Get the JSON data
//       var dataConvertedToJSON = json.decode(response.body);
//       // Extract the required part and assign it to the global variable named data
//       data = dataConvertedToJSON['results'];
//     });

//     return "Successfull";
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Retrieve JSON Data via HTTP GET"),
//       ),
//       // Create a Listview and load the data when available
//       body: ListView.builder(
//           itemCount: data == null ? 0 : data.length,
//           itemBuilder: (BuildContext context, int index) {
//             return Container(
//               child: Center(
//                   child: Column(
//                 // Stretch the cards in horizontal axis
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: <Widget>[
//                   Card(
//                     child: Container(
//                       child: Text(
//                         // Read the name field value and set it in the Text widget
//                         data[index]['name'],
//                         // set some style to text
//                         style: TextStyle(
//                             fontSize: 20.0, color: Colors.lightBlueAccent),
//                       ),
//                       // added padding
//                       padding: const EdgeInsets.all(15.0),
//                     ),
//                   )
//                 ],
//               )),
//             );
//           }),
//     );
//   }

//   @override
//   void initState() {
//     super.initState();

//     // Call the getJSONData() method when the app initializes
//     this.getJSONData();
//   }
// }

// import 'package:flutter/material.dart';

// import './widgets/new_transaction.dart';
// import './widgets/transaction_list.dart';
// import './widgets/chart.dart';
// import './models/transaction.dart';

// void main() => runApp(MyApp());

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Personal Expenses',
//       theme: ThemeData(
//           primarySwatch: Colors.purple,
//           accentColor: Colors.amber,
//           // errorColor: Colors.red,
//           fontFamily: 'Quicksand',
//           textTheme: ThemeData.light().textTheme.copyWith(
//                 title: TextStyle(
//                   fontFamily: 'OpenSans',
//                   fontWeight: FontWeight.bold,
//                   fontSize: 18,
//                 ),
//                 button: TextStyle(color: Colors.white),
//               ),
//           appBarTheme: AppBarTheme(
//             textTheme: ThemeData.light().textTheme.copyWith(
//                   title: TextStyle(
//                     fontFamily: 'OpenSans',
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//           )),
//       home: MyHomePage(),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   // String titleInput;
//   // String amountInput;
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final List<Transaction> _userTransactions = [
//     // Transaction(
//     //   id: 't1',
//     //   title: 'New Shoes',
//     //   amount: 69.99,
//     //   date: DateTime.now(),
//     // ),
//     // Transaction(
//     //   id: 't2',
//     //   title: 'Weekly Groceries',
//     //   amount: 16.53,
//     //   date: DateTime.now(),
//     // ),
//   ];

//   List<Transaction> get _recentTransactions {
//     return _userTransactions.where((tx) {
//       return tx.date.isAfter(
//         DateTime.now().subtract(
//           Duration(days: 7),
//         ),
//       );
//     }).toList();
//   }

//   void _addNewTransaction(
//       String txTitle, double txAmount, DateTime chosenDate) {
//     final newTx = Transaction(
//       title: txTitle,
//       amount: txAmount,
//       date: chosenDate,
//       id: DateTime.now().toString(),
//     );

//     setState(() {
//       _userTransactions.add(newTx);
//     });
//   }

//   void _startAddNewTransaction(BuildContext ctx) {
//     showModalBottomSheet(
//       context: ctx,
//       builder: (_) {
//         return GestureDetector(
//           onTap: () {},
//           child: NewTransaction(_addNewTransaction),
//           behavior: HitTestBehavior.opaque,
//         );
//       },
//     );
//   }

//   void _deleteTransaction(String id) {
//     setState(() {
//       _userTransactions.removeWhere((tx) => tx.id == id);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Personal Expenses',
//         ),
//         actions: <Widget>[
//           IconButton(
//             icon: Icon(Icons.add),
//             onPressed: () => _startAddNewTransaction(context),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           // mainAxisAlignment: MainAxisAlignment.start,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: <Widget>[
//             Chart(_recentTransactions),
//             TransactionList(_userTransactions, _deleteTransaction),
//           ],
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//       floatingActionButton: FloatingActionButton(
//         child: Icon(Icons.add),
//         onPressed: () => _startAddNewTransaction(context),
//       ),
//     );
//   }
// }

//import 'tabbar.dart';
//void main() => runApp(MyApp2());

// class MyApp extends StatelessWidget {
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Hitomi Viewer',
//       theme:
//           ThemeData(primaryColor: Colors.cyan, accentColor: Colors.tealAccent),
//       home: DefaultTabController(
//         length: 3,
//         child: Scaffold(
//           appBar: AppBar(
//             //title: Text('Hitomi Viewer'),
//             bottom: PreferredSize(
//               child: Container(
//                 //margin: EdgeInsets.fromLTRB(100, 0, 0, 0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: <Widget>[
//                     Container(
//                       child: InkWell(
//                         child: Text('Hitomi Viewer'),
//                       ),
//                       margin: EdgeInsets.fromLTRB(10, 0, 80, 0),
//                     ),
//                     Flexible(
//                       child: TabBar(
//                         tabs: <Widget>[
//                           Container(
//                             child: Tab(icon: Icon(Icons.search)),
//                             //height: 10,
//                           ),
//                           Container(
//                             child: Tab(icon: Icon(Icons.file_download)),
//                             //height: 10,
//                           ),
//                           Container(
//                             child: Tab(icon: Icon(Icons.settings)),
//                             //height: 10,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               preferredSize: Size.fromHeight(-8),
//             ),
//           ),
//           body: TabBarView(
//             children: [
//               Icon(Icons.search),
//               Icon(Icons.file_download),
//               Icon(Icons.settings),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class MyApp2 extends StatelessWidget {
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key key, this.title}) : super(key: key);
//   final String title;

//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           title: Text(widget.title),
//         ),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: <Widget>[
//               Text(
//                 'You have pushed the button this many times:',
//               ),
//               Text(
//                 '$_counter',
//                 style: Theme.of(context).textTheme.display1,
//               ),
//             ],
//           ),
//         ),
//         floatingActionButton: FloatingActionButton(
//           onPressed: _incrementCounter,
//           tooltip: 'Increment',
//           child: Icon(Icons.add),
//         ),
//         // 추가된 bottomNavigationBar
//         bottomNavigationBar: BottomNavigationBar(
//             type: BottomNavigationBarType.fixed,
//             onTap: (index) => {},
//             currentIndex: 0,
//             items: [
//               new BottomNavigationBarItem(
//                 icon: Icon(Icons.home),
//                 title: Text('Home'),
//               ),
//               new BottomNavigationBarItem(
//                 icon: Icon(Icons.mail),
//                 title: Text('First'),
//               ),
//               new BottomNavigationBarItem(
//                 icon: Icon(Icons.person),
//                 title: Text('Second'),
//               )
//             ]));
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:usage/usage.dart';
import 'package:usage/usage_io.dart';
import 'package:violet/settings.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'locale.dart';
import 'package:violet/pages/database_download_page.dart';
import 'package:violet/pages/splash_page.dart';
import 'package:violet/pages/afterloading_page.dart';
import 'package:path_provider/path_provider.dart';

DateTime currentBackPressTime;
Future<bool> onWillPop() {
  DateTime now = DateTime.now();
  if (currentBackPressTime == null ||
      now.difference(currentBackPressTime) > Duration(seconds: 2)) {
    currentBackPressTime = now;
    //Fluttertoast.showToast(msg: '한 번 더 누르면 종료합니다.');
    return Future.value(false);
  }
  return Future.value(true);
}

const _filesToWarmup = [
  'assets/flare/Loading2.flr',
];

Future<void> warmupFlare() async {
  for (final filename in _filesToWarmup) {
    await cachedActor(rootBundle, filename);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlareCache.doesPrune = false;

  // final String UA = '';
  // Analytics ga = new AnalyticsIO(UA, 'ga_test', '3.0',
  //   documentDirectory: await getApplicationDocumentsDirectory());
  // ga.analyticsOpt = AnalyticsOpt.optIn;
  // ga.sendScreenView('home');

  FirebaseAnalytics analytics = FirebaseAnalytics();
  await analytics.setUserId('some-user');

  await Settings.init();

  warmupFlare().then((_) {
    runApp(
      DynamicTheme(
        defaultBrightness: Brightness.light,
        data: (brightness) => new ThemeData(
          accentColor: Settings.majorColor,
          primaryColor: Settings.majorColor,
          brightness: brightness,
        ),
        themedWidgetBuilder: (context, theme) {
          return MaterialApp(
            navigatorObservers: [
              FirebaseAnalyticsObserver(analytics: analytics),
            ],
            theme: theme,
            home: SplashPage(), //AfterLoadingPage(),
            supportedLocales: [
              const Locale('ko', 'KR'),
              const Locale('en', 'US'),
            ],
            routes: <String, WidgetBuilder>{
              //'/Loading':
              '/AfterLoading': (BuildContext context) => WillPopScope(
                    child: new AfterLoadingPage(),
                    onWillPop: onWillPop,
                  ),
              '/DatabaseDownload': (BuildContext context) =>
                  new DataBaseDownloadPage(),
            },
            localizationsDelegates: [
              const TranslationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate
            ],
            localeResolutionCallback:
                (Locale locale, Iterable<Locale> supportedLocales) {
              if (locale == null) {
                debugPrint("*language locale is null!!!");
                return supportedLocales.first;
              }

              for (Locale supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode ||
                    supportedLocale.countryCode == locale.countryCode) {
                  debugPrint("*language ok $supportedLocale");
                  return supportedLocale;
                }
              }

              debugPrint("*language to fallback ${supportedLocales.first}");
              return supportedLocales.first;
            },
          );
        },
      ),
    );
  });
}
