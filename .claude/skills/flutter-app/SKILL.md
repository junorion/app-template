---
name: flutter-app
description: Flutter 앱을 시작하고 빌드한다 — flutter create 후 apply.sh 로 prod/dev flavor·업로드 키·시험폰용 디버그 서명·앱 이름 리소스를 입히고, 시험폰 APK·Play AAB 를 만들며, 골든 테스트로 화면 스크린샷을 찍는다. 백그라운드 위치·센서·오디오처럼 네이티브 기능이 많은 앱에 쓴다.
---

# Flutter 앱

톡톡런(`running/app`)에서 정한 것을 뼈대로 만들었다. 웹앱(단일 HTML + WebView)으로 안 되는 것
(화면이 꺼진 채 위치·소리, 센서, 잠금 화면)이 핵심이면 Flutter 로 한다. 종류는 `new-app` 에서 정한다.

## 환경

```sh
export PATH=~/toolchain/flutter/bin:$PATH
export JAVA_HOME=~/toolchain/jdk-17.0.20.1+1
```
`flutter config` 에 Android SDK(`~/Android/sdk`)·JDK 가 지정돼 있다. 첫 APK 빌드 때 Gradle 이 NDK 를 받느라 5분쯤 걸린다.
에뮬레이터는 없다 — 로직은 `flutter test`, 화면은 골든 스크린샷, 실제 동작은 시험폰(`device`).

## 시작

저장소 루트에 `app/` 으로 만든다(웹 템플릿 파일은 `new-app` 이 지운다).
```sh
flutter create --org com.junorion --project-name <앱-id> --platforms android,ios app
.claude/skills/flutter-app/templates/apply.sh app <앱-id> "<한국어 이름>" "<영어 이름>"
cd app && flutter analyze && flutter test
```
`apply.sh` 가 하는 일:
- `android/app/build.gradle.kts` 를 `templates/build.gradle.kts` 로: minSdk 26, targetSdk 36, **prod/dev flavor**
  (dev 는 `.dev` 패키지라 정식 앱 옆에 나란히 깔린다), 업로드 키(`android/key.properties`), `-PdebugSign`, R8 규칙 파일.
- 앱 이름을 flavor 별 `res/values`(영어)·`values-ko`(한국어)로. `resValue` 로 넣으면 lint 의 ExtraTranslation 이 release 빌드를 막는다.
- `.gitignore` 에 `key.properties` `secrets.properties` `test/goldens/`, `analysis_options.yaml` 에서 android/ios/build 제외.
- `test/screenshot_test.dart` 골든 스크린샷 견본.

## 빌드

| 목적 | 명령 (`app/` 에서) | 산출물 |
|---|---|---|
| 시험폰 | `flutter build apk --release --flavor prod --android-project-arg=debugSign=true` | `build/app/outputs/flutter-apk/app-prod-release.apk` |
| 진단·실험 앱 | `flutter build apk --release --flavor dev --android-project-arg=debugSign=true` | `app-dev-release.apk` (정식 앱과 따로 깔림) |
| Play 업로드 | `flutter build appbundle --release --flavor prod` (+ 광고면 `--dart-define=AD_SLOT=live`) | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |

- **시험폰 APK 는 늘 디버그 키로.** 업로드 키가 생긴 뒤 그냥 release 로 빌드하면 업로드 키로 서명돼, 폰에 깔린 앱(디버그 서명)에
  덮어 깔리지 않는다. 지우면 기록이 사라지니 uninstall 하지 않는다(`device`).
- 지도 같은 API 키가 서명 지문(SHA-1)에 묶이면 디버그·업로드·Play 앱 서명 세 지문을 모두 등록해야 한다.
  디버그 지문: `$JAVA_HOME/bin/keytool -list -v -keystore ~/.android/debug.keystore -storepass android | grep SHA1`.
- 버전은 `pubspec.yaml` 의 `version: 1.0.0+1` (이름+코드). Play 에 올릴 때마다 `+` 뒤 숫자를 올린다.
  시험 APK 는 버전을 올리지 않고 고정 이름(`<앱-id>.apk`)으로 공유한다.
- 업로드 키 만들기는 `android-build` 의 서명 절과 같다(`~/keystores/<앱-id>-upload.jks`, 비밀번호 파일 600).
  `android/key.properties` 는 `storeFile=`, `keyAlias=`, `passwordFile=` 세 줄. 키를 만들면 사용자에게 백업을 권한다.
- 빌드 뒤 정적 점검: `aapt dump badging <apk> | grep -E "^package|application-label|targetSdk"`, 서명은
  `apksigner verify --print-certs <apk> | grep DN` (build-tools 안, `JAVA_HOME` 필요. 디버그면 `CN=Android Debug`).
  `keytool -printcert -jarfile` 은 v2 서명만 있는 APK 를 못 읽는다.
- **release APK 는 꼭 실기기에서 켜 본다.** R8 축소는 release 에서만 돌아, SDK 가 이름으로 찾는 클래스가 지워지면
  켜자마자 죽는다(광고 SDK 사례는 `ads`). `device` 의 logcat 으로 `ClassNotFound` 를 보고 `proguard-rules.pro` 에 keep.

## 플러그인이 요구하는 SDK·도구 버전

플러그인이 `compileSdk` 를 더 높게 요구하면(예: permission_handler → 37) 그 숫자로 올린다. targetSdk 는 Play 요구에 맞춘 채 둔다.
그러면 AGP·Gradle 도 올려야 할 수 있다 — 빌드 오류가 알려 주는 최소 버전을 `settings.gradle.kts` 와
`gradle/wrapper/gradle-wrapper.properties` 에 넣는다. 톡톡런은 compileSdk 37 · AGP 9.4.1 · Gradle 9.6.0.

## 화면 스크린샷 (골든 테스트)

```sh
flutter test --update-goldens --tags screenshot test/screenshot_test.dart   # → test/goldens/*.png
```
- 테스트 기본 글꼴은 글자가 네모로 나온다. 견본의 `loadFonts()` 가 맑은 고딕을 `Roboto` 로, Material 아이콘 글꼴을 등록한다.
- 앱 화면을 넣고 저장소·서비스는 가짜로 바꿔 상태를 심는다. 지도 타일처럼 네트워크가 필요한 것은 미리 받은 타일로.
- 레이아웃을 고치는 동안은 이 스크린샷(영어·한국어, 라이트·다크)으로 확인받고, 확정되면 그때 APK 로 폰에서 본다.
- 접근성: 같은 방법으로 `MediaQuery(textScaler: TextScaler.linear(2))` 를 씌워 글자 2배에서 넘침이 없는지 본다.

## 하지 말 것

- **`dart format` 을 디렉터리 전체에 돌리지 않는다.** 코드가 포매터 기준으로 쓰여 있지 않아 수십 파일이 바뀐다. 고친 파일만.
- 화면이 꺼진 채 도는 기능(위치·소리·타이머)은 포그라운드 서비스 종류마다 Play 신고와 영상이 필요하다(`play-release`).
  종류를 늘리기 전에 사용자에게 알린다.
- OS 가 모양을 정하는 UI(미디어 알림 카드 등)보다 Android·iOS 에서 같은 모양을 낼 수 있는 Flutter 화면을 고른다.
