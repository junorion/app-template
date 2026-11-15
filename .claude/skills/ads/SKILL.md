---
name: ads
description: 앱에 AdMob 배너 광고를 붙이고 출시 서류까지 맞춘다 — WebView 앱(네이티브 AdView 를 웹 자리에 겹침)·Flutter 앱(google_mobile_ads) 견본, 시험/실제 광고 빌드 구분, 동의(UMP), R8 규칙, app-ads.txt, 개인정보처리방침·데이터 보안 답. 광고를 넣거나 광고 있는 앱을 출시할 때 쓴다.
---

# 광고 (AdMob 배너)

스도쿠(WebView, `tier2-ads` 브랜치)와 톡톡런(Flutter)에서 한 것을 정리했다.
**광고를 넣는 것은 되돌리기 어려운 결정이다**(출시 서류가 전부 바뀐다). 사용자에게 먼저 확인받는다.

## 원칙

- 배너만, 화면 아래에. 전면 광고는 쓰지 않는다. 게임 진행·러닝처럼 집중하는 화면에는 두지 않는다.
- 광고를 못 받으면(오프라인, 광고 없음) 자리를 접거나 빈 여백으로 두고 앱은 그대로 돈다. 광고 쪽 예외가 앱으로 오면 안 된다.
- **시험폰에는 절대 실제 광고를 넣지 않는다.** 내 광고를 내가 누르면 무효 클릭으로 AdMob 계정이 막힐 수 있다.
  빌드 옵션으로 `test`(기본) / `live`(Play 에 올릴 AAB 만) / `placeholder`(회색 자리) / `off`(스토어 스크린샷용) 을 고른다.
- AdMob 계정이 없어도 Google 공개 시험 ID 로 끝까지 만들고 확인할 수 있다. 실제 ID 는 마지막에 넣는다.
  앱 ID·광고 단위 ID 는 비밀값이 아니다(앱에 그대로 실린다).

## Flutter 앱

견본: `templates/ads.dart` (상태 관리 없이 동작, `flutter analyze` 통과). `lib/features/ads/` 쯤에 둔다.
1. `flutter pub add google_mobile_ads`
2. `AndroidManifest.xml` `<application>` 안에 앱 ID meta-data (시험 앱 ID `ca-app-pub-3940256099942544~3347511713`).
3. 화면 틀 아래에 `const AdSlot()`. 설정 화면에 `adsPrivacyRequired()` 가 참일 때만 "광고 개인정보 설정" 줄 → `showAdsPrivacyOptions()`.
4. `android/app/proguard-rules.pro` 에 `templates/proguard-rules.pro` 를 넣고 `build.gradle.kts` release 에
   `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")`.
   **이 규칙이 없으면 release 빌드가 켜지자마자 죽는다**(WorkManager DB 를 R8 이 지움). 디버그에선 안 보인다.
5. 빌드:
   ```sh
   flutter build apk --release --flavor prod                          # 시험폰: 시험 광고
   flutter build apk --release --flavor prod --dart-define=AD_SLOT=off # 스토어 스크린샷
   flutter build appbundle --release --flavor prod --dart-define=AD_SLOT=live   # Play 업로드만
   ```
   AAB 를 만들 때 `AD_SLOT=live` 를 빠뜨리면 시험 광고가 출시된다. 출시 문서의 업데이트 절에 명령을 그대로 적어 둔다.

## WebView 앱

광고를 웹 페이지 안에 넣지 않는다(AdSense 는 앱 WebView 에서 금지). WebView 위에 네이티브 `AdView` 를 겹치고,
웹은 "어디에, 지금 보여도 되는지" 만 알려 준다. 견본: `templates/Ads.java` (스도쿠).
1. `app/build.gradle`: `implementation "com.google.android.gms:play-services-ads:<최신>"`,
   `buildFeatures { buildConfig true }`, defaultConfig 에
   `manifestPlaceholders = [admobAppId: "…"]`, `buildConfigField "String", "BANNER_AD_UNIT", '"…"'`.
   시험·실제를 빌드 옵션으로 가르려면 `project.hasProperty("liveAds")` 로 두 값을 고른다.
