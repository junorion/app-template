#!/usr/bin/env bash
# USB 로 연결한 폰 화면을 adb screenrecord 로 녹화한다 (Play 포그라운드 서비스 신고 영상 등).
#
#   record.sh start  <이름> [최대초=170]   녹화 시작(화면 켜 둠). 이어서 앱을 조작한다
#   record.sh stop   <이름> [받을폴더]      녹화 정지 → PC 로 가져옴 → 화면 설정 되돌림
#   record.sh frames <mp4>  [초,초,...]     확인용으로 여러 시점 장면을 PNG 한 장에 모음
#
# 환경 변수
#   ADB  adb 실행 파일 (기본: Windows adb — WSL 은 USB 를 못 본다)
#   OUT  받을 폴더 (기본: /mnt/c/Users/junor/apk-share/fgs-videos — PC·폰에서 바로 열림)
#
# 주의
#   - screenrecord 는 소리를 녹음하지 않는다. 메트로놈처럼 소리가 핵심이면 영상 설명에 적는다.
#   - 한 번에 최대 180초(Android 제한). 그보다 길면 나눠 찍는다.
#   - 녹화 전에 다른 앱 알림을 모두 지우고, 시험 광고가 보이지 않는 빌드를 설치해 둔다.
set -euo pipefail

ADB=${ADB:-/mnt/c/Users/junor/platform-tools/adb.exe}
OUT=${OUT:-/mnt/c/Users/junor/apk-share/fgs-videos}
STATE=/data/local/tmp/stayon.prev   # 녹화 전 stay_on_while_plugged_in 값 (phone.sh 와 같은 파일)
CHROME="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"

a() { "$ADB" "$@" | tr -d '\r'; }
# adb.exe 에는 Windows 경로를 넘겨야 한다
hostpath() { case "$ADB" in *.exe) wslpath -w "$1" ;; *) echo "$1" ;; esac; }
die() { echo "record: $*" >&2; exit 1; }

cmd=${1:-}; shift || true
case "$cmd" in
start)
  name=${1:?이름이 필요합니다 (예: myapp-fgs-location)}; limit=${2:-170}
  [ "$(a get-state 2>/dev/null)" = device ] || die "폰이 연결되어 있지 않습니다 ($ADB devices 확인)"
  [ "$(a shell dumpsys window | grep -o 'isKeyguardShowing=[a-z]*' | head -1)" = isKeyguardShowing=true ] \
    && die "폰이 잠겨 있습니다. 잠금을 풀고 다시 실행하세요"
  a shell pidof screenrecord >/dev/null 2>&1 && die "이미 녹화 중입니다 (stop 먼저)"
  a shell "[ -f $STATE ] || settings get global stay_on_while_plugged_in > $STATE"
  a shell svc power stayon usb
  a shell rm -f "/sdcard/$name.mp4"
  # 기기 안에서 백그라운드로 돌려 이 스크립트가 끝나도 녹화가 이어지게 한다
  a shell "nohup screenrecord --time-limit $limit /sdcard/$name.mp4 >/dev/null 2>&1 &"
  sleep 1
  a shell pidof screenrecord >/dev/null || die "screenrecord 가 시작되지 않았습니다"
  echo "녹화 중: /sdcard/$name.mp4 (최대 ${limit}초). 조작이 끝나면: $0 stop $name"
  ;;
stop)
  name=${1:?이름이 필요합니다}; out=${2:-$OUT}
  a shell pkill -INT screenrecord 2>/dev/null || true
  for _ in $(seq 20); do a shell pidof screenrecord >/dev/null 2>&1 || break; sleep 0.5; done
  sleep 1   # mp4 마무리(moov) 기록 대기 — 바로 가져오면 재생이 안 될 수 있다
  mkdir -p "$out"
  a pull "/sdcard/$name.mp4" "$(hostpath "$out/$name.mp4")" | tail -1
  a shell rm -f "/sdcard/$name.mp4"
  prev=$(a shell "cat $STATE 2>/dev/null" || true)
  a shell settings put global stay_on_while_plugged_in "${prev:-0}"
  a shell rm -f "$STATE"
  ls -la "$out/$name.mp4"
  ;;
frames)
  mp4=${1:?mp4 경로가 필요합니다}; times=${2:-1,4,7,10,15,20,25,30}
  [ -f "$mp4" ] || die "$mp4 가 없습니다"
  dir=$(cd "$(dirname "$mp4")" && pwd); base=$(basename "$mp4" .mp4)
  html="$dir/.frames-$base.html"; png="$dir/$base-frames.png"
  n=$(echo "$times" | tr ',' '\n' | wc -l)
  {
    echo '<!doctype html><body style="margin:0;background:#333;display:flex;gap:6px;padding:6px;color:#fff;font:14px sans-serif">'
    for t in ${times//,/ }; do
      echo "<div><video src=\"$base.mp4#t=$t\" width=\"170\" muted preload=\"auto\"></video><br>${t}s</div>"
    done
    echo '</body>'
  } > "$html"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --autoplay-policy=no-user-gesture-required --virtual-time-budget=8000 \
    --window-size=$((n * 176 + 12)),420 --screenshot="$(wslpath -w "$png")" \
    "file:///$(wslpath -w "$html" | tr '\\' '/')" 2>/dev/null
  rm -f "$html"
  echo "$png"
  ;;
*)
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
