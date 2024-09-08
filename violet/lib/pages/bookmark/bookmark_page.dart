// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:math';

import 'package:animated_widgets/animated_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/bookmark/crop_bookmark.dart';
import 'package:violet/pages/bookmark/group/group_article_list_page.dart';
import 'package:violet/pages/bookmark/group_modify.dart';
import 'package:violet/pages/bookmark/record_view_page.dart';
import 'package:violet/pages/common/toast.dart';
import 'package:violet/pages/segment/double_tap_to_top.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/style/palette.dart';
import 'package:violet/widgets/theme_switchable_state.dart';

class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends ThemeSwitchableState<BookmarkPage>
    with AutomaticKeepAliveClientMixin<BookmarkPage>, DoubleTapToTopMixin {
  @override
  bool get wantKeepAlive => true;
  bool reorder = false;

  @override
  VoidCallback? get shouldReloadCallback => null;

  static const int _kReservedPreIndex = 2;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: FutureBuilder(
        future: Bookmark.getInstance().then((value) => value.getGroup()),
        builder: _reorderFutureBuilder,
      ),
      floatingActionButton: SpeedDial(
        childMargin: const EdgeInsets.only(right: 18, bottom: 20),
        animatedIcon: AnimatedIcons.menu_close,
        animatedIconTheme: const IconThemeData(size: 22.0),
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.transparent,
        overlayOpacity: 0.2,
        heroTag: 'speed-dial-hero-tag',
        backgroundColor: Settings.themeWhat
            ? Settings.themeBlack
                ? Palette.blackThemeBackground
                : Colors.grey.shade800
            : Colors.white,
        foregroundColor: Settings.majorColor,
        elevation: 1.0,
        shape: const CircleBorder(),
        children: [
          _dialButton(MdiIcons.orderNumericAscending, 'editorder', () async {
            setState(() {
              reorder = !reorder;
            });
          }),
          _dialButton(MdiIcons.group, 'newgroup', () async {
            (await Bookmark.getInstance()).createGroup(
                Translations.instance!.trans('newgroup'),
                Translations.instance!.trans('newgroup'),
                Colors.orange);
            setState(() {});
          }),
        ],
      ),
    );
  }

  _dialButton(IconData? icon, String label, Function() onTap) {
    return SpeedDialChild(
      child: Icon(icon, color: Settings.majorColor),
      backgroundColor: Settings.themeWhat
          ? Settings.themeBlack
              ? Palette.blackThemeBackground
              : Colors.grey.shade800
          : Colors.white,
      label: Translations.instance!.trans(label),
      labelStyle: TextStyle(
        fontSize: 14.0,
        color: Settings.themeWhat ? Colors.white : Colors.grey.shade800,
      ),
      labelBackgroundColor: Settings.themeWhat
          ? Settings.themeBlack
              ? Palette.blackThemeBackground
              : Colors.grey.shade800
          : Colors.white,
      onTap: onTap,
    );
  }

  Widget _reorderFutureBuilder(
      BuildContext context, AsyncSnapshot<List<BookmarkGroup>> snapshot) {
    if (!snapshot.hasData) {
      return const Center(
        child: Text('Loading ...'),
      );
    }

    final double statusBarHeight = MediaQuery.of(context).padding.top;

    final scrollController =
        doubleTapToTopScrollController = PrimaryScrollController.of(context);

    final rows = _buildRowItems(snapshot.data!, reorder);

    return reorder
        ? Theme(
            data: Theme.of(context).copyWith(
              // https://github.com/flutter/flutter/issues/45799#issuecomment-770692808
              // Fuck you!!
              canvasColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            child: ReorderableListView(
              padding: EdgeInsets.fromLTRB(4, statusBarHeight + 16, 4, 8),
              scrollDirection: Axis.vertical,
              scrollController: scrollController,
              children: rows,
              onReorder: _onReorder,
            ),
          )
        : ListView.builder(
            padding: EdgeInsets.fromLTRB(4, statusBarHeight + 16, 4, 8),
            physics: const BouncingScrollPhysics(),
            controller: scrollController,
            itemCount: snapshot.data!.length + _kReservedPreIndex,
            itemBuilder: (BuildContext ctxt, int index) {
              return _buildItem(
                  index,
                  index < _kReservedPreIndex
                      ? null
                      : snapshot.data![index - _kReservedPreIndex]);
            },
          );
  }

  _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex * newIndex <= _kReservedPreIndex ||
        oldIndex <= _kReservedPreIndex ||
        newIndex <= _kReservedPreIndex) {
      showToast(
        level: ToastLevel.error,
        message: 'You cannot move like that!',
      );
      return;
    }

    var bookmark = await Bookmark.getInstance();
    if (oldIndex < newIndex) newIndex -= _kReservedPreIndex;
    await bookmark.positionSwap(
        oldIndex - _kReservedPreIndex, newIndex - _kReservedPreIndex);
    setState(() {});
  }

  _buildItem(int index, BookmarkGroup? data, [bool reorder = false]) {
    index -= _kReservedPreIndex;

    String name;
    String oname = '';
    String desc;
    String date = '';
    int id;

    if (index == -2) {
      name = Translations.instance!.trans('readrecord');
      desc = Translations.instance!.trans('readrecorddesc');
      id = -2;
    } else if (index == -1) {
      name = Translations.instance!.trans('cropbookmark');
      desc = Translations.instance!.trans('cropbookmarkdesc');
      id = -1;
    } else {
      name = data!.name();
      oname = name;
      desc = data.description();
      date = data.datetime().split(' ')[0];
      id = data.id();
    }

    if (name == 'violet_default') {
      name = Translations.instance!.trans('unclassified');
      desc = Translations.instance!.trans('unclassifieddesc');
    }

    final random = Random();

    return Container(
      key: Key('bookmark_group_$id'),
      child: ShakeAnimatedWidget(
        enabled: reorder,
        duration: Duration(milliseconds: 300 + random.nextInt(50)),
        shakeAngle: Rotation.deg(z: 0.8),
        curve: Curves.linear,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Settings.themeWhat ? Colors.black26 : Colors.white,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: Settings.themeWhat
                    ? Colors.black26
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: Settings.themeWhat ? 0 : 5,
                blurRadius: 7,
                offset: const Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Material(
              color: Settings.themeWhat
                  ? Settings.themeBlack
                      ? Palette.blackThemeBackground
                      : Colors.black38
                  : Colors.white,
              child: ListTile(
                title: Text(name, style: const TextStyle(fontSize: 16.0)),
                subtitle: Text(desc),
                trailing: Text(date),
                onTap: reorder
                    ? null
                    : () {
                        PlatformNavigator.navigateSlide(
                          context,
                          id == -2
                              ? const RecordViewPage()
                              : id == -1
                                  ? const CropBookmarkPage()
                                  : GroupArticleListPage(
                                      groupId: id, name: name),
                          opaque: false,
                        );
                      },
                onLongPress: reorder
                    ? null
                    : () async {
                        _onLongPressBookmarkItem(index, oname, name, data);
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }

  _onLongPressBookmarkItem(
      int index, String oname, String name, BookmarkGroup? data) async {
    if (index < 0 || (oname == 'violet_default' && index == 0)) {
      await showOkDialog(
          context,
          Translations.instance!.trans('cannotmodifydefaultgroup'),
          Translations.instance!.trans('bookmark'));
      return;
    }

    final rr = await showDialog(
      context: context,
      builder: (BuildContext context) =>
          GroupModifyPage(name: name, desc: data!.description()),
    );

    if (rr == null) return;

    if (rr[0] == 2) {
      await (await Bookmark.getInstance()).deleteGroup(data!);
    } else if (rr[0] == 1) {
      final nname = rr[1] as String;
      final ndesc = rr[2] as String;

      final rrt = Map<String, dynamic>.from(data!.result);

      rrt['Name'] = nname;
      rrt['Description'] = ndesc;

      await (await Bookmark.getInstance())
          .modfiyGroup(BookmarkGroup(result: rrt));
    }

    setState(() {});
  }

  _buildRowItems(List<BookmarkGroup> data, [bool reorder = false]) {
    var ll = <Widget>[];
    for (int index = 0; index < data.length + _kReservedPreIndex; index++) {
      ll.add(
        _buildItem(
          index,
          index < _kReservedPreIndex ? null : data[index - _kReservedPreIndex],
          reorder,
        ),
      );
    }

    return ll;
  }
}
