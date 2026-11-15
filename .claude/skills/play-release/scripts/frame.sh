#!/usr/bin/env bash
# 원본 스크린샷에 제목·부제를 얹어 Play 스토어 스크린샷(1080×1920, 9:16)을 만든다.
#
#   frame.sh <문구 파일> [원본 폴더=문구 파일 옆 raw/] [출력 폴더=문구 파일 옆]
#
# 문구 파일 한 줄 = "원본 이름|제목|부제" (# 은 주석). 원본은 <원본 폴더>/<이름>.png 또는 .jpg.
# 출력 이름은 문구 파일 이름을 따른다: captions.txt → screenshot-1.png …,
# captions-en.txt → screenshot-en-1.png … (줄 순서 = 스토어에 보이는 순서, 첫 두 장이 검색 결과에 뜬다)
#
# 환경 변수
#   TOP / BOTTOM   원본에서 잘라 낼 상태바·내비게이션 바 높이(px). 기본 80 / 126 (갤럭시 A32 1080×2400)
#                  웹 화면(web-verify shot.sh)처럼 바가 없는 원본은 TOP=0 BOTTOM=0
#   ACCENT BG INK  부제 색, 바탕색, 제목 색 (앱 색에 맞춘다)
#
# 원본 찍기: device 스킬 `phone.sh shot store/raw/1-ready.png` (store/raw/ 는 gitignore 해 둔다 —
# 지도·개인 기록이 찍힐 수 있다)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
shot="$here/../../web-verify/scripts/shot.sh"
cap=$(realpath "${1:?문구 파일이 필요합니다}")
raw=$(realpath "${2:-$(dirname "$cap")/raw}"); out=$(realpath -m "${3:-$(dirname "$cap")}")
suffix=$(basename "$cap" .txt | sed -n 's/^captions-\(.*\)$/\1-/p')
mkdir -p "$out"; n=0
while IFS='|' read -r f t s; do
  case "$f" in ''|\#*) continue ;; esac
  n=$((n + 1))
  img=""; for e in png jpg jpeg; do [ -f "$raw/$f.$e" ] && img="$raw/$f.$e" && break; done
  [ -n "$img" ] || { echo "건너뜀: $raw/$f.png 없음"; continue; }
  page="$raw/.frame-$n.html"   # 원본 옆에 두어 상대 경로로 읽는다
  python3 - "$here/frame.html" "$page" "$(basename "$img")" "$t" "$s" <<PY
import sys, json
src, dst, img, t, s = sys.argv[1:]
vals = {'img': img, 't': t, 's': s, 'top': '${TOP:-80}', 'bottom': '${BOTTOM:-126}',
        'accent': '${ACCENT:-#2E9E5B}', 'bg': '${BG:-#F2F2F7}', 'ink': '${INK:-#1C1C1E}'}
h = open(src, encoding='utf-8').read()
h = h.replace("const q=new URLSearchParams(location.search);",
              "const q=new Map(Object.entries(" + json.dumps(vals, ensure_ascii=False) + "));")
open(dst, 'w', encoding='utf-8').write(h)
PY
  dst="$out/screenshot-$suffix$n.png"
  SHOT_WAIT_MS=3000 bash "$shot" "$page" "$dst" 1080 1920 >/dev/null </dev/null   # chrome.exe 가 stdin(문구 파일)을 먹지 않게
  rm -f "$page"
  echo "$dst  ← $(basename "$img")"
done < "$cap"
