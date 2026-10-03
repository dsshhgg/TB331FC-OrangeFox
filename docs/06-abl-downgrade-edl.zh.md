# TB331FC · abl 降级包（离线准备完毕，尚未在设备上执行）

> 目的：把 `abl`（A/B 两槽）从 **ZUI16** 换成 **ZUI15**，验证「ZUI16 abl 里有 recovery 白名单」这个假设。
> 全流程 **只碰 abl**，不动 origin 目录、不动 boot/vbmeta。

---

## 一、为什么上次 9008 写 abl 失败（这次已定位并修正）

上次的命令（见 `E:\rom\release\ZUI15-extract\images\port_trace.txt`）：

```
tools\fh_loader.exe --port=\\.\COM5 --lun=4 --search_path=. --sendxml=abl_only.xml ...
```

**漏了 `--memoryname=ufs`**。fh_loader 默认按 **eMMC** 走，目标端直接报：

```
ERROR: Failed to open the SDCC Device slot 0 partition 4
ERROR: Failed to open device, type:eMMC, slot:0, lun:4 error:3
```

这台平板是 **UFS** 存储。原厂 `运行我，刷机.bat` 里两条 fh_loader 命令**都带 `--memoryname=ufs`**：

```
tool\fh_loader.exe --port=\\.\%ProtNumber% --search_path=%~dp0image --sendxml=FHLoaderErase.xml ... --memoryname=ufs
tool\fh_loader.exe --port=\\.\%ProtNumber% --search_path=%~dp0image --sendxml=rawprogram0.xml,... --memoryname=ufs ...
```

**结论：不是 LUN 参数错，是存储类型没声明。** 本包脚本已按原厂写法修正。

---

## 二、目录内容

```
TB331FC-abl-downgrade\
├─ README.md                  本说明
├─ verify_staging.ps1         离线自检（只读，已跑通：ALL CHECKS PASSED）
├─ detect_9008.ps1            检测 9008 端口（只读）
├─ run_downgrade.ps1          写 ZUI15 abl 到 abl_a/abl_b（UFS 模式）
├─ run_rollback.ps1           写回 ZUI16 abl（保命）
├─ flash_of_and_test.ps1      诊断状态 + 刷 OrangeFox + 测进入
├─ images\
│  ├─ abl_zui15.img            1048576 B  sha256 349b5b40…
│  ├─ abl_zui16_padded.img     1048576 B  sha256 22eaf506…（ZUI16 原厂 abl 补零到 1MB）
│  ├─ prog_firehose_ddr.elf    SM6225 firehose
│  ├─ write_abl_zui15.xml      abl_a @ LUN4 扇区 56838 / abl_b @ 206574
│  └─ write_abl_zui16.xml      同上，镜像换成 ZUI16
├─ tools\
│  ├─ fh_loader.exe
│  └─ QSaharaServer.exe
└─ logs\                      运行后自动生成
```

---

## 三、执行顺序（你在电脑上操作）

```powershell
cd E:\rom\release\TB331FC-abl-downgrade

# 0) 先离线自检（不需要设备）
powershell -ExecutionPolicy Bypass -File .\verify_staging.ps1

# 1) 平板完全关机 -> 按住【音量上】不放 -> 插数据线（进 9008）
powershell -ExecutionPolicy Bypass -File .\detect_9008.ps1
powershell -ExecutionPolicy Bypass -File .\run_downgrade.ps1 -WhatIf   # 演练，不写入
powershell -ExecutionPolicy Bypass -File .\run_downgrade.ps1           # 真写入

# 2) 长按【电源】+【音量下】8 秒退出 9008
#    能进系统 -> 刷 OF 并测试
powershell -ExecutionPolicy Bypass -File .\flash_of_and_test.ps1
#    开不了机 -> 回滚
powershell -ExecutionPolicy Bypass -File .\run_rollback.ps1
```

脚本都是 **纯 ASCII 输出**（本机 PowerShell 5.1 按 GBK 读脚本，中文会乱码报错），
中文说明只放在这份 README 里。

---

## 四、风险（先说清楚）

| 风险 | 说明 | 兜底 |
|---|---|---|
| abl 写坏 | abl 属 Critical 分区，写坏表现为黑屏、只能 9008 | `run_rollback.ps1` 刷回；再无解 9008 全量刷售后包 |
| xbl 校验 | 若 xbl 对 abl 有独立哈希校验，换 ZUI15 abl 可能直接不启动 | 同上 |
| 无法判断 abl 版本 | `version-bootloader` 为空 | 只能看行为（能否进 OF）判断 |

**未修改** `E:\类\刷机\联想\TB331FC\` 原始目录（脚本只读引用其中 vbmeta 作为可选参数）。

---

## 五、关键事实（已实测/已核对）

| 项 | 值 |
|---|---|
| recovery 分区 | `0x6400000` = 100MB（A/B 各一） |
| abl_a | LUN4 扇区 56838 = 0xde06000，256 扇区 × 4096B = 1MB |
| abl_b | LUN4 扇区 206574 = 0x326ee000 |
| ZUI15 abl | 1048576 B（有效载荷 0x43000 + 零填充） |
| ZUI16 abl | 274432 B 有效，本包补零到 1MB 以便回滚 |
| 两版差异 | 前 274KB 中 87.15% 字节不同，证书链区域相同 |
| OF 镜像 | `E:\rom\release\OrangeFox-TB331FC\OrangeFox-new.img` |
| OF 镜像结构 | v4 头，kernel=46819840（原厂内核），cmdline 空，ramdisk = legacy LZ4 @0x2ca8000 |
| OF ramdisk | 解压 48MB，含 `FFiles/`、`etc/fox.cfg`、`twres/`、`init.recovery.qcom.rc`、`nvt36523_spi.ko` |
| 可选 vbmeta | `E:\类\刷机\联想\TB331FC\镜像 img\原 boot\vbmeta.img`（ZUI16 原厂 8KB，alg=SHA256_RSA4096，flags=0） |
