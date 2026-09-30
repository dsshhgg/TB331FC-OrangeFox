# 从设备备份关键分区（动手前必做）
# 用法: .\backup_partitions.ps1 -OutDir "E:\rom\backup"
param(
    [string]$OutDir = 'E:\rom\backup'
)
. "$PSScriptRoot\_common.ps1"

$adb = Find-Tool 'adb.exe'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "检查 adb 设备 ..." -ForegroundColor Cyan
& $adb devices
Write-Host "请确认设备已开 USB 调试且已授权" -ForegroundColor Yellow

$parts = @(
    @{ Part = 'init_boot_a';   Out = 'init_boot_a.img' },
    @{ Part = 'boot_a';        Out = 'boot_a.img' },
    @{ Part = 'vendor_boot_a'; Out = 'vendor_boot_a.img' },
    @{ Part = 'vbmeta_a';      Out = 'vbmeta_a.img' }
)

foreach ($p in $parts) {
    $dest = Join-Path $OutDir $p.Out
    Write-Host "备份 $($p.Part) -> $dest" -ForegroundColor Cyan
    & $adb shell "dd if=/dev/block/by-name/$($p.Part) of=/data/local/tmp/$($p.Out)"
    & $adb pull "/data/local/tmp/$($p.Out)" $dest
    & $adb shell "rm -f /data/local/tmp/$($p.Out)"
}

# system_a / dm-2 整块（约 5.4GB，改 /product 前必做）
Write-Host "`n是否备份 system_a (dm-2, ~5.4GB)？需要设备剩余空间充足 [Y/N]" -ForegroundColor Yellow
$c = Read-Host
if ($c -in 'Y','y') {
    $dest = Join-Path $OutDir 'system_a_backup.img'
    Write-Host "dd dm-2（bs=4096，勿用 count 截断）..." -ForegroundColor Cyan
    & $adb shell "dd if=/dev/block/dm-2 of=/data/local/tmp/system_a_backup.img bs=4096"
    & $adb shell "md5sum /data/local/tmp/system_a_backup.img"
    & $adb pull /data/local/tmp/system_a_backup.img $dest
    & $adb shell "rm -f /data/local/tmp/system_a_backup.img"
    $len = (Get-Item $dest).Length
    Write-Host "本地大小: $len（期望 5794435072）" -ForegroundColor Cyan
}

Write-Host "备份完成 -> $OutDir" -ForegroundColor Green
