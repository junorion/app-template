---
name: app-icon
description: 앱 아이콘(icon-512.png, icon-192.png)과 안드로이드 네이티브 아이콘(런처·적응형 앞면·Android 13 단색·알림 상태바)을 icon.html 에서 만든다 — 헤드리스 Chrome 렌더링 + 순수 파이썬 PNG 리샘플, Play 가 요구하는 32비트 RGBA. 아이콘을 새로 그리거나 바꿀 때 쓴다.
---

# 앱 아이콘 만들기

WSL 에 이미지 라이브러리(PIL, ImageMagick)가 없다. 그래서 아이콘을 **HTML/SVG 로 그리고**
Chrome 으로 찍은 뒤, `zlib`/`struct` 만 쓰는 파이썬으로 RGBA 변환·축소한다.

```sh
bash .claude/skills/app-icon/scripts/render_icon.sh icon.html .
# → ./icon-512.png (512, RGBA), ./icon-192.png (192, RGBA)
```
그 다음 Read 로 `icon-192.png` 를 열어 눈으로 확인한다.

## 그리는 규칙

- `icon.html` 은 512×512 고정, `body` 에 배경을 **가장자리까지** 채운다. manifest 의
  `purpose: "any maskable"` 과 안드로이드 adaptive icon 이 둥글게·사각으로 잘라내므로,
  그림은 **가운데 80%(약 410px) 안**에 둔다.
- 앱 안의 그림(로고, 말, 보드)과 같은 그림을 쓴다 — 홈 화면 아이콘과 앱 첫 화면이 같아야 한다.
- 이모지·시스템 글꼴 글자를 쓰지 않는다 (기기마다 달라 보인다). 글자가 꼭 필요하면 SVG path 로.
- 바꾼 뒤 `sw.js` 의 `CACHE` 버전을 올린다 — 안 그러면 설치된 PWA 가 옛 아이콘을 쥐고 있다.

## 산출물이 쓰이는 곳

| 파일 | 쓰는 곳 |
|---|---|
| `icon-512.png` | manifest, Play 스토어 앱 아이콘(512×512 **32비트 PNG** 필수 — 24비트는 거부될 수 있다), 안드로이드 런처(빌드 때 `mipmap-xxxhdpi` 로 복사) |
| `icon-192.png` | manifest, favicon, apple-touch-icon |

## 안드로이드 네이티브 아이콘 (Flutter 앱, 알림을 쓰는 앱)

Flutter 앱은 `res/mipmap-*` 를 직접 채워야 한다. 그림을 두 장 그린다.
- `icon.html` — 바탕까지 그린 전체 아이콘(위와 같다).
- `icon-foreground.html` — 같은 그림을 **바탕 투명, 0.8 배로 줄여** 가운데에. 적응형 아이콘은 108dp 중 가운데
  66dp 만 확실히 보이므로 그림이 크면 런처 모양(원·물방울)에 잘린다.

```sh
S=.claude/skills/app-icon/scripts
bash $S/android_icons.sh store/icon.html store/icon-foreground.html app/android/app/src/main/res '#FFFFFF' ic_stat_<앱>
```
- 만드는 것: `mipmap-*/ic_launcher.png`(옛 런처), `ic_launcher_foreground.png`(적응형 앞면),
  `ic_launcher_monochrome.png`(Android 13 테마 아이콘), `drawable-*/ic_stat_<앱>.png`(알림 상태바),
  `mipmap-anydpi-v26/ic_launcher.xml`, `drawable/ic_launcher_background.xml`(바탕색). `store/icon-512.png` 도 함께 나온다.
- 단색·상태바는 **바탕색과 다른 픽셀을 흰색으로** 남긴다. 바탕과 비슷한 색으로 그린 부분은 빠지니 결과를 Read 로 본다.
- 알림 작은 아이콘(`setSmallIcon`, 위치 패키지의 `notificationIcon`)에는 앱 아이콘 대신 `ic_stat_<앱>` 을 쓴다.
  색이 있는 아이콘을 쓰면 상태바에 흰 네모로 나온다.
- 글꼴을 쓰면(`@font-face`) 글꼴 파일을 html 옆에 두고 라이선스(OFL 등) 파일도 함께 커밋한다.

## 스크립트

- `render_icon.sh <icon.html> <출력 디렉토리>` — Chrome 스크린샷(배율 1 고정) → 두 크기
- `android_icons.sh <icon.html> <icon-foreground.html> <res> [바탕색] [상태바 이름]` — 위 안드로이드 아이콘 전부
- `png_resize.py <입력> <출력> <px>` — 8비트 RGB/RGBA PNG 를 RGBA 로, 면적 평균 축소.
  `read_png`/`write_png` 는 다른 스크립트에서 import 해 픽셀을 직접 읽을 때도 쓴다.
  스토어 그래픽 이미지(1024×500)처럼 정사각형이 아닌 것은 `web-verify` 의 `shot.sh` 로 찍는다.
