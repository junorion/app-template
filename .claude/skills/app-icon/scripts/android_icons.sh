#!/usr/bin/env bash
# 안드로이드 네이티브 아이콘을 모두 만든다 (Flutter 앱, 또는 WebView 앱에서 적응형 아이콘을 따로 줄 때).
#
#   android_icons.sh <icon.html> <icon-foreground.html> <res 폴더> [바탕색=#FFFFFF] [상태바 이름=ic_stat_app]
#
# icon.html            512 전체 아이콘(바탕 포함) — Play 스토어 icon-512.png 도 여기서. 출력 폴더는 icon.html 옆
# icon-foreground.html 512 앞면만(바탕 투명), 그림을 0.8 배로 줄여 가운데(적응형 안전 영역 66%) 안에 둔다
# 바탕색               적응형 아이콘 바탕 = icon.html 의 바탕색과 같게
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
[ $# -ge 3 ] || { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
icon=$(realpath "$1"); fg=$(realpath "$2"); res=$(realpath -m "$3"); bg=${4:-#FFFFFF}; stat=${5:-ic_stat_app}
tmp=$(mktemp -d)
bash "$here/render_icon.sh" "$icon" "$(dirname "$icon")"
mkdir -p "$tmp/fg" && bash "$here/render_icon.sh" "$fg" "$tmp/fg"
python3 "$here/android_icons.py" "$(dirname "$icon")/icon-512.png" "$tmp/fg/icon-512.png" "$res" "$bg" "$stat"
rm -rf "$tmp"
