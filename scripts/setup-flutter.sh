#!/bin/bash
# Flutter SDK 수동 설치 스크립트 (온디맨드).
#
# 목적(방법론 docs/testing-methodology.md "메타 지렛대"): 실행 환경에 Flutter SDK 가
# 없어 에이전트/개발자가 로컬에서 `flutter analyze && flutter test` 를 초 단위로
# self-verify 하지 못하는 문제를 해소한다. 이 스크립트를 한 번 실행하면 이후
# `flutter analyze` / `flutter test` 를 로컬에서 바로 돌릴 수 있다.
#
# 이 스크립트는 "직접 실행할 때만" 동작한다(SessionStart 자동 훅 아님).
# 자동 실행 훅으로 승격하려면 저장소 소유자가 명시적으로 .claude/settings.json 에
# 등록해야 한다.
#
# 사용:  bash scripts/setup-flutter.sh   →   안내대로 PATH 추가 후 flutter pub get
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-${HOME}/flutter}"
FLUTTER_BIN="${FLUTTER_DIR}/bin"

if [ ! -x "${FLUTTER_BIN}/flutter" ]; then
  echo "[setup-flutter] Flutter stable clone → ${FLUTTER_DIR}"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
else
  echo "[setup-flutter] 기존 Flutter 재사용: ${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_BIN}:${PATH}"

# Claude Code on the web 세션에서 직접 실행됐다면 이번 세션 PATH 를 유지한다.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"${FLUTTER_BIN}:\$PATH\"" >> "${CLAUDE_ENV_FILE}"
fi

flutter --version
flutter pub get

cat <<EOF

[setup-flutter] 완료.
  현재 셸에 PATH 추가:  export PATH="${FLUTTER_BIN}:\$PATH"
  이제 사용 가능:        flutter analyze --no-fatal-infos   /   flutter test
EOF
