# scripts/capture/setup_windows.ps1
# 누룽지도 마케팅 캡처 — Windows 준비물 일괄 설치/점검.
#
# 사용법 (PowerShell):
#   powershell -ExecutionPolicy Bypass -File scripts\capture\setup_windows.ps1
#
# 설치 후에는 PATH 갱신을 위해 **새 창**을 열어야 한다.
# 실제 캡처는 bash 스크립트라 Git Bash 에서 실행한다:
#   scripts/capture/local_capture.sh

$ErrorActionPreference = 'Continue'

function Head($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Yellow }
function Ok($t)   { Write-Host "  [OK]   $t" -ForegroundColor Green }
function Miss($t) { Write-Host "  [필요] $t" -ForegroundColor Red }
function Has($c)  { return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

Head "0. winget 확인"
if (-not (Has 'winget')) {
  Miss "winget 이 없습니다. Microsoft Store 에서 '앱 설치 관리자(App Installer)' 를 설치한 뒤 다시 실행하세요."
  exit 1
}
Ok "winget"

# ── adb (Android Platform Tools) ─────────────────────────────
Head "1. adb (Android Platform Tools)"
if (Has 'adb') {
  Ok ("adb — " + ((adb --version | Select-Object -First 1)))
} else {
  Write-Host "  설치 중…"
  winget install --id Google.PlatformTools -e --accept-source-agreements --accept-package-agreements
  # Android Studio 를 이미 쓰는 경우 SDK 경로도 PATH 후보로 알려준다
  $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools'
  if (Test-Path (Join-Path $sdk 'adb.exe')) {
    Write-Host "  (참고) Android Studio SDK 에도 adb 가 있습니다: $sdk" -ForegroundColor DarkGray
  }
}

# ── ImageMagick ──────────────────────────────────────────────
Head "2. ImageMagick"
if (Has 'magick') {
  Ok ("magick — " + ((magick --version | Select-Object -First 1)))
} else {
  Write-Host "  설치 중…"
  winget install --id ImageMagick.ImageMagick -e --accept-source-agreements --accept-package-agreements
}

# ── ffmpeg ───────────────────────────────────────────────────
Head "3. ffmpeg"
if (Has 'ffmpeg') {
  Ok ("ffmpeg — " + ((ffmpeg -version | Select-Object -First 1)))
} else {
  Write-Host "  설치 중…"
  winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
}

# ── Flutter (프로젝트는 Dart >= 3.10.4 필요) ─────────────────
Head "4. Flutter / Dart 버전"
if (-not (Has 'flutter')) {
  Miss "flutter 가 없습니다. https://docs.flutter.dev/get-started/install/windows 참고"
} else {
  $v = (flutter --version | Out-String)
  if ($v -match 'Dart (\d+)\.(\d+)\.(\d+)') {
    $maj=[int]$Matches[1]; $min=[int]$Matches[2]; $pat=[int]$Matches[3]
    $need = ($maj -lt 3) -or ($maj -eq 3 -and $min -lt 10) -or ($maj -eq 3 -and $min -eq 10 -and $pat -lt 4)
    if ($need) {
      Miss "Dart $maj.$min.$pat — 이 프로젝트는 3.10.4 이상이 필요합니다. 업그레이드합니다…"
      flutter upgrade
    } else {
      Ok "Dart $maj.$min.$pat (요구: 3.10.4+)"
    }
  } else {
    Write-Host "  Dart 버전을 읽지 못했습니다. 수동 확인: flutter --version" -ForegroundColor DarkYellow
  }
}

# ── Git Bash ─────────────────────────────────────────────────
Head "5. Git Bash (캡처 스크립트 실행용)"
$bash = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($bash) { Ok "Git Bash — $bash" }
else {
  Miss "Git Bash 가 없습니다. 설치합니다…"
  winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
}

Write-Host ""
Write-Host "────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host " 설치 완료. 다음 순서로 진행하세요." -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host @"
 1) 이 창을 닫고 **새 PowerShell 창**을 엽니다 (PATH 갱신).
    확인:  adb --version ;  magick --version ;  flutter --version

 2) 폰을 USB 로 연결합니다.
    설정 > 휴대전화 정보 > 빌드번호 7번 탭  ->  개발자 옵션 > USB 디버깅 켜기
    폰에 뜨는 'USB 디버깅을 허용하시겠습니까?' -> 허용
    확인:  adb devices     (device 라고 나와야 함)

 3) 프로젝트 폴더에서 우클릭 > 'Git Bash Here' 후:
      git pull
      scripts/capture/local_capture.sh
"@
