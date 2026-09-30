# 刷机后一键体检
. "$PSScriptRoot\_common.ps1"
$adb = Find-Tool 'adb.exe'

Write-Host "=== TB331FC 刷后体检 ===" -ForegroundColor Cyan
& $adb devices

function Show([string]$Title, [string]$ShellCmd) {
    Write-Host "`n--- $Title ---" -ForegroundColor Yellow
    & $adb shell $ShellCmd
}

Show 'SELinux' 'getenforce'
Show 'bootfix 服务' 'getprop init.svc.tb331fc_boot'
Show 'bootfix 日志尾部' 'tail -30 /data/local/tmp/_boot_fix.log'
Show 'KernelSU / su' 'which su; id'
Show '相机 (Aperture)' "dumpsys package org.lineageos.aperture | grep codePath"
Show '小米互传 (应含 PRIVILEGED)' "dumpsys package com.miui.mishare.connectivity | grep -E 'codePath|privateFlags'"
Show '手写笔' 'cat /proc/support_pen; dmesg | grep -i "Pen state" | tail -5'
Show 'device_features 挂载（通信共享）' 'grep device_features /proc/mounts'
Show '小米账号数量' "dumpsys account | grep -c 'type=com\\.xiaomi'"
Show '应用层 avc 抽样' "dmesg | grep 'avc:' | grep denied | grep -v 'su:s0' | grep -v 'ksu:s0' | tail -20"

Write-Host "`n体检结束。应用层 avc 应接近 0；device_features 若装了模块应有 bind 挂载。" -ForegroundColor Cyan
