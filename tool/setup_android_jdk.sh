#!/usr/bin/env bash
# Android/Gradle는 Java 26(class file 70)을 아직 지원하지 않습니다.
# 이 스크립트는 OpenJDK 17을 설치하고 Gradle이 사용할 JAVA_HOME을 고정합니다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JDK_LOCAL="$ROOT/android/jdk.local.properties"

install_jdk17() {
  if command -v brew >/dev/null 2>&1; then
    if ! brew list openjdk@17 >/dev/null 2>&1; then
      echo "OpenJDK 17 설치 중..."
      brew install openjdk@17
    fi
    echo "$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
    return
  fi
  if /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
    /usr/libexec/java_home -v 17
    return
  fi
  echo "OpenJDK 17을 찾을 수 없습니다. brew install openjdk@17 후 다시 실행하세요." >&2
  exit 1
}

JAVA17_HOME="$(install_jdk17)"
cat > "$JDK_LOCAL" <<EOF
# tool/setup_android_jdk.sh 가 생성 (git 제외). Gradle 전용 JDK 17.
org.gradle.java.home=$JAVA17_HOME
EOF

echo "Wrote $JDK_LOCAL"
echo "JAVA_HOME=$JAVA17_HOME"
"$JAVA17_HOME/bin/java" -version

echo ""
echo "다음 중 하나로 빌드하세요:"
echo "  source tool/android_build_env.sh && flutter build apk --release"
echo "  또는 터미널에: export JAVA_HOME=\"$JAVA17_HOME\""