2. 매니페스트: `INTERNET` 권한, `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="${admobAppId}"/>`.
3. `MainActivity`: 루트를 `FrameLayout` 으로 감싸 WebView 위에 `ads = new Ads(this, root)`,
   `web.addJavascriptInterface(ads, "AppAds")`, `onPause/onResume/onDestroy` 에서 `ads.pause()/resume()/destroy()`.
4. 웹(`index.html`) — 브라우저에는 `AppAds` 가 없어 아무 일도 안 한다:
   ```js
   function syncAd() {
     if (!window.AppAds) return;
     const r = document.getElementById("adSlot").getBoundingClientRect();
     const show = /* 광고를 보여도 되는 화면인가 */ && r.width > 0 && r.height > 0;
     try { show ? AppAds.place(r.left, r.top, r.width, r.height) : AppAds.hide(); } catch (e) {}
   }
   addEventListener("resize", () => requestAnimationFrame(syncAd));
   // 화면 전환·오버레이 열고 닫을 때도 syncAd()
   ```
   `#adSlot` 은 높이 50px 이상 빈 칸. viewport 가 `device-width` 라 CSS 픽셀 = dp 이다.
5. 축소(`minifyEnabled`)를 켜면 JS 인터페이스 메서드가 지워지지 않게 keep 규칙과 위 WorkManager 규칙을 함께 넣는다.

## AdMob 콘솔 (사용자 몫, PC 브라우저)

1. admob.google.com → 앱 → 앱 추가 → "Google Play 에 게시되었나요?" **아니요**(출시 뒤 연결) → 앱 ID 복사.
2. 광고 단위 → 배너 → 이름(`<앱-id>_bottom_banner`) → 광고 단위 ID 복사. 둘 다 받아 코드에 넣는다.
3. 개인정보 보호 및 메시지 → **유럽 규정 메시지** 만들기·게시(동의 창 문구는 Google 이 만든다). 안 하면 유럽에서 광고가 안 나온다.
4. 설정 → 테스트 기기에 시험폰 등록(광고 ID 는 폰 설정 › Google › 광고). 정식 앱에서도 그 폰엔 시험 광고만 나온다.
5. **출시 뒤**: 앱을 Play 스토어 등록정보와 연결 → "앱 준비 검토" 통과해야 광고가 제대로 나온다. app-ads.txt 탭에서 "확인됨" 확인.

## app-ads.txt

개발자 웹사이트 루트에 있어야 한다. 사용자 사이트는 공개 저장소 `junorion/junorion.github.io`
(→ `https://junorion.github.io/app-ads.txt`, 개발자 첫 페이지 겸용). 앱마다 새로 만들지 않는다 — 같은 AdMob 계정이면 한 줄이 모든 앱에 통한다:
```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```
Play Console › 스토어 등록정보 › 연락처 세부정보의 **웹사이트**에 `https://junorion.github.io` 를 넣어야 AdMob 이 찾는다(크롤링에 하루쯤).

## 출시 서류에 반영 (빠뜨리면 심사 거절)

광고를 넣는 순간 "수집하지 않음" 이던 답이 모두 바뀐다. `play-release` 와 함께 고친다.
- **개인정보처리방침**에 광고 절: Google Mobile Ads SDK 가 보내는 것(광고 ID 등 기기 식별자, IP·대략적 위치,
  광고 노출·클릭, 기기·앱 정보·진단), 쓰임(광고 제공·측정·부정 클릭 방지), 앱 고유 데이터는 광고에 넘기지 않는다는 문장,
  동의 변경(앱 설정)·광고 ID 재설정(기기 설정) 방법, Google 파트너 사이트 정책 링크. 예: 톡톡런 `privacy.html` 5절.
- **앱 콘텐츠**: 광고 "예", 광고 ID "예(광고·분석)", 타겟층은 13세 미만 제외(어린이 대상이면 가족 정책·인증 SDK 필요).
- **데이터 보안**: 대략적 위치·앱 상호작용·기기 ID 를 "수집함, 공유함(Ads SDK), 필수" 로. 톡톡런 `store/LISTING.md` 표를 출발점으로.
- 매니페스트에 `INTERNET`·`AD_ID` 가 생기는지 `aapt dump badging` 으로 확인(`AD_ID` 는 SDK 가 병합해 넣는다).
- release APK 를 실기기에서 꼭 켜 보고 시험 배너가 뜨는지 본다(`device`).
