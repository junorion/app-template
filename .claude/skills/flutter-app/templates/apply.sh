#!/usr/bin/env bash
# flutter create 로 막 만든 app/ 에 공통 설정을 입힌다. 한 번만 실행한다.
#
#   apply.sh <app 폴더> <앱-id> "<한국어 이름>" "<영어 이름>"
#
# - android/app/build.gradle.kts: prod/dev flavor, 업로드 키(key.properties), 시험폰용 -PdebugSign, R8 규칙 자리
# - flavor 별 앱 이름(values=영어, values-ko=한국어, dev 는 " Dev" 붙임), 매니페스트 label
# - analysis_options 에서 android/ios/build 제외, .gitignore 에 key/secrets/goldens
# - test/screenshot_test.dart (골든 스크린샷 견본)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
[ $# -eq 4 ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
app=$(realpath "$1"); id=$2; ko=$3; en=$4
cd "$app"
[ -f pubspec.yaml ] && [ -d android/app ] || { echo "$app 은 flutter create 로 만든 폴더가 아닙니다"; exit 1; }
[ -f android/app/build.gradle.kts ] || { echo "build.gradle.kts 가 없습니다(옛 Groovy 템플릿?)"; exit 1; }

sed "s/myapp/$id/g" "$here/build.gradle.kts" > android/app/build.gradle.kts
[ -f android/app/proguard-rules.pro ] || printf '# 출시 빌드 코드 축소(R8)용 규칙. release APK 가 켜자마자 죽으면 logcat 의 ClassNotFound 를 보고 keep 을 더한다.\n' > android/app/proguard-rules.pro

xml() { mkdir -p "$(dirname "$1")"; printf '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">%s</string>\n</resources>\n' "$2" > "$1"; }
xml android/app/src/prod/res/values/strings.xml "$en"
xml android/app/src/prod/res/values-ko/strings.xml "$ko"
xml android/app/src/dev/res/values/strings.xml "$en Dev"
xml android/app/src/dev/res/values-ko/strings.xml "$ko Dev"
sed -i 's/android:label="[^"]*"/android:label="@string\/app_name"/' android/app/src/main/AndroidManifest.xml

grep -q 'exclude:' analysis_options.yaml || cat >> analysis_options.yaml <<'YAML'

analyzer:
  exclude:
    - build/**
    - android/**
    - ios/**
YAML
for p in key.properties secrets.properties /test/goldens/; do grep -qxF "$p" .gitignore || echo "$p" >> .gitignore; done
mkdir -p test && cp "$here/screenshot_test.dart" test/screenshot_test.dart
echo "적용함: $app ($id, $ko / $en)"
echo "시험폰 APK: flutter build apk --release --flavor prod --android-project-arg=debugSign=true"
