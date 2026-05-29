<#
PowerShell script: collect_logs.ps1
Usage: .\collect_logs.ps1 -DeviceId RFCX71RKANX -OutDir C:\temp\span_logs

What it does:
- Runs `flutter logs` (10s) and saves to flutter_logs.txt
- Runs `adb logcat` for a specified duration and saves to logcat_full.txt
- Dumps meminfo and device list
- Optionally runs `flutter run --profile` instructions are printed
- Archives results to ZIP
#>

param(
    [string]$DeviceId = '',
    [string]$OutDir = "./span_logs",
    [int]$LogcatSeconds = 60
)

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Error "adb not found in PATH. Install Android Platform Tools and retry."
    exit 1
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter not found in PATH. Install Flutter SDK and retry."
    exit 1
}

# normalize outdir
$OutDir = Resolve-Path -Path $OutDir | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
if (-not $OutDir) { New-Item -ItemType Directory -Path ./span_logs | Out-Null; $OutDir = (Resolve-Path ./span_logs).Path }

Write-Host "Collecting logs to: $OutDir"

# 1) flutter logs (run for a short window)
$flutterLog = Join-Path $OutDir flutter_logs.txt
Write-Host "Starting flutter logs (10s) -> $flutterLog"
Start-Process -NoNewWindow -FilePath flutter -ArgumentList "logs" -RedirectStandardOutput $flutterLog -WindowStyle Hidden
Start-Sleep -Seconds 10
# attempt to stop flutter logs by killing the process (best-effort)
Get-Process -Name flutter -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null; Start-Sleep -Milliseconds 500; $_.Kill() }

# 2) adb logcat
$logcatFile = Join-Path $OutDir logcat_full.txt
Write-Host "Starting adb logcat for $LogcatSeconds seconds -> $logcatFile"
if ($DeviceId -ne '') { $adbArgs = "-s $DeviceId logcat -v threadtime" } else { $adbArgs = "logcat -v threadtime" }
Start-Process -NoNewWindow -FilePath adb -ArgumentList $adbArgs -RedirectStandardOutput $logcatFile -WindowStyle Hidden
Start-Sleep -Seconds $LogcatSeconds
Get-Process -Name adb -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null; Start-Sleep -Milliseconds 500; $_.Kill() }

# 3) meminfo
$memInfo = Join-Path $OutDir meminfo.txt
Write-Host "Dumping meminfo -> $memInfo"
if ($DeviceId -ne '') { adb -s $DeviceId shell dumpsys meminfo > $memInfo } else { adb shell dumpsys meminfo > $memInfo }

# 4) device list and package info
$devList = Join-Path $OutDir devices.txt
adb devices -l > $devList

# 5) optional: get top CPU snapshot (1s sample via top)
$topFile = Join-Path $OutDir top.txt
if ($DeviceId -ne '') { adb -s $DeviceId shell top -n 1 -b > $topFile } else { adb shell top -n 1 -b > $topFile }

# 6) zip results
$zipFile = Join-Path $OutDir span_logs_$(Get-Date -Format "yyyyMMdd_HHmmss").zip
Write-Host "Creating ZIP -> $zipFile"
Compress-Archive -Path (Join-Path $OutDir "*") -DestinationPath $zipFile -Force

Write-Host "Done. ZIP: $zipFile"
Write-Host "If you need profile traces: run 'flutter run --profile -d <device-id>' and collect CPU profile via DevTools as described in docs/TRACING_AND_PROFILE.md"
