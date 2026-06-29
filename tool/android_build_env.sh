#!/usr/bin/env bash
# Android Gradle 빌드 전 source 하세요: source tool/android_build_env.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JDK_LOCAL="$ROOT/android/jdk.local.properties"

if [[ ! -f "$JDK_LOCAL" ]]; then
  echo "jdk.local.properties 없음 — tool/setup_android_jdk.sh 실행 중..." >&2
  bash "$ROOT/tool/setup_android_jdk.sh"
fi

JAVA_HOME="$(grep -E '^org\.gradle\.java\.home=' "$JDK_LOCAL" | cut -d= -f2-)"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
