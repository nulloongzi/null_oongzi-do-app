param(
  [Parameter(Mandatory=$true)][string]$TextFile,
  [Parameter(Mandatory=$true)][string]$OutWav
)
# tts_sapi.ps1 - edge-tts 를 못 쓸 때의 오프라인 폴백.
# 한국어 Windows 에 기본 탑재된 SAPI 음성으로 한 줄을 읽어 WAV 로 저장한다.
# 한글은 인자로 넘기면 콘솔 코드페이지 때문에 깨지므로 UTF-8 파일로 받는다.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech

$text = [System.IO.File]::ReadAllText($TextFile, [System.Text.Encoding]::UTF8)
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

$ko = $null
foreach ($v in $synth.GetInstalledVoices()) {
  if ($v.Enabled -and $v.VoiceInfo.Culture.Name -eq "ko-KR") { $ko = $v.VoiceInfo.Name; break }
}
if ($ko) { $synth.SelectVoice($ko) }
else { Write-Error "ko-KR 음성이 설치돼 있지 않습니다 (설정 > 시간 및 언어 > 음성)"; exit 1 }

$synth.Rate = 1          # -10..10, 0 이 기본. 릴스는 살짝 빠르게.
$synth.SetOutputToWaveFile($OutWav)
$synth.Speak($text)
$synth.SetOutputToNull()
$synth.Dispose()
