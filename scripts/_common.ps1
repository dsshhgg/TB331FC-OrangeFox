# TB331FC HyperOS 一键辅助脚本
# 用法示例：
#   .\verify_files.ps1
#   .\flash_system.ps1 -Image "E:\rom\extracted\...\system_a_完全自包含.img" -Wipe
#   .\backup_partitions.ps1 -OutDir "E:\rom\backup"
#   .\check_after_flash.ps1

param()

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# 默认套件根：请按实际解压位置修改
$KitRoot = 'E:\rom\extracted\GSI_Kit'
$PlatformTools = Join-Path $KitRoot '06_工具\platform-tools'

function Find-Tool([string]$Name) {
    $local = Join-Path $PlatformTools $Name
    if (Test-Path $local) { return $local }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "找不到 $Name（请解压套件 06_工具/platform-tools 或加入 PATH）"
}

function Find-Image([string]$PreferName = 'system_a_完全自包含.img') {
    $candidates = @(
        (Join-Path $KitRoot "05_镜像\GSI\$PreferName"),
        "E:\rom\extracted\GSI_Kit\05_镜像\GSI\$PreferName"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return (Resolve-Path $c).Path }
    }
    # 全盘搜索 E:\rom
    $hit = Get-ChildItem -Path 'E:\rom' -Recurse -Filter $PreferName -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($hit) { return $hit.FullName }
    throw "找不到 $PreferName，请用 -Image 指定完整路径"
}

Write-Host "TB331FC 工具集已加载  KitRoot=$KitRoot" -ForegroundColor Cyan
