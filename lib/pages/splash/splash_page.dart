// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:connectivity/connectivity.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/component/hitomi/population.dart';
import 'package:violet/component/hitomi/related.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/downloader/isolate_downloader.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/act_log.dart';
import 'package:violet/log/log.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/other/named_color.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/settings/settings_page.dart';
import 'package:violet/script/script_manager.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';

class RadioTile<T> extends StatefulWidget {
  const RadioTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.setGroupValue,
    required this.title,
    required this.subtitle,
    required this.onLongPress,
  });

  final T value;
  final T groupValue;
  final void Function(T) setGroupValue;
  final Widget title;
  final Widget subtitle;
  final void Function() onLongPress;

  @override
  State<RadioTile<T>> createState() => _RadioTileState<T>();
}

class _RadioTileState<T> extends State<RadioTile<T>> {
  bool _longPressing = false;

  @override
  Widget build(BuildContext context) {
    bool selected = widget.value == widget.groupValue;

    return AnimatedContainer(
      transform: Matrix4.identity()
        ..translate(300 / 2, 50 / 2)
        ..scale(_longPressing ? 0.95 : (selected ? 1.03 : 1.0))
        ..translate(-300 / 2, -50 / 2),
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 4,
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3.0))),
          child: ListTile(
            leading: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
                maxWidth: 44,
                maxHeight: 44,
              ),
              child: Radio<T>(
                value: widget.value,
                groupValue: widget.groupValue,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onChanged: (T? selected) {
                  setState(() {
                    _longPressing = false;
                    if (selected != null) {
                      widget.setGroupValue(selected);
                    }
                  });
                },
              ),
            ),
            title: widget.title,
            subtitle: widget.subtitle,
            dense: true,
          ),
          onTapDown: (details) {
            setState(() {
              _longPressing = true;
            });
          },
          onTap: () {
            setState(() {
              _longPressing = false;
              widget.setGroupValue(widget.value);
            });
          },
          onLongPress: () {
            setState(() {
              _longPressing = false;
              widget.onLongPress();
            });
          },
        ),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  final bool switching;

  const SplashPage({super.key, this.switching = false});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

enum Database { userLanguage, all }

class _SplashPageState extends State<SplashPage> {
  bool showFirst = false;
  bool animateBox = false;
  bool languageBox = false;
  bool showIndicator = false;
  int chunkDownloadMax = 0;
  int chunkDownloadProgress = 0;
  bool backupBookmark = false;
  bool showMessage = false;
  String message = '';

  final imgSize = {
    'global': '320MB',
    'ko': '76MB',
    'en': '100MB',
    'jp': '165MB',
    'zh': '85MB',
  };

  final dbSuppors = {'global', 'ko', 'en', 'jp', 'zh'};

