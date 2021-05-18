// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/settings/settings.dart';

class FAQPageKorean extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Settings.majorColor,
        title: Text('FAQ'),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('하단 메뉴바가 안보입니다.'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              '설정에서 Drawer 옵션이 켜져있는지 확인해주세요. Drawer 메뉴는 메인 화면에서 화면 왼쪽 끝에서 오른쪽으로 밀면 열 수 있습니다.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('썸네일들이 로딩이 안됩니다.'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              'VPN이나 DPI 우회 프로그램(1.1.1.1 또는 Intra 등)이 실행 중인지 확인해주세요.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('최신 작품들이 안보입니다.'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              '데이터베이스를 동기화하거나 웹검색을 사용해주세요. 자세한건 유저 메뉴얼을 참고해주세요.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('북마크를 백업하고 싶어요.'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              '설정 => 북마크 => 북마크 내보내기를 통해 북마크를 외부 저장소로 내보내고, /Android/data/xyz.project.violet/files/bookmark.db를 다른 안전한 장소에 백업해주세요. '
                              '북마크를 안전한 장소에 백업하지않고 앱을 삭제하면 모든 정보가 삭제되니 주의해주세요.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('다운로드가 너무 느립니다.'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              'DPI Bypass 툴(Intra, 유니콘 등)이 실행중이라면 종료하고 재시도해보세요. 그래도 느리고, 느린이유가 앱 문제라고 생각한다면 오류 및 버그 항목으로 문의주세요.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('다운로드된 파일은 어디에 저장되나요?'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text('기본적으로 외부 저장소의 Violet 폴더에 저장됩니다.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('앱에 바이러스나 해킹기능, 백도어가 포함되어있나요?'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text('해당 기능은 포함되어있지 않습니다.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('검색이 조금 빨랐으면 좋겠어요.'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              '한국어 작품만 빠르게 검색하고 보고싶다면 일단 설정=>기본 태그를 (lang:korean or lang:n/a)에서 (lang:korean)으로 바꾸세요.' +
                                  ' 그 다음 데이터베이스 최적화 옵션을 켜고 데이터베이스 리빌딩을 실행해주세요.' +
                                  ' 그 다음 태그 리빌딩을 실행해주세요. 이 과정은 기본 태그와 제외 태그를 설정한 상태에서 필요없는 모든 데이터를 삭제하여 성능을 최적화하는 과정입니다.'
                                      ' 만약 기본 태그와 제외 태그를 통해 검색 범위를 줄이지 않는다면 성능 이점을 얻을 수 없습니다.',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              height: 0.5,
              color: Settings.themeWhat
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
            ExpandableNotifier(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: ScrollOnExpand(
                  child: ExpandablePanel(
                    theme: ExpandableThemeData(
                        iconColor:
                            Settings.themeWhat ? Colors.white : Colors.grey,
                        animationDuration: const Duration(milliseconds: 500)),
                    header: Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                      child: Text('위에 나오지않은 다른 문제를 겪고있어요'),
                    ),
                    expanded: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Column(
                        children: [
                          Text(
                              '유저 메뉴얼을 봐도, FAQ를 봐도 해결되지 않는 문제가 있다면, 메일이나 디스코드 채널을 통해 개발자에게 알려주세요!',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
