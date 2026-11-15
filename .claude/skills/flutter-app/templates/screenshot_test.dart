// 화면 스크린샷을 골든 테스트로 찍는다 — 실기기 없이 레이아웃을 보여 주거나 영어 화면을 찍을 때.
//   flutter test --update-goldens --tags screenshot test/screenshot_test.dart   → test/goldens/<이름>.png
// 테스트 환경 기본 글꼴(Ahem)은 글자가 네모로 나온다. 그래서 Windows 맑은 고딕을 'Roboto' 로,
// Flutter SDK 의 Material 아이콘 글꼴을 'MaterialIcons' 로 등록한다. FilledButton 등 일부 글자는 그래도 네모일 수 있다.
// 찍은 PNG 는 커밋하지 않는다(test/goldens/ 를 .gitignore 에). 지도 타일처럼 네트워크가 필요한 것은 가짜로 바꿔 끼운다.
@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
}

Future<void> loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/toolchain/flutter';
  await _font('Roboto', '/mnt/c/Windows/Fonts/malgun.ttf');
  await _font('MaterialIcons', '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
}

/// 폰 화면 크기로 [app] 을 찍는다. 기본은 갤럭시 A32(1080×2400, 배율 2.625).
Future<void> shoot(WidgetTester tester, Widget app, String name,
    {Size physical = const Size(1080, 2400), double ratio = 2.625}) async {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await expectLater(find.byWidget(app), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(loadFonts);

  for (final dark in [false, true]) {
    testWidgets('home ${dark ? 'dark' : 'light'}', (tester) async {
      await shoot(
        tester,
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          // 앱의 실제 화면을 넣는다. 저장소·서비스는 가짜로 바꿔 상태를 심는다
          home: Scaffold(
            appBar: AppBar(title: const Text('화면 이름 Screen')),
            body: const Center(child: Icon(Icons.directions_run, size: 96)),
          ),
        ),
        'home-${dark ? 'dark' : 'light'}',
      );
    });
  }
}
