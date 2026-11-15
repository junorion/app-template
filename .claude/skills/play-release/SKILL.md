---
name: play-release
description: Google Play 출시 준비 — 요건(테스터 12명×14일, targetSdk), 스토어 자료(아이콘·그래픽·스크린샷·문안), 개인정보처리방침 페이지, 포그라운드 서비스 영상(adb 녹화), AAB, 사용자가 Play Console 에서 할 단계 안내. 앱을 Play 에 올리거나 업데이트할 때 쓴다.
---

# Play 스토어 출시

완성된 예시: 스도쿠 저장소의 `store/` (`/home/noble/app_development/sudoku/store/`) —
`PUBLISHING.md`(콘솔 단계별 절차), `LISTING.md`(문안·설문 답), `TESTERS.md`(테스터 모집·안내문),
`capture.sh`·`shots.html`(스크린샷), `graphic.html`·`capture-graphic.sh`(그래픽 이미지).
새 앱은 이 파일들을 `store/` 로 복사해 앱에 맞게 고치는 데서 시작한다.

## 먼저 확인할 것 (일정을 좌우함)

1. **개인 개발자 계정은 테스터 12명이 14일 연속** 비공개 테스트에 참여해야 프로덕션을
   신청할 수 있다. 동시에 12명, 한 명이 빠지면 다시 14일 → 15~20명을 모은다.
   **"내부 테스트" 트랙은 세지 않는다** — 반드시 "비공개 테스트". 조직 계정은 면제(D-U-N-S 필요).
2. **targetSdk 요구가 매년 오른다** (2026-08-31 부터 API 36). 출시 전 웹에서 현재 요구를 다시
   확인하고 `compileSdk`/`targetSdk` 를 맞춘다. AGP 도 그에 맞게 올려야 할 수 있다.

## 준비물 체크리스트

| 항목 | 규격 / 방법 |
|---|---|
| AAB | `./gradlew bundleRelease` (`android-build`), 업로드 키 서명, versionCode 증가 |
| 앱 아이콘 | 512×512 **32비트 PNG(알파 포함)** — `icon-512.png` (`app-icon`) |
| 그래픽 이미지 | 1024×500 PNG — HTML 로 그려 `web-verify/scripts/shot.sh graphic.html out.png 1024 500` |
| 휴대전화 스크린샷 | 2~8장, 1080×1920(9:16). 원본을 찍고 `scripts/frame.sh` 로 제목·부제를 얹는다 (아래) |
| 문안 | 앱 이름(30자), 짧은 설명(80자), 자세한 설명(4000자) — 한국어·영어 |
| 개인정보처리방침 | `privacy.html` 을 저장소 루트에 두고 Pages 로 서빙: `https://junorion.github.io/<앱-id>/privacy.html` |
| 콘텐츠 등급·데이터 보안·타겟층 | 설문 답을 `store/LISTING.md` 에 미리 적어 둔다 |
| 포그라운드 서비스 영상 | FGS 를 쓰는 앱만. 종류마다 하나씩, YouTube 일부 공개 링크 (아래) |

## 개인정보처리방침

수집하는 것이 없어도 URL 은 필수다. 스도쿠 `privacy.html` 을 출발점으로 쓰고 **실제와 맞게**
고친다 — 광고(AdMob)·분석·계정·서버를 붙이면 수집 항목과 제3자 제공을 반드시 적고,
Play Console 의 데이터 보안 답도 함께 바꾼다. 문의처는 앱 저장소
(`https://github.com/junorion/<앱-id>`). 배포 후 `curl` 로 200 을 확인한다.

## 스토어 스크린샷

Play 규격: 각 변 320–3840px, 긴 변이 짧은 변의 2배 이하. 폰 원본(1080×2400 = 2.22:1)은 그대로 못 올린다.
그래서 원본 위·아래 바를 잘라 내고 1080×1920 틀에 제목·부제와 함께 넣는다.

1. **원본 찍기** — 둘 중 하나.
   - 실기기: `device` 스킬 `phone.sh shot store/raw/1-ready.png`. 실제 데이터가 있어야 그럴듯한 화면
     (러닝 기록, 지도)은 사용자가 실제로 쓴 뒤 찍는다. 시험 광고·다른 앱 알림이 없는 빌드·상태로.
   - 웹앱: 앱 상태를 심는 촬영대 페이지를 만들어 `web-verify` 의 `shot.sh` 로 찍는다
     (예: 스도쿠 `store/shots.html` — 실제 조작만으로 장면을 만든다).
   - `store/raw/` 는 `.gitignore` 에 넣는다. 지도에 집·동네가 보이면 공개해도 되는지 사용자에게 묻는다.
