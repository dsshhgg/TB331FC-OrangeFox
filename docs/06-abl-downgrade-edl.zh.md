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
├─ one_click_of.ps1           一键编排（默认只报告；加开关才动手）
├─ detect_9008.ps1            检测 9008 端口（只读）
├─ check_abl_version.ps1      读回 abl 判断当前是 ZUI15 还是 ZUI16（只读，写之前先跑）
├─ run_downgrade.ps1          写 ZUI15 abl 到 abl_a/abl_b（UFS 模式，写完自动读回校验）
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

**先按设备现状选一条：**

| 设备现状 | 先做什么 |
|---|---|
| 能开机进系统（ZUI15 或 ZUI16） | 直接 `flash_of_and_test.ps1` 刷 OF 试一次；进不去再换 abl |
| 停在 fastboot | 先 `fastboot reboot` / 切槽回系统；或直接刷 OF 测试 |
| 黑屏 / 只能 9008 | `run_downgrade.ps1` 换 abl 后测；不行再 `run_rollback.ps1` |
| 完全不确定 | 先 `detect_9008.ps1` + `flash_of_and_test.ps1`（它第一步就打印全部状态） |

```powershell
cd E:\rom\release\TB331FC-abl-downgrade

# 0) 先离线自检（不需要设备）
powershell -ExecutionPolicy Bypass -File .\verify_staging.ps1

# 1) 平板完全关机 -> 按住【音量上】不放 -> 插数据线（进 9008）
powershell -ExecutionPolicy Bypass -File .\detect_9008.ps1
powershell -ExecutionPolicy Bypass -File .\check_abl_version.ps1   # 只读：当前是 15 还是 16
powershell -ExecutionPolicy Bypass -File .\run_downgrade.ps1 -WhatIf   # 演练，不写入
powershell -ExecutionPolicy Bypass -File .\run_downgrade.ps1           # 真写入 + 自动读回校验

# 2) 长按【电源】+【音量下】8 秒退出 9008
#    能进系统 -> 刷 OF 并测试
powershell -ExecutionPolicy Bypass -File .\flash_of_and_test.ps1
#    开不了机 -> 回滚
powershell -ExecutionPolicy Bypass -File .\run_rollback.ps1
```

脚本都是 **纯 ASCII 输出**（本机 PowerShell 5.1 按 GBK 读脚本，中文会乱码报错），
中文说明只放在这份 README 里。

**写入后自动读回校验**：`run_downgrade.ps1` 第 3 步用 `--sendimage` 把 abl_a/abl_b 的前 256KB 读回
（落在 `logs\readback\`），逐字节与 `abl_zui15.img` 比对，相同才提示 PASSED。
不想校验可加 `-SkipVerify`。该校验只读，不改设备。

---

## 四、一键脚本 `one_click_of.ps1`

**默认什么都不改**，只识别设备状态（系统 / fastboot / 9008 / 未授权 / 无设备）并给出建议，同时把全过程写进 `logs\one_click_*.txt`。

```powershell
# 只报告（安全）
powershell -ExecutionPolicy Bypass -File .\one_click_of.ps1

# 设备在 9008 时：写 ZUI15 abl（含读回校验）
powershell -ExecutionPolicy Bypass -File .\one_click_of.ps1 -AblDowngrade

# 设备在 fastboot 时：刷 OrangeFox
powershell -ExecutionPolicy Bypass -File .\one_click_of.ps1 -FlashOf
# 仍进不去才加原厂 vbmeta（默认不带）
powershell -ExecutionPolicy Bypass -File .\one_click_of.ps1 -FlashOf -DoVbmeta
# 刷完顺手测进入
powershell -ExecutionPolicy Bypass -File .\one_click_of.ps1 -FlashOf -TestBoot
```

**vbmeta 血统（本轮用 avbtool 复核）**

```
avbtool info_image --image avb\vbmeta_stock_backup.img
  Public key (sha1): 2597c218aae470a130f61162feaae70afd97f011   ← = AOSP testkey = 原厂公钥
  Algorithm: SHA256_RSA4096    Flags: 0
  Chain Partition descriptor -> vbmeta_system (rollback index 2)
  release string: avbtool 1.2.0
  Prop ... fingerprint -> Lenovo/TB331FC_PRC/TB331FC:14/.../ZUI_16.0.544_241115_PRC:user/release-keys
```

即 `avb\vbmeta_stock_backup.img` 就是**纯原厂 ZUI16 vbmeta**（8192 B），
sha256 `52ecb456…` 与只读原厂目录里的 `原 boot\vbmeta.img` **逐字节一致**，
所以 `-DoVbmeta` 用它而不是去动原厂目录。

---

## 五、风险（先说清楚）

| 风险 | 说明 | 兜底 |
|---|---|---|
| abl 写坏 | abl 属 Critical 分区，写坏表现为黑屏、只能 9008 | `run_rollback.ps1` 刷回；再无解 9008 全量刷售后包 |
| xbl 校验 | 若 xbl 对 abl 有独立哈希校验，换 ZUI15 abl 可能直接不启动 | 同上 |
| 无法判断 abl 版本 | `version-bootloader` 为空 | 只能看行为（能否进 OF）判断 |

**未修改** `E:\类\刷机\联想\TB331FC\` 原始目录（脚本只读引用其中 vbmeta 作为可选参数）。

---

## 六、关键事实（已实测/已核对）

| 项 | 值 |
|---|---|
| recovery 分区 | `0x6400000` = 100MB（A/B 各一） |
| abl_a | LUN4 扇区 56838 = 0xde06000，256 扇区 × 4096B = 1MB |
| abl_b | LUN4 扇区 206574 = 0x326ee000 |
| 扇区大小 | **4096B**（原厂 `erase_UFS-128G.xml` 与 `rawprogram*.xml` 都这么声明，故不需要 `--sectorsizeinbytes`） |
| ZUI15 abl | 1048576 B（有效载荷 0x43000 + 零填充） |
| ZUI16 abl | 274432 B 有效，本包补零到 1MB 以便回滚 |
| 两版差异 | 整 1MB 比 22.81%（239155 字节）；差异集中在 274KB 有效载荷内（即有效区约 87%） |
| 是否需要先 erase | 不需要。写入覆盖全部 256 扇区 = 整个 1MB，无残留 |
| 布局一致性 | ZUI15 与 ZUI16 两包的 `rawprogram4.xml` 中 abl_a/abl_b 完全一致（56838 / 206574 / 256 / LUN4） |
| OF 镜像 | `E:\rom\release\OrangeFox-TB331FC\OrangeFox-new.img` |
| OF 镜像结构 | v4 头，kernel=46819840（原厂内核），cmdline 空，ramdisk = legacy LZ4 @0x2ca8000 |
| OF ramdisk | 解压 48MB，含 `FFiles/`、`etc/fox.cfg`、`twres/`、`init.recovery.qcom.rc`、`nvt36523_spi.ko` |
| 可选 vbmeta | `E:\类\刷机\联想\TB331FC\镜像 img\原 boot\vbmeta.img`（ZUI16 原厂 8KB，alg=SHA256_RSA4096，flags=0） |