  final imgZipSize = {
    'global': '32MB',
    'ko': '9MB',
    'en': '10MB',
    'jp': '18MB',
    'zh': '9MB',
  };

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('checkauthalready') == null) {
      await prefs.setBool('checkauthalready', true);
      if (await Permission.manageExternalStorage.request() ==
          PermissionStatus.denied) {
        await showOkDialog(context, '파일 권한을 허용하지 않으면 다운로드 기능을 이용할 수 없습니다.');
      }

      if (Platform.isAndroid) {
        await const AndroidIntent(
          action: 'ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION',
        ).launch();
      }
    }
  }

  startTime() async {
    var duration = const Duration(milliseconds: 100);
    return Timer(duration, navigationPage);
  }

  Future<void> navigationPage() async {
    setState(() {
      showMessage = true;
    });

    _changeMessage('init logger...');
    await Logger.init();
    _changeMessage('init act-logger...');
    await ActLogger.init();
    _changeMessage('init settings...');
    await Settings.init();
    _changeMessage('loading bookmark...');
    await Bookmark.getInstance();
    _changeMessage('loading userdb...');
    await User.getInstance();
    await Variables.init();
    _changeMessage('loading index...');
    await HitomiIndexs.init();
    _changeMessage('loading translate...');
    await TagTranslate.init();
    _changeMessage('init population...');
    await Population.init();
    _changeMessage('init related...');
    await Related.init();
    // await HisokiHash.init();
    _changeMessage('init downloader...');
    await IsolateDownloader.getInstance();

    // this may be slow down to loading
    _changeMessage('check network...');
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.none) {
      _changeMessage('loading script...');
      await ScriptManager.init();
    }

    // if (Settings.autobackupBookmark) {
    //   setState(() {
    //     backupBookmark = true;
    //   });
    //   await VioletServer.uploadBookmark();
    //   setState(() {
    //     backupBookmark = false;
    //   });
    // }

    // if (Platform.isAndroid)
    //   try {
    //     await Logger.exportLog();
    //   } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('db_exists') == 1 && !widget.switching) {
      if (connectivityResult != ConnectivityResult.none) {
        try {
          _changeMessage('check sync...');
          await SyncManager.checkSyncLatest(true);

          if (!SyncManager.firstSync && SyncManager.chunkRequire) {
            setState(() {
              showMessage = false;
              showIndicator = true;
            });
            await SyncManager.doChunkSync((_, len) async {
              setState(() {
                chunkDownloadMax = len;
                chunkDownloadProgress++;
              });
            });
          }
        } catch (e, st) {
          // If an error occurs, stops synchronization immediately.
          FirebaseCrashlytics.instance.recordError(e, st);
          Logger.error('[Splash-Navigation] E: $e\n'
              '$st');
        }
      }

      // We must show main page to user anyway
      Navigator.of(context).pushReplacementNamed('/AfterLoading');
    } else {
      setState(() {
        showMessage = false;
      });
      if (!widget.switching) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
      setState(() {
        showFirst = true;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        animateBox = true;
      });
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        languageBox = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _database = Database.userLanguage;
      });
    }
  }

  _changeMessage(String msg) {
    setState(() {
      message = msg;
    });
  }

  @override
  void initState() {
    super.initState();
    startTime();
  }

  Database? _database;

  void _setDatabase(Database? database) {
    setState(() {
      _database = database;
    });
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.ease,
              top: showFirst ? 130 : height / 2 - 50,
              left: width / 2 - 50,
              child: Image.asset(
                'assets/images/logo-${Settings.majorColor.name}.png',
                width: 100,
                height: 100,
              ),
            ),
            _showMessage(),
            _chunkDownload(),
            _firstPage(),
            _dbSelector(),
            _languageSelector(),
          ],
        ),
      ),
      backgroundColor: showFirst && !widget.switching
          ? const Color(0x7FB200ED)
          : Settings.majorColor.withAlpha(200),
    );
  }

  _chunkDownload() {
    return Visibility(
      visible: showIndicator || backupBookmark,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showIndicator)
                const Text('<< AutoSync >>',
                    style: TextStyle(color: Colors.white)),
              Text(
                  backupBookmark
                      ? 'Bookmark Backup...'
                      : chunkDownloadProgress != chunkDownloadMax ||
                              chunkDownloadMax == 0
                          ? 'Chunk downloading...[$chunkDownloadProgress/${SyncManager.getSyncRequiredChunkCount()}]'
                          : 'Extracting...',
                  style: const TextStyle(color: Colors.white)),
              Container(
                height: 16,
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Settings.majorColor.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _showMessage() {
    return Visibility(
      visible: showMessage,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(message, style: const TextStyle(color: Colors.white)),
              Container(
                height: 16,
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Settings.majorColor.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _firstPage() {
    final translations = Translations.of(context);

    return Visibility(
      visible: showFirst,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(top: 140),
          child: Card(
            elevation: 100,
            color: widget.switching
                ? Settings.majorColor.withAlpha(150)
                : Colors.purple.shade50,
            child: AnimatedOpacity(
              opacity: animateBox ? 1.0 : 0,
              duration: const Duration(milliseconds: 500),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.ease,
                width: animateBox ? 300 : 300,
                height: animateBox ? 300 : 0,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 900),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: <Widget>[
                      _welcomeMessage(),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                      ),
                      RadioTile(
                        value: Database.userLanguage,
                        groupValue: _database,
                        setGroupValue: _setDatabase,
                        title: Text(
                          translations.trans('dbuser'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${imgZipSize['ko']}${translations.trans('dbdownloadsize')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onLongPress: () {
                          showOkDialog(
                              context,
                              translations.trans('dbusermsg').replaceFirst(
                                  '%s', imgSize[translations.dbLanguageCode]!));
                        },
                      ),
                      RadioTile(
                        value: Database.all,
                        groupValue: _database,
                        setGroupValue: _setDatabase,
                        title: Text(
                          translations.trans('dballname'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${imgZipSize['global']}${translations.trans('dbdownloadsize')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onLongPress: () {
                          showOkDialog(
                              context,
                              translations
                                  .trans('dballmsg')
                                  .replaceFirst('%s', imgSize['global']!));
                        },
                      ),
                      _downloadButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _welcomeMessage() {
    return Row(
      children: <Widget>[
        Icon(
          MdiIcons.database,
          size: 50,
          color: widget.switching
              ? Settings.majorAccentColor.withOpacity(0.8)
              : Colors.grey,
        ),
        Container(
          padding: const EdgeInsets.all(4),
        ),
        Expanded(
          child: Text(
            widget.switching
                ? '${Translations.of(context).trans('database')} ${Translations.of(context).trans('switching')}'
                : Translations.of(context).trans('welcome'),
            maxLines: 4,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  _downloadButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.switching
                ? Settings.majorColor.withAlpha(200)
                : Colors.purple.shade400,
          ),
          onPressed: _onDownloadButtonPressed,
          child: SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(Translations.of(context).trans('download')),
                const Icon(Icons.keyboard_arrow_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onDownloadButtonPressed() async {
    if (_database == Database.all) {
      if (!await showYesNoDialog(
          context,
          Translations.of(context).trans('dbwarn'),
          Translations.of(context).trans('warning'))) {
        return;
      }
    }
    if (widget.switching) {
      var dir = await getApplicationDocumentsDirectory();
      try {
        await ((await openDatabase('${dir.path}/data/data.db')).close());
        await deleteDatabase('${dir.path}/data/data.db');
        await Directory('${dir.path}/data').delete(recursive: true);
      } catch (_) {}
    }
    print(Translations.of(context).dbLanguageCode);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => DataBaseDownloadPage(
              dbType: _database == Database.all
                  ? 'global'
                  : Translations.of(context).dbLanguageCode,
            )));
  }

  _dbSelector() {
    return AnimatedOpacity(
      opacity: languageBox ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 700),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
          child: GestureDetector(
            child: SizedBox(
              child: Text(Translations.of(context).trans('dbalready'),
                  style: TextStyle(
                      color: widget.switching
                          ? Settings.majorAccentColor
                          : Colors.purpleAccent.shade100,
                      fontSize: 12.0)),
            ),
            // onTap: () async {
            //   var path = await getFile();

            //   if (path == '') return;
            //   Navigator.of(context).push(MaterialPageRoute(
            //       builder: (context) => DataBaseDownloadPage(
            //             dbType: _database == Database.all
            //                 ? 'global'
            //                 : Translations.of(context).locale.languageCode,
            //             isExistsDataBase: true,
            //             dbPath: path,
            //           )));
            // },
          ),
        ),
      ),
    );
  }

  _languageSelector() {
    return AnimatedOpacity(
      opacity: languageBox ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 700),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
          child: InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0))),
            child: const SizedBox(
              width: 150,
              height: 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.language,
                    size: 35,
                    color: Colors.white70,
                  ),
                  Text('  Language',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))
                ],
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Theme(
                  data: Theme.of(context).copyWith(primaryColor: Colors.pink),
                  child: CountryPickerDialog(
                    titlePadding: const EdgeInsets.symmetric(vertical: 16),
                    // searchCursorColor: Colors.pinkAccent,
                    // searchInputDecoration:
                    //     InputDecoration(hintText: 'Search...'),
                    // isSearchable: true,
                    title: const Text('Select Language'),
                    onValuePicked: (Country country) async {
                      var exc = country as ExCountry;
                      await Translations.of(context).load(exc.toString());
                      await Settings.setLanguage(exc.toString());
                      setState(() {});
                    },
                    itemFilter: (c) => [].contains(c.isoCode),
                    priorityList: [
                      ExCountry.create('US'),
                      ExCountry.create('KR'),
                      ExCountry.create('JP'),
                      ExCountry.create('CN', script: 'Hant'),
                      ExCountry.create('CN', script: 'Hans'),
                      // ExCountry.create('IT'),
                      // ExCountry.create('ES'),
                      // CountryPickerUtils.getCountryByIsoCode('RU'),
                    ],
                    itemBuilder: (Country country) {
                      return Row(
                        children: <Widget>[
                          CountryPickerUtils.getDefaultFlagImage(country),
                          const SizedBox(
                            width: 8.0,
                            height: 30,
                          ),
                          Text((country as ExCountry).getDisplayLanguage()),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<String> getFile() async {
    var filename = (await FilePicker.platform.pickFiles(
      type: FileType.any,
    ))!
        .files
        .single
        .path;

    if (filename == null) {
      await showOkDialog(
          context, Translations.of(context).trans('dbalreadyerr'));
      return '';
    }

    File file;
    file = File(filename);

    return file.path;
  }
}
