# TB331FC - OrangeFox post-flash verification checklist (runs when device is IN recovery).
# Read-only on the device: only queries state, writes a local report.
# NOTE: device-side commands deliberately avoid | > && quotes, because Windows argument
#       mangling would break them; all filtering happens here in PowerShell.
# Usage: powershell -ExecutionPolicy Bypass -File verify_in_recovery.ps1 [-AdbPath <path>] [-FastbootPath <path>] [-NoFastbootD]
param(
    [string]$AdbPath = 'E:\rom\tools\platform-tools\adb.exe',
    [string]$FastbootPath = 'E:\rom\tools\platform-tools\fastboot.exe',
    [switch]$NoFastbootD
)
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$report = Join-Path $logDir ('verify_recovery_' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')

$results = New-Object System.Collections.ArrayList
function Add-Result($name, $state, $evidence) {
    $ev = ($evidence | Out-String).Trim()
    if ($ev.Length -gt 300) { $ev = $ev.Substring(0, 300) + ' ...' }
    [void]$results.Add([pscustomobject]@{ Check = $name; Result = $state; Evidence = $ev })
    $color = switch ($state) { 'PASS' { 'Green' } 'FAIL' { 'Red' } 'WARN' { 'Yellow' } default { 'Gray' } }
    Write-Host ("[{0,-4}] {1,-26} {2}" -f $state, $name, $ev) -ForegroundColor $color
}
$adb = $AdbPath
$fb  = $FastbootPath

# one simple command per call -> no shell metacharacters, no mangling
function Sh([string]$cmd) {
    $out = (& $adb shell $cmd) 2>$null
    $txt = ($out | Out-String)
    return $txt.Trim()
}

Write-Host "===== TB331FC OrangeFox verification checklist =====" -ForegroundColor Cyan
Write-Host ("adb     : " + $adb)
Write-Host ("report  : " + $report)
Write-Host ""

# --- 0. recovery online? ---
$devLines = @((& $adb devices) 2>$null | Where-Object { $_ -match '\t(device|recovery|sideload)\b' })
if ($devLines.Count -eq 0) {
    Add-Result 'device online (adb)' 'FAIL' 'no adb device; boot OrangeFox first'
    Write-Host ""
    Write-Host "No device in adb. If the tablet is in fastboot, flash OrangeFox first:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\flash_of_and_test.ps1" -ForegroundColor Yellow
    $results | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath $report -Encoding UTF8
    exit 1
}
Add-Result 'device online (adb)' 'PASS' ($devLines -join ' | ')

# --- 1. OrangeFox markers ---
$twrp = Sh 'getprop ro.twrp.version'
$fox  = Sh 'getprop ro.orangefox.version'
$foxcfg = Sh 'cat /etc/fox.cfg'
$ffiles = Sh 'ls /FFiles'
if ($twrp -or $fox -or $foxcfg -or $ffiles) {
    Add-Result 'OrangeFox markers' 'PASS' ("twrp=" + $twrp + " fox=" + $fox + " cfg=" + ($foxcfg -split "`n")[0] + " /FFiles=" + (($ffiles -split "`n") -join ','))
} else {
    Add-Result 'OrangeFox markers' 'WARN' 'no twrp/orangefox props, no /FFiles -> looks like stock recovery'
}

# --- 2. kernel / cmdline ---
$kern = Sh 'cat /proc/version'
Add-Result 'kernel up' $(if ($kern -match 'Linux version') { 'PASS' } else { 'FAIL' }) $kern
$cmdline = Sh 'cat /proc/cmdline'
Add-Result 'cmdline clean' $(if ($cmdline -notmatch 'buildvariant=eng') { 'PASS' } else { 'WARN' }) $cmdline

# --- 3. touch ---
$inputDevs  = Sh 'cat /proc/bus/input/devices'
$inputLines = @(($inputDevs -split "`n") | Where-Object { $_ -match '(?i)Name=|Handlers=|nvt|touch' })
$nvtList    = Sh 'ls /vendor/lib/modules'
$nvtKo      = @(($nvtList -split "`n") | Where-Object { $_ -match '(?i)nvt|touch' })
$dmesg      = Sh 'dmesg'
$dmesgTouch = @(($dmesg -split "`n") | Where-Object { $_ -match '(?i)nvt|novatek|touchscreen' } | Select-Object -Last 5)
$touchOk = ($inputLines.Count -gt 0) -or ($nvtKo.Count -gt 0)
Add-Result 'touch driver/module' $(if ($touchOk) { 'PASS' } else { 'WARN' }) (($inputLines -join ' | ') + ' | modules: ' + ($nvtKo -join ','))
Add-Result 'touch dmesg' $(if ($dmesgTouch.Count -gt 0) { 'PASS' } else { 'WARN' }) ($dmesgTouch -join ' | ')
Write-Host "     manual: swipe the menu and confirm the screen responds" -ForegroundColor DarkGray

# --- 4. dynamic partitions ---
$mapper = Sh 'ls /dev/block/mapper'
$dmList = Sh 'ls /dev/block'
$dm     = @(($dmList -split "`n") | Where-Object { $_ -match '^dm-' })
$mounts = Sh 'cat /proc/mounts'
$mountHit = @(($mounts -split "`n") | Where-Object { $_ -match '/dev/block/(mapper|dm-)' })
$superPart = Sh 'ls -l /dev/block/by-name/super'
Add-Result 'dynamic partitions' $(if (($mapper -or $dm.Count -gt 0 -or $mountHit.Count -gt 0)) { 'PASS' } else { 'WARN' }) (($mapper -split "`n" -join ',') + ' | dm: ' + ($dm -join ',') + ' | super: ' + $superPart)
$sysMount = @(($mounts -split "`n") | Where-Object { $_ -match ' /(system|vendor|product) ' })
Add-Result 'system/vendor mounted' $(if ($sysMount.Count -gt 0) { 'PASS' } else { 'WARN' }) ($sysMount -join ' | ')

# --- 5. FBE / data ---
$dataMount = @(($mounts -split "`n") | Where-Object { $_ -match ' /data ' })
$crypto = Sh 'getprop ro.crypto.state'
$dataList = Sh 'ls /data'
$dataLines = @(($dataList -split "`n") | Where-Object { $_.Trim() -ne '' })
$fbLog = @(($dmesg -split "`n") | Where-Object { $_ -match '(?i)fbe|fscrypt|keymaster|decrypt|ice ' } | Select-Object -Last 5)
Add-Result 'data mount' $(if ($dataMount.Count -gt 0) { 'PASS' } else { 'WARN' }) (($dataMount -join ' | ') + ' | crypto=' + $crypto)
Add-Result 'data readable' $(if ($dataLines.Count -gt 0 -and $dataList -notmatch '(?i)permission denied|encrypted') { 'PASS' } else { 'WARN' }) (($dataLines | Select-Object -First 5) -join ',')
Add-Result 'FBE logs' $(if ($fbLog.Count -gt 0) { 'PASS' } else { 'WARN' }) ($fbLog -join ' | ')

# --- 6. MTP / USB ---
$usbState = (Sh 'cat /sys/class/android_usb/android0/state') + ' / ' + (Sh 'getprop sys.usb.config') + ' / ' + (Sh 'getprop sys.usb.state')
Add-Result 'MTP/USB config' $(if ($usbState.Trim(' /') -ne '') { 'PASS' } else { 'WARN' }) $usbState
Write-Host "     manual: connect USB and confirm the PC shows the tablet storage" -ForegroundColor DarkGray

# --- 7. mount table / space ---
$df = Sh 'df -h'
Add-Result 'mount table' $(if ($mounts) { 'PASS' } else { 'WARN' }) (($mounts -split "`n").Count.ToString() + ' mount entries')
Write-Host ""
Write-Host "--- df -h ---" -ForegroundColor DarkGray
($df -split "`n") | Select-Object -First 12 | ForEach-Object { Write-Host ("     " + $_) -ForegroundColor DarkGray }

# --- 8. partition map ---
$byName = Sh 'ls /dev/block/by-name'
$superLink = Sh 'ls /dev/block/by-name/super'
$byNameOk = ($byName -match 'recovery') -or ($superLink -match 'super')
Add-Result 'by-name partitions' $(if ($byNameOk) { 'PASS' } else { 'WARN' }) ('super=' + $superLink + ' | entries=' + (($byName -split "`n") -join ' '))

# --- 9. fastbootd (optional, leaves recovery) ---
if ($NoFastbootD) {
    Add-Result 'fastbootd is-userspace' 'SKIP' '-NoFastbootD'
} else {
    $ans = 'n'
    if ($env:TB331FC_AUTO_FASTBOOTD -eq '1') { $ans = 'y' }
    else { $ans = Read-Host "test fastbootd now? this reboots out of recovery (y/N)" }
    if ($ans -eq 'y') {
        & $adb reboot fastboot | Out-Null
        Start-Sleep -Seconds 15
        $isUserspace = ((& $fb getvar is-userspace) 2>&1 | Out-String)
        Add-Result 'fastbootd is-userspace' $(if ($isUserspace -match 'yes') { 'PASS' } else { 'WARN' }) $isUserspace
    } else {
        Add-Result 'fastbootd is-userspace' 'SKIP' 'not tested (optional)'
    }
}

# --- summary + report ---
$all = @($results)
$pass = @($all | Where-Object { $_.Result -eq 'PASS' }).Count
$fail = @($all | Where-Object { $_.Result -eq 'FAIL' }).Count
$warn = @($all | Where-Object { $_.Result -eq 'WARN' }).Count
$skip = @($all | Where-Object { $_.Result -eq 'SKIP' }).Count
Write-Host ""
Write-Host ("===== summary: PASS " + $pass + " / FAIL " + $fail + " / WARN " + $warn + " / SKIP " + $skip + " =====") -ForegroundColor Cyan
$hdr = @("# TB331FC OrangeFox verification report", ("# time: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
         ("# adb : " + $adb), ("# summary: PASS " + $pass + " FAIL " + $fail + " WARN " + $warn + " SKIP " + $skip), "")
$hdr | Set-Content -LiteralPath $report -Encoding UTF8
$results | Format-Table -AutoSize | Out-String -Width 200 | Add-Content -LiteralPath $report -Encoding UTF8
Write-Host ("report written: " + $report)
if ($fail -eq 0) { exit 0 } else { exit 2 }
