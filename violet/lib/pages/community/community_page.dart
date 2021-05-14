// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/server/community/article.dart';
import 'package:violet/server/community/session.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/pages/community/signin_dialog.dart';
import 'package:violet/pages/community/signup_dialog.dart';

class CommunityPage extends StatefulWidget {
  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with AutomaticKeepAliveClientMixin<CommunityPage> {
  @override
  bool get wantKeepAlive => true;

  VioletCommunitySession sess;
  String _userId;
  String _userAppId;
  String _userNickName;
  bool _logining = false;

  @override
  void initState() {
    super.initState();

    // load boards
    Future.delayed(Duration(milliseconds: 100)).then((value) async {
      var id = (await SharedPreferences.getInstance())
          .getString('saved_community_id');
      var pw = (await SharedPreferences.getInstance())
          .getString('saved_community_pw');

      _userId = id != null ? id : 'None';
      _userAppId =
          (await SharedPreferences.getInstance()).getString('fa_userid');
      setState(() {});

      if (id != null && pw != null) {
        setState(() {
          _logining = true;
        });
        sess = VioletCommunitySession.lastSession != null
            ? VioletCommunitySession.lastSession
            : await VioletCommunitySession.signIn(id, pw);
        _userNickName =
            (await VioletCommunitySession.getUserInfo(id))['NickName'];
        setState(() {
          _logining = false;
        });
      }

      // [{Id: 1, ShortName: issue, Name: Issue, Description: Leave app issues or improvements here},
      //  {Id: 2, ShortName: general, Name: General, Description: Any Topic}]
      var boards = (await VioletCommunityArticle.getBoards(null))['result'];
      boards.removeWhere((element) => element['ShortName'] == '-- free --');
    });
  }

  Future<void> _trylogin() async {
    var id =
        (await SharedPreferences.getInstance()).getString('saved_community_id');
    var pw =
        (await SharedPreferences.getInstance()).getString('saved_community_pw');

    _userId = id != null ? id : 'None';
    _userAppId = (await SharedPreferences.getInstance()).getString('fa_userid');
    setState(() {});

    if (id != null && pw != null) {
      sess = await VioletCommunitySession.signIn(id, pw);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: statusBarHeight),
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(height: 16),
            _userStatusCard(),
          ],
        ),
      ),
    );
  }

  _userStatusCard() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
          alignment: Alignment.centerLeft,
          height: 80,
          // decoration:
          child: Ink(
            decoration: BoxDecoration(
              color: Settings.themeWhat ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(8)),
              boxShadow: [
                BoxShadow(
                  color: Settings.themeWhat
                      ? Colors.black26
                      : Colors.grey.withOpacity(0.1),
                  spreadRadius: Settings.themeWhat ? 0 : 5,
                  blurRadius: 7,
                  offset: Offset(0, 3), // changes position of shadow
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10.0),
                          bottomLeft: Radius.circular(10.0)),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('User: ',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 16)),
                              Text(' $_userNickName ($_userId)',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          ),
                          Container(
                            height: 2,
                          ),
                          Row(
                            children: [
                              Text('User App Id: ',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 16)),
                              Text(
                                  ' ' +
                                      (_userAppId != null
                                          ? _userAppId.substring(0, 16)
                                          : '') +
                                      '...',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          )
                        ],
                      ),
                    ),
                    onTap: () async {
                      await Dialogs.okDialog(
                          context,
                          '$_userAppId\n\nThis user app id has a unique value on a per app session. If you have any problems using the app, please contact us with above user app id.',
                          'Your User App Id');
                    },
                  ),
                ),
                _buildDivider(),
                Container(
                  height: double.infinity,
                  width: 88,
                  child: _logining
                      ? SizedBox(
                          height: 48,
                          width: 48,
                          child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                SizedBox(
                                    height: 30,
                                    width: 30,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey),
                                    ))
                              ]))
                      : InkWell(
                          customBorder: RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10.0),
                                bottomRight: Radius.circular(10.0)),
                          ),
                          child: Align(
                            alignment: Alignment.center,
                            child: Badge(
                              showBadge: false,
                              badgeContent: Text('N',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12.0)),
                              // badgeColor: Settings.majorAccentColor,
                              child: Icon(
                                  sess == null
                                      ? MdiIcons.accountCancel
                                      : MdiIcons.accountCheck,
                                  size: 30),
                            ),
                          ),
                          onTap: () async {
                            if (sess != null) {
                              return;
                            }

                            var ync = await Dialogs.yesnoDialog(
                                context,
                                'You need to log in to use the community feature. ' +
                                    'If you have an existing id, press "YES" to log in. ' +
                                    'If you do not have an existing id, press "NO" to register for a new one.',
                                'Sign In/Up');

                            if (ync == null) return;

                            String id, pw;

                            if (ync == true) {
                              // signin
                              var r = await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return SignInDialog();
                                  });
                              if (r == null) return;
                              id = r[0];
                              pw = r[1];
                            } else {
                              // signup
                              if (await VioletCommunitySession.checkUserAppId(
                                      _userAppId) !=
                                  'success') {
                                await Dialogs.okDialog(
                                    context,
                                    'You cannot continue, there is an account registered with your UserAppId.' +
                                        ' If you have already registered as a member, please sign in with your existing id.' +
                                        ' If you forgot your login information, please contact developer.');
                                return;
                              }
                              var r = await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return SignUpDialog();
                                  });

                              if (r == null) return;

                              print(await VioletCommunitySession.signUp(
                                  r[0], r[1], _userAppId, r[2]));

                              if (await VioletCommunitySession.signUp(
                                      r[0], r[1], _userAppId, r[2]) ==
                                  'success') {
                                await Dialogs.okDialog(
                                    context, 'Sign up is complete!');
                                id = r[0];
                                pw = r[1];
                              } else {
                                await Dialogs.okDialog(
                                    context, 'Registration has been declined!');
                                return;
                              }
                            }

                            await (await SharedPreferences.getInstance())
                                .setString('saved_community_id', id);
                            await (await SharedPreferences.getInstance())
                                .setString('saved_community_pw', pw);

                            await _trylogin();
                            setState(() {});
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Container _buildDivider() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      height: double.infinity,
      width: 1.0,
      color: Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
    );
  }
}
