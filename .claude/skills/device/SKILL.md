---
name: device
description: USB 로 연결한 안드로이드 시험폰을 WSL2 에서 다룬다 — Windows adb.exe, 설치(서명 충돌 시 지우지 않기), 스크린샷, 화면 글자로 누르기, 화면 켜 둠, logcat, 화면 녹화(record.sh), APK LAN 공유. 실기기에 설치·확인·촬영할 때 쓴다.
---

# 실기기 다루기 (WSL2 + USB)

에뮬레이터는 쓸 수 없다(`/dev/kvm` 권한 없음). 실기기 확인은 USB 로 연결한 폰에서 한다.
기기 목록과 특성(진동 없는 태블릿, 주 시험폰 등)은 메모리의 테스트 기기 항목을 본다.

## adb 는 Windows 쪽을 쓴다

WSL 은 USB 장치를 못 본다. `/mnt/c/Users/junor/platform-tools/adb.exe` 를 쓴다.
WSL 의 `~/Android/sdk/platform-tools/adb` 서버를 먼저 띄우면 5037 포트가 겹쳐 "protocol fault" 가 난다.
그랬다면 WSL 쪽에서 `adb kill-server` 를 한 번 하고 다시 Windows adb 로.
`adb.exe` 에 넘기는 PC 경로는 Windows 경로(`wslpath -w`)여야 한다. `/sdcard/...` 같은 기기 경로는 그대로.

연결이 안 되면 사용자에게: 폰을 USB 로 꽂고 → 폰에 뜬 "USB 디버깅을 허용하시겠습니까?" 에서 **허용**
(처음 연결한 PC 면 "이 컴퓨터에서 항상 허용" 체크). 개발자 옵션이 꺼져 있으면 설정 → 휴대전화 정보 →
소프트웨어 정보 → 빌드번호 7번 누르기 → 설정 → 개발자 옵션 → USB 디버깅 켜기.

## scripts/phone.sh

```bash
P=.claude/skills/device/scripts/phone.sh
$P check                 # 모델·Android 버전·해상도·잠금 여부
$P install app.apk       # 덮어쓰기 설치
$P shot out.png          # 스크린샷 → Read 로 열어 본다
$P ui [글자]             # 화면 글자와 가운데 좌표
$P tap "시작"            # 글자로 누르기
$P stayon / restore      # 작업 중 화면 켜 둠 / 원래 값으로
$P log com.junorion.x    # 그 앱 logcat
$P share                 # apk-share 폴더를 LAN 에 공유
```
그 밖의 조작은 `adb.exe shell input tap X Y`, `input swipe`, `input keyevent KEYCODE_HOME|KEYCODE_BACK`,
`cmd statusbar expand-notifications|collapse`, `am start -n <패키지>/.MainActivity`, `am force-stop <패키지>`.

## 설치: 절대 지우지 않는다

- 설치된 앱과 **서명이 다르면** `INSTALL_FAILED_UPDATE_INCOMPATIBLE` 로 거부된다. 이때 `uninstall` 하면
  사용자가 쌓은 기록이 모두 사라진다. 지우지 말고 **설치된 쪽과 같은 키로 다시 빌드**한다.
  - 시험폰에 디버그 서명으로 깔아 둔 앱: 릴리스 빌드도 디버그 키로 서명하는 옵션을 둔다
    (Flutter 는 `flutter-app` 의 `-PdebugSign=true`).
  - 업로드 키로 깔아 둔 앱(스도쿠 태블릿): 릴리스 APK 를 보낸다.
- `versionCode` 가 설치된 것보다 낮으면 `VERSION_DOWNGRADE` 로 거부된다.
- 지워야만 하는 상황이면 무엇이 사라지는지 적어 사용자에게 먼저 묻는다.

## 화면 읽고 누르기

- 좌표를 짐작하지 말고 `ui` 로 글자 위치를 읽거나, `shot` 으로 찍어 Read 로 보고 정한다.
- **1초마다 바뀌는 화면(카운트다운 알림, 러닝 중 시계)이 있으면 `uiautomator dump` 가
  "could not get idle state" 로 실패한다.** 그때는 `shot` 으로 보고 좌표로 누른다.
- 조작 사이에 1–3초 쉰다(애니메이션·창 전환). 결과는 `shot` 으로 확인한다.
- 작업을 길게 할 때는 `stayon` → 끝나면 반드시 `restore`. 잠기면 `input` 이 잠금 화면에 들어간다.
- 폰의 원래 상태(빠른 설정 타일, 설정값)를 바꿨으면 작업 끝에 되돌리고 바꾼 것을 보고한다.

## 화면 녹화: scripts/record.sh

```bash
R=.claude/skills/device/scripts/record.sh
$R start <이름> [최대초]   # 기기 안에서 screenrecord 시작 + 화면 켜 둠
# ... adb 로 조작 ...
$R stop <이름>             # → C:\Users\junor\apk-share\fgs-videos\<이름>.mp4, 화면 설정 되돌림
$R frames <mp4> [1,4,7]    # 여러 시점 장면을 한 장으로 → Read 로 확인
```
- `screenrecord` 는 **소리를 녹음하지 않고**, 한 번에 최대 180초다.
- 삼성 기기 자체 화면 녹화는 기종에 따라 막혀 있다(A32). 그래서 adb 로 찍는다.
- 다른 앱 알림·시험 광고가 찍히지 않게 먼저 치운다. 알림 지우기는 adb 로 안정적으로 안 되니 사용자에게 부탁한다.
- 바깥에서 걸어야 하는 장면처럼 USB 로 못 찍는 것은 사용자가 폰의 녹화 앱으로 찍는다.

## 폰으로 파일 보내기 (USB 가 없을 때)

`phone.sh share` 가 Windows Python 으로 `C:\Users\junor\apk-share` 를 8000 포트에 공유한다.
사용자는 폰 Chrome 에서 `http://<PC IP>:8000/` 을 열어 APK 를 받는다(같은 Wi-Fi).
- 시험 APK 는 버전 없는 고정 이름(`<앱-id>.apk`)으로 덮어쓴다.
- 브라우저로 받은 APK 는 옛 파일이 남아 업데이트가 안 된 것처럼 보일 수 있다. USB 가 되면 `install` 로.
- 레이아웃 스크린샷도 이 폴더 아래 `<주제>/index.html` 로 모아 두면 사용자가 PC·폰에서 본다.

## 로그

`$P log <패키지>` 는 앱이 실행 중이어야 한다. 시작하자마자 죽는 앱은 `adb.exe logcat -v time -d | grep -E 'FATAL|AndroidRuntime' -A 20`
으로 마지막 충돌을 본다. 릴리스 빌드에서만 죽으면 R8 축소부터 의심한다(`android-build`, `flutter-app`).
