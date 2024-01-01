// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:violet/settings/settings.dart';

class FAQPageKorean extends StatelessWidget {
  const FAQPageKorean({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Settings.majorColor,
        title: const Text('FAQ'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _subitem(
                '하단 메뉴바가 안보입니다.',
                '설정에서 Drawer 옵션이 켜져있는지 확인해주세요.'
                    ' Drawer 메뉴는 메인 화면에서 화면 왼쪽 끝에서 오른쪽으로 밀면 열 수 있습니다.'),
            _divider(),
            _subitem('썸네일들이 로딩이 안됩니다.',
                'VPN이나 DPI 우회 프로그램(1.1.1.1 또는 Intra 등)이 실행 중인지 확인해주세요.'),
            _divider(),
            _subitem(
                '최신 작품들이 안보입니다.',
                '데이터베이스를 동기화하거나 웹검색을 사용해주세요.'
                    ' 자세한건 유저 메뉴얼을 참고해주세요.'),
            _divider(),
            _subitem(
                '북마크를 백업하고 싶어요.',
                '설정 => 북마크 => 북마크 내보내기를 통해 북마크를 외부 저장소로 내보내고,'
                    ' /Android/data/xyz.project.violet/files/bookmark.db를 다른 안전한 장소에 백업해주세요.'
                    ' 북마크를 안전한 장소에 백업하지않고 앱을 삭제하면 모든 정보가 삭제되니 주의해주세요.'),
            _divider(),
            _subitem(
                '북마크를 서버에 백업하고 싶어요.',
                '설정탭에서 "테마-Drawer 사용" 밑에 있는 구름 업로드 표시를 누르면 북마크 및 열람기록이 서버로 백업됩니다.'
                    ' 백업 후 다른 기기에서 복원하려면 UserAppId를 반드시 기억해야합니다.'
                    ' User App Id는 구름 업로드 표시 왼쪽 칸을 누르면 볼 수 있습니다.'),
            _divider(),
            _subitem(
                '다운로드가 너무 느립니다.',
                'DPI Bypass 툴(Intra, 유니콘 등)이 실행중이라면 종료하고 재시도해보세요.'
                    ' 그래도 느리고, 느린이유가 앱 문제라고 생각한다면 오류 및 버그 항목으로 문의주세요.'),
            _divider(),
            _subitem(
                '앱 로딩이 너무 느려요.',
                '"아래 검색이 조금 빨랐으면 좋겠어요."를 따라해보세요.'
                    ' 앱 로딩 시간 중 가장 큰 부분이 인덱싱파일 로딩입니다.'
                    ' 태그 리빌딩을 통해 인덱싱파일의 크기를 줄이면 앱 로딩 시간을 최대 20배까지 단축시킬 수 있습니다.'),
            _divider(),
            _subitem(
                '검색할 때 하얀박스나 오류메시지가 나와요.',
                '데이터베이스가 고장나서 생긴 문제입니다.'
                    ' 데이터베이스 동기화를 통해 데이터베이스를 복구해주세요!'),
            _divider(),
            _subitem(
                '다운로드 시 누락되는 파일들이 있어요.',
                '해당 항목을 길게 눌러서 메뉴를 띄운뒤 Recovery를 눌러주세요.'
                    ' 누락된 파일만 다시 다운로드합니다.'),
            _divider(),
            _subitem('다운로드된 파일은 어디에 저장되나요?', '기본적으로 외부 저장소의 Violet 폴더에 저장됩니다.'),
            _divider(),
            _subitem('앱에 바이러스나 해킹기능, 백도어가 포함되어있나요?', '해당 기능은 포함되어있지 않습니다.'),
            _divider(),
            _subitem(
                '작가 북마크는 어디서 보나요?', '"미분류" 등 북마크 그룹에서 오른쪽으로 슬라이드하면 볼 수 있습니다.'),
            _divider(),
            _subitem(
                '검색이 조금 빨랐으면 좋겠어요.',
                '한국어 작품만 빠르게 검색하고 보고싶다면 일단 설정=>기본 태그를 (lang:korean or lang:n/a)에서 (lang:korean)으로 바꾸세요.'
                    ' 그 다음 데이터베이스 최적화 옵션을 켜고 데이터베이스 리빌딩을 실행해주세요.'
                    ' 그 다음 태그 리빌딩을 실행해주세요.'
                    ' 이 과정은 기본 태그와 제외 태그를 설정한 상태에서 필요없는 모든 데이터를 삭제하여 성능을 최적화하는 과정입니다.'
                    ' 만약 기본 태그와 제외 태그를 통해 검색 범위를 줄이지 않는다면 성능 이점을 얻을 수 없습니다.'),
            _divider(),
            _subitem(
                '위에 나오지않은 다른 문제를 겪고있어요.',
                '유저 메뉴얼을 봐도, FAQ를 봐도 해결되지 않는 문제가 있다면,'
                    ' 메일이나 디스코드 채널을 통해 개발자에게 알려주세요!'),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: double.infinity,
      height: 0.5,
      color: Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
    );
  }

  Widget _subitem(String title, String body) {
    return ExpandableNotifier(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ScrollOnExpand(
          child: ExpandablePanel(
            theme: ExpandableThemeData(
                iconColor: Settings.themeWhat ? Colors.white : Colors.grey,
                animationDuration: const Duration(milliseconds: 500)),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
              child: Text(title),
            ),
            expanded: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                children: [
                  Text(body, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            collapsed: Container(),
          ),
        ),
      ),
    );
  }
}
