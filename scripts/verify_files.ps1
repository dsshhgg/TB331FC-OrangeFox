# 校验 TB331FC 套件文件完整性
. "$PSScriptRoot\_common.ps1"

$md5file = Join-Path $KitRoot 'MD5SUMS.txt'
if (-not (Test-Path $md5file)) {
    # 也可能在解压根
    $alt = 'E:\rom\extracted\GSI_Kit\MD5SUMS.txt'
    if (Test-Path $alt) { $md5file = $alt }
    else { throw "找不到 MD5SUMS.txt" }
}

Write-Host "校验清单: $md5file" -ForegroundColor Cyan
$lines = Get-Content $md5file -Encoding UTF8 | Where-Object { $_ -match '^[0-9a-f]{32}' }
$ok = 0; $fail = 0; $skip = 0
foreach ($line in $lines) {
    if ($line -match '^([0-9a-f]{32})\s+(\d+)\s+(.+)$') {
        $expectMd5 = $Matches[1]
        $expectLen = [int64]$Matches[2]
        $rel = $Matches[3].Trim()
        # 路径可能是反斜杠
        $path = Join-Path $KitRoot ($rel -replace '\\','\')
        if (-not (Test-Path $path)) {
            Write-Host "[缺失] $rel" -ForegroundColor Yellow
            $skip++
            continue
        }
        $item = Get-Item $path
        if ($item.Length -ne $expectLen) {
            Write-Host "[大小不符] $rel  期望 $expectLen 实际 $($item.Length)" -ForegroundColor Red
            $fail++
            continue
        }
        $actual = (Get-FileHash $path -Algorithm MD5).Hash.ToLower()
        if ($actual -eq $expectMd5) {
            Write-Host "[OK] $rel" -ForegroundColor Green
            $ok++
        } else {
            Write-Host "[MD5不符] $rel`n  期望 $expectMd5`n  实际 $actual" -ForegroundColor Red
            $fail++
        }
    }
}
Write-Host "`n结果: OK=$ok  失败=$fail  缺失=$skip" -ForegroundColor Cyan
if ($fail -gt 0) { exit 1 }
