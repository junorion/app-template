#!/usr/bin/env bash
# USB 로 연결한 시험폰을 WSL 에서 다룬다. Windows adb.exe 를 쓴다(WSL 은 USB 를 못 본다).
#
#   phone.sh check                 연결·모델·Android 버전·잠금 여부
#   phone.sh install <apk>         설치(덮어쓰기). 서명이 달라 거부되면 지우지 말고 멈춘다
#   phone.sh shot <out.png>        스크린샷 (PNG, 기기 해상도 그대로)
#   phone.sh ui [글자]             화면의 글자·설명과 좌표(가운데) 목록. 글자를 주면 그 줄만
#   phone.sh tap <글자>            그 글자가 보이는 요소의 가운데를 누른다
#   phone.sh stayon | restore      USB 연결 중 화면 켜 둠 / 원래 값으로 되돌림
#   phone.sh log [패키지]          logcat (패키지를 주면 그 앱 프로세스만)
#   phone.sh share                 C:\Users\junor\apk-share 를 LAN 에 공유(http://<PC IP>:8000/)
#
# 환경 변수 ADB (기본 /mnt/c/Users/junor/platform-tools/adb.exe)
set -euo pipefail
ADB=${ADB:-/mnt/c/Users/junor/platform-tools/adb.exe}
SHARE='C:\Users\junor\apk-share'
STATE=/data/local/tmp/stayon.prev   # record.sh 와 같은 파일
a() { "$ADB" "$@" | tr -d '\r'; }
die() { echo "phone: $*" >&2; exit 1; }
need() { [ "$(a get-state 2>/dev/null)" = device ] || die "폰이 연결되어 있지 않습니다. USB 디버깅 허용 창이 떠 있으면 폰에서 허용을 누르세요"; }
winpath() { case "$1" in /mnt/*) wslpath -w "$1" ;; *) echo "$1" ;; esac; }
# uiautomator 덤프에서 text/content-desc 와 가운데 좌표를 뽑는다: "x y 글자"
ui_list() {
  a shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || die "화면을 읽지 못했습니다(1초마다 바뀌는 알림이 있으면 실패한다 — shot 으로 보고 좌표로 누르세요)"
  a shell cat /sdcard/ui.xml | grep -o '<node [^>]*>' | python3 -c '
import re, sys
for n in sys.stdin:
    b = re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", n)
    for k in ("text", "content-desc"):
        m = re.search(k + r"=\"([^\"]+)\"", n)
        if m and b:
            x1, y1, x2, y2 = map(int, b.groups())
            print((x1 + x2) // 2, (y1 + y2) // 2, m.group(1))'
}

cmd=${1:-}; shift || true
case "$cmd" in
check)
  need
  echo "모델 $(a shell getprop ro.product.model) · Android $(a shell getprop ro.build.version.release) (API $(a shell getprop ro.build.version.sdk)) · $(a shell wm size | sed 's/.*: //')"
  a shell dumpsys window | grep -o 'isKeyguardShowing=[a-z]*' | head -1 | sed 's/isKeyguardShowing=true/잠김 — 잠금을 풀어 주세요/; s/isKeyguardShowing=false/잠금 풀림/'
  ;;
install)
  need; apk=${1:?apk 경로가 필요합니다}; [ -f "$apk" ] || die "$apk 가 없습니다"
  case "$apk" in /mnt/*) ;; *) cp "$apk" "/mnt/c/Users/junor/apk-share/.install.apk"; apk=/mnt/c/Users/junor/apk-share/.install.apk ;; esac
  out=$(a install -r "$(winpath "$apk")" 2>&1 || true); echo "$out" | tail -2
  rm -f /mnt/c/Users/junor/apk-share/.install.apk
  case "$out" in
    *UPDATE_INCOMPATIBLE*) die "설치된 앱과 서명이 다릅니다. 지우면 기록이 사라지니 uninstall 하지 말고, 설치된 쪽과 같은 키로 다시 빌드하세요" ;;
    *VERSION_DOWNGRADE*) die "versionCode 가 설치된 앱보다 낮습니다" ;;
    *Success*) ;;
    *) die "설치 실패" ;;
  esac ;;
shot)
  need; out=${1:?출력 PNG 경로가 필요합니다}; mkdir -p "$(dirname "$out")"
  "$ADB" exec-out screencap -p > "$out"; ls -la "$out" ;;
ui)
  need; if [ $# -gt 0 ]; then ui_list | grep -F -- "$1" || true; else ui_list; fi ;;
tap)
  need; t=${1:?누를 글자가 필요합니다}
  hit=$(ui_list | awk -v t="$t" '{x=$1; y=$2; $1=$2=""; sub(/^  /,""); if ($0==t) {print x, y; exit}}')
  [ -n "$hit" ] || hit=$(ui_list | grep -F -- "$t" | head -1 | cut -d' ' -f1,2)
  [ -n "$hit" ] || die "'$t' 를 화면에서 찾지 못했습니다"
  a shell input tap $hit; echo "tap $hit ($t)" ;;
stayon)
  need; a shell "[ -f $STATE ] || settings get global stay_on_while_plugged_in > $STATE"; a shell svc power stayon usb; echo "화면 켜 둠 (끝나면 phone.sh restore)" ;;
restore)
  need; prev=$(a shell "cat $STATE 2>/dev/null" || true)
  a shell settings put global stay_on_while_plugged_in "${prev:-0}"; a shell rm -f "$STATE"
  echo "stay_on_while_plugged_in=$(a shell settings get global stay_on_while_plugged_in)" ;;
log)
  need
  if [ $# -gt 0 ]; then pid=$(a shell pidof "$1" || true); [ -n "$pid" ] || die "$1 이 실행 중이 아닙니다"; "$ADB" logcat -v time --pid="$pid"
  else "$ADB" logcat -v time; fi ;;
share)
  # 메모리 규칙: 이 서버 명령은 settings.json 에 글자 그대로 허용돼 있다. 바꾸면 다시 승인이 필요하다
  powershell.exe -NoProfile -c "Start-Process -WindowStyle Minimized -FilePath 'C:\Python\Python312\python.exe' -ArgumentList '-m','http.server','8000','--bind','0.0.0.0','--directory','$SHARE'"
  ip=$(powershell.exe -NoProfile -c "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.PrefixOrigin -eq 'Dhcp' } | Select-Object -First 1).IPAddress" | tr -d '\r')
  echo "공유 중: http://${ip:-<PC IP>}:8000/  (폴더 $SHARE)" ;;
*)
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
