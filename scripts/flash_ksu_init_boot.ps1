# 刷 KernelSU 修补后的 init_boot
# 用法: .\flash_ksu_init_boot.ps1 -Image "C:\path\kernelsu_patched_init_boot.img"
param(
    [Parameter(Mandatory = $true)][string]$Image
)
. "$PSScriptRoot\_common.ps1"
$fastboot = Find-Tool 'fastboot.exe'

if (-not (Test-Path $Image)) { throw "镜像不存在: $Image" }
Write-Host "刷入 init_boot: $Image ($((Get-Item $Image).Length) B)" -ForegroundColor Cyan
& $fastboot devices
& $fastboot flash init_boot $Image
if ($LASTEXITCODE -ne 0) { exit 1 }
& $fastboot reboot
Write-Host "完成。请安装 KSU 模块 tb331fc_drop_xiaomi_account.zip。" -ForegroundColor Green
