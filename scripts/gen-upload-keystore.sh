#!/bin/bash
# 업로드 키스토어 생성 헬퍼 — Play Store 릴리즈 서명용.
#
# 배경(docs/deploy-readiness.md): 이 앱은 Play App Signing 활성(시나리오 A).
# 원본 업로드 키스토어가 집 노트북 등에 있으면 그걸 쓰고, 없으면 이 스크립트로
# 새 업로드 키를 만들어 Play Console "업로드 키 재설정 요청"에 인증서(.pem)를 제출한다.
#
# ⚠️ 생성된 .jks / .pem / 비밀번호는 레포에 커밋 금지(.gitignore로 차단됨).
#    안전한 곳(비밀번호 관리자)에 보관. 분실 시 재설정 절차 반복 필요.
#
# 사용법:
#   ./scripts/gen-upload-keystore.sh [출력경로] [alias]
#   예) ./scripts/gen-upload-keystore.sh upload-keystore.jks upload
set -euo pipefail

OUT="${1:-upload-keystore.jks}"
ALIAS="${2:-upload}"

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool 없음 — JDK 설치 필요(예: temurin 17)." >&2
  exit 1
fi

if [ -e "$OUT" ]; then
  echo "이미 존재: $OUT (덮어쓰지 않음). 다른 경로를 지정하세요." >&2
  exit 1
fi

echo "== 업로드 키스토어 생성 =="
echo "출력: $OUT / alias: $ALIAS"
echo "(비밀번호 2회, 이름/조직 등 입력 프롬프트가 뜹니다)"
keytool -genkeypair -v \
  -keystore "$OUT" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias "$ALIAS"

echo
echo "== 재설정 요청용 인증서(.pem) 추출 =="
PEM="${OUT%.jks}_certificate.pem"
keytool -export -rfc -keystore "$OUT" -alias "$ALIAS" -file "$PEM"
echo "→ $PEM  (Play Console '업로드 키 재설정 요청'에 이 파일 제출)"

echo
echo "== 이 업로드 키의 지문(SHA-1) — 로컬/CI 디버깅 등록용 =="
keytool -list -v -keystore "$OUT" -alias "$ALIAS" | grep -E 'SHA1|SHA-1' || true

cat <<EOF

== 다음 단계 ==
1) $PEM 를 Play Console → 앱 서명 → "업로드 키 재설정 요청"에 제출(구글 승인 대기).
2) GitHub Secrets 등록(release-aab.yml):
   ANDROID_KEYSTORE_BASE64   = $(echo "base64 -w0 $OUT")   # macOS: base64 -i $OUT
   ANDROID_KEYSTORE_PASSWORD = (storePassword)
   ANDROID_KEY_ALIAS         = $ALIAS
   ANDROID_KEY_PASSWORD      = (keyPassword)
3) ⚠️ 콘솔(Firebase/카카오/네이버)에 등록할 릴리즈 SHA-1/키해시는 이 업로드 키가 아니라
   Play Console에 표시된 '앱 서명 키'의 지문을 쓸 것. (docs/deploy-readiness.md §1-2)
EOF
