# 刷入 system_a_完全自包含.img（必须进 fastbootd）
# 用法：
#   .\flash_system.ps1
#   .\flash_system.ps1 -Image "D:\roms\system_a_完全自包含.img"
#   .\flash_system.ps1 -Wipe          # 从原厂首次刷入时清 userdata
#   .\flash_system.ps1 -SkipRebootFastboot  # 已在 fastbootd 时

param(
    [string]$Image,
    [switch]$Wipe,
    [switch]$SkipRebootFastboot
)
. "$PSScriptRoot\_common.ps1"

$fastboot = Find-Tool 'fastboot.exe'
if (-not $Image) { $Image = Find-Image 'system_a_完全自包含.img' }

Write-Host "=== TB331FC 刷系统镜像 ===" -ForegroundColor Cyan
Write-Host "fastboot : $fastboot"
Write-Host "镜像     : $Image"
$len = (Get-Item $Image).Length
Write-Host "大小     : $len 字节"
if ($len -ne 5794435072L) {
    Write-Host "警告: 大小不是 5,794,435,072，请确认镜像完整！" -ForegroundColor Yellow
}

$md5 = (Get-FileHash $Image -Algorithm MD5).Hash.ToLower()
Write-Host "MD5      : $md5"
if ($md5 -ne '0234dc1feceb9c4396e330fed1d34c9d') {
    Write-Host "警告: MD5 与作者发布值不一致，是否继续？(Y/N)" -ForegroundColor Yellow
    $c = Read-Host
    if ($c -notin 'Y','y') { exit 1 }
}

Write-Host "`n请确认设备已解锁 BL，并已连接 USB（fastboot devices 可见）" -ForegroundColor Yellow
& $fastboot devices
Read-Host "按 Enter 继续，Ctrl+C 取消"

if (-not $SkipRebootFastboot) {
    Write-Host "进入 fastbootd ..." -ForegroundColor Cyan
    & $fastboot reboot fastboot
    Start-Sleep -Seconds 8
    & $fastboot devices
}

if ($Wipe) {
    Write-Host "清 userdata（-w）..." -ForegroundColor Yellow
    & $fastboot -w
}

Write-Host "刷入 system（可能需要数分钟）..." -ForegroundColor Cyan
& $fastboot flash system $Image
if ($LASTEXITCODE -ne 0) {
    Write-Host "刷入失败，exit=$LASTEXITCODE" -ForegroundColor Red
    exit 1
}

Write-Host "重启 ..." -ForegroundColor Cyan
& $fastboot reboot
Write-Host "完成。请继续 KernelSU 步骤（修补 init_boot）。" -ForegroundColor Green