2. **문구** — `store/captions.txt`(영어는 `captions-en.txt`), 한 줄에 `원본이름|제목|부제`.
   첫 두 장이 검색 결과에 보이니 앱의 핵심 두 가지를 앞에 둔다.
3. **틀 씌우기** —
   ```bash
   F=.claude/skills/play-release/scripts/frame.sh
   ACCENT='#2E9E5B' $F store/captions.txt              # 폰 원본(A32: 위 80·아래 126 px 자름)
   TOP=0 BOTTOM=0 $F store/captions-en.txt store/raw-en # 바가 없는 웹 화면 원본
   ```
   → `store/screenshot-1.png …`(영어는 `screenshot-en-1.png …`). 다른 기종은 상태바·내비게이션 바 높이를 재서 `TOP`·`BOTTOM` 으로.
4. 결과를 한 장에 모아 Read 로 보고, 레이아웃이 정해지면 사용자에게 보여 고르게 한다.

## 포그라운드 서비스 영상

앱이 포그라운드 서비스(FGS)를 쓰면 Play Console 의 **앱 콘텐츠 → 포그라운드 서비스 권한**에서
종류(`location`, `mediaPlayback`, `health` …)마다 사용 설명과 **영상 링크 하나**를 낸다.
영상 하나에 담을 것: 앱에서 기능을 켬 → 홈으로 나가도 계속 돎(알림이 보임) → 알림을 펼쳐 상태 확인 → 끔.
30초–1분이면 된다. 찍은 파일과 링크는 `store/LISTING.md` 의 해당 신고 답 아래에 적는다.

**USB 로 찍을 수 있는 영상**(집 안에서 재현되는 것)은 `device` 스킬의 `scripts/record.sh` 로 찍는다.

```bash
R=.claude/skills/device/scripts/record.sh
$R start <앱-id>-fgs-mediaPlayback      # 화면 켜 둠 + 기기 안에서 녹화 시작
# device/scripts/phone.sh tap·shot, adb shell input keyevent KEYCODE_HOME 등으로 조작
$R stop  <앱-id>-fgs-mediaPlayback      # → C:\Users\junor\apk-share\fgs-videos\, 화면 설정 되돌림
$R frames /mnt/c/Users/junor/apk-share/fgs-videos/<앱-id>-fgs-mediaPlayback.mp4   # 장면 모아 보기
```

찍기 전에 할 것과 함정(톡톡런, 2026-11-15):
- **광고 자리·시험 광고를 끈 빌드**를 설치한다. 다른 앱 알림은 미리 모두 지운다.
- 삼성 기기 화면 녹화 버튼은 기종에 따라 막혀 있다(A32). adb `screenrecord` 는 된다. 단 **소리는 안 담긴다**.
- 알림에 1초마다 바뀌는 카운트다운이 있으면 `uiautomator dump` 가 idle 을 못 기다려 실패한다.
  `adb exec-out screencap -p` 로 스크린샷을 보고 **고정 좌표로 탭**한다.
- 조작 사이에 2–4초씩 쉬어야 심사자가 무엇이 일어나는지 알아본다. 찍은 뒤 `frames` 로 장면을 확인한다.

**바깥에서만 재현되는 영상**(`location` 처럼 걸어야 거리가 느는 것)은 사용자가 폰의 화면 녹화
앱(삼성 화면 녹화, 막혔으면 XRecorder 등)으로 찍는다. 안내할 순서: 녹화 시작 → 앱에서 시작 →
홈으로 나가 1분쯤 걷기 → 알림 펼쳐 값이 느는 것 보이기 → 앱으로 돌아와 끝내기 → 녹화 정지.
집·동네가 지도에 보이면 공개 여부를 사용자에게 묻는다.

**업로드는 사용자 몫이다.** YouTube Data API 로 올린 영상은 API 감사를 받기 전까지 강제로
비공개가 되어 심사자가 볼 수 없다. PC 브라우저에서 YouTube Studio → 만들기 → 동영상 업로드 →
공개 상태 **일부 공개** → 링크 복사 → Play Console 신고 칸에 붙여넣기 순서로 안내한다.

## 사용자 몫 (계정·신원이 걸린 일)

Play Console 작업은 대신 할 수 없다. `store/PUBLISHING.md` 를 앱에 맞게 고쳐 주고,
단계마다 **PC 브라우저**에서 어느 메뉴를 누르는지, 붙여넣을 값과 올릴 파일 경로를 적는다.
앱 이름·광고 여부·유료 여부·계정 유형처럼 되돌리기 어려운 결정은 사용자에게 확인받는다.

## 출시 후 업데이트

versionCode 올림 → `bundleRelease` → 콘솔에서 같은 트랙에 새 버전 → 출시 노트(ko/en).
권한이나 수집 항목이 바뀌면 데이터 보안·개인정보처리방침을 같이 고친다.
