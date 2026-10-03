# TB331FC · abl 降级包与 boot 分区实验记录

> **本项目规则：只用 OrangeFox，不用 TWRP。**
> 本目录同时承担两件事：① 9008 写 abl 的工具包；② boot 分区实验的完整记录（结论为「此路不通」）。

---

## 一、上次 9008 写 abl 失败的真因（已定位并修正）

历史命令（见 `E:\rom\release\ZUI15-extract\images\port_trace.txt`）：

```
tools\fh_loader.exe --port=\\.\COM5 --lun=4 --search_path=. --sendxml=abl_only.xml ...
```

**漏了 `--memoryname=ufs`**。fh_loader 默认按 eMMC 通信，目标端直接拒绝：

```
ERROR: Failed to open the SDCC Device slot 0 partition 4
ERROR: Failed to open device, type:eMMC, slot:0, lun:4 error:3
→ NAK → program FAILED
```

依据：原厂 ZUI16 包 `运行我，刷机.bat` 的两条 fh_loader 命令**都带 `--memoryname=ufs`**，
而这台是 **UFS** 存储。所以不是 LUN/扇区写错，是**存储类型没声明**。

---

## 二、目录内容

```
TB331FC-abl-downgrade\
├─ README.md                  本说明
├─ verify_staging.ps1         离线自检（只读，已跑通：ALL CHECKS PASSED）
├─ one_click_of.ps1           一键编排（默认只报告；加开关才动手）
├─ detect_9008.ps1            检测 9008 端口（只读）
├─ check_abl_version.ps1      读回 abl 判断当前是 ZUI15 还是 ZUI16（只读）
├─ run_downgrade.ps1          写 ZUI15 abl 到 abl_a/abl_b（UFS，写完自动读回校验）
├─ run_rollback.ps1           写回 ZUI16 abl（保命）
├─ flash_of_and_test.ps1      诊断状态 + 刷 OrangeFox + 测进入
├─ flash_of_to_boot.ps1       把 OF 塞进 boot 分区（含 vbmeta 重签步骤，只动一个槽）
├─ verify_in_recovery.ps1     进 OF 后跑验证清单（触摸/动态分区/FBE/MTP/FastbootD）
├─ tests\                     离线分发测试（假设备桩，不需要真机）
├─ images\
│  ├─ abl_zui15.img            1048576 B  sha256 349b5b40…
│  ├─ abl_zui16_padded.img     1048576 B  sha256 22eaf506…（原厂 abl 补零到 1MB）
│  ├─ prog_firehose_ddr.elf    SM6225 firehose
│  ├─ write_abl_zui15.xml      abl_a @ LUN4 扇区 56838 / abl_b @ 206574
│  └─ write_abl_zui16.xml      同上，镜像换成 ZUI16
└─ tools\
   ├─ fh_loader.exe
   └─ QSaharaServer.exe
```

脚本刻意写成**纯 ASCII 输出**：本机 Windows PowerShell 5.1 按 GBK 读脚本文件，
中文会乱码并触发语法错误。中文说明集中在本文档。

---

## 三、执行顺序（你在电脑上操作）

**先按设备现状选一条：**

| 设备现状 | 先做什么 |
|---|---|
| 能开机进系统 | 先 `check_abl_version.ps1` 判断 abl 版本，再决定是否降级 |
| 停在 fastboot | `flash_of_and_test.ps1` 刷 OF 并测进入 |
| 黑屏 / 只能 9008 | `run_downgrade.ps1` 换 abl 后测；不行再 `run_rollback.ps1` |
| 完全不确定 | `one_click_of.ps1`（纯报告，不动设备） |

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

**写入后自动读回校验**：`run_downgrade.ps1` 第 3 步用 `--sendimage` 把 abl_a/abl_b 的前 256KB 读回
（落在 `logs\readback\`），逐字节与 `abl_zui15.img` 比对，相同才提示 PASSED。
不想校验可加 `-SkipVerify`。该校验只读，不改设备。

---

## 四、一键脚本 `one_click_of.ps1`

**默认什么都不改**，只识别设备状态（系统 / fastboot / 9008 / 未授权 / 无设备）并给出建议，
同时把全过程写进 `logs\one_click_*.txt`。

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

**vbmeta 血统（用 avbtool 复核）**

```
avbtool info_image --image avb\vbmeta_stock_backup.img
  Public key (sha1): 2597c218aae470a130f61162feaae70afd97f011   ← = AOSP testkey = 原厂公钥
  Algorithm: SHA256_RSA4096    Flags: 0
  Chain Partition descriptor -> vbmeta_system (rollback index 2)
  release string: avbtool 1.2.0
  Prop ... fingerprint -> Lenovo/TB331FC_PRC/TB331FC:14/.../ZUI_16.0.544_241115_PRC:user/release-keys
```

即 `avb\vbmeta_stock_backup.img` 就是**纯原厂 ZUI16 vbmeta**（8192 B，sha256 `52ecb456…`），
与只读原厂目录里的 `原 boot\vbmeta.img` 逐字节一致。

原厂 vbmeta 的哈希描述符覆盖：`boot / dtbo / init_boot / recovery / vendor_boot / odm /
system_dlkm / vendor / vendor_dlkm`（+ chain 到 `vbmeta_system`），**flags=0（校验开启）**。

---

## 五、风险（先说清楚）

| 风险 | 说明 | 兜底 |
|---|---|---|
| abl 写坏 | abl 属 Critical 分区，写坏表现为黑屏、只能 9008 | `run_rollback.ps1` 刷回；再无解 9008 全量刷售后包 |
| xbl 校验 | 若 xbl 对 abl 有独立哈希校验，换 ZUI15 abl 可能直接不启动 | 同上 |
| 无法判断 abl 版本 | `version-bootloader` 为空 | 只能看行为，或用 `check_abl_version.ps1` 读回比对 |
| 900E 假死 | 刷写后重启可能落到 `Qualcomm HS-USB Diagnostics 900E`，adb/fastboot 均不可用 | 长按电源强制断电 → 音量键重新进 fastboot / 9008 |

**未修改** `E:\类\刷机\联想\TB331FC\` 原始目录（脚本只读引用其中文件）。

---

## 六、关键事实（已实测/已核对）

| 项 | 值 |
|---|---|
| recovery 分区 | `0x6400000` = 100MB（A/B 各一） |
| boot 分区 | `0x6000000` = 96MB |
| vbmeta 分区 | `0x10000` = 64KB |
| abl_a | LUN4 扇区 56838 = 0xde06000，256 扇区 × 4096B = 1MB |
| abl_b | LUN4 扇区 206574 = 0x326ee000 |
| 扇区大小 | **4096B**（原厂 `erase_UFS-128G.xml` 与 `rawprogram*.xml` 一致声明） |
| ZUI15 abl | 1048576 B（有效载荷 0x43000 + 零填充） |
| ZUI16 abl | 274432 B 有效，本包补零到 1MB 以便回滚 |
| 两版 abl 差异 | 整 1MB 比 **239155 字节**，区间精确落在 `0x1108-0x3d708`；**不是**同一份补零 |
| 是否需要先 erase | 不需要。写入覆盖全部 256 扇区 = 整个 1MB，无残留 |
| 布局一致性 | ZUI15 与 ZUI16 两包 `rawprogram4.xml` 中 abl_a/abl_b 完全一致（56838 / 206574 / 256 / LUN4） |
| OF 镜像 | `OrangeFox-TB331FC\OrangeFox-new.img`（v4 头、原厂内核 46819840、ramdisk legacy LZ4 23860970） |
| OF ramdisk | 解压 48.5MB / 783 条目，含 `init`、`system/bin/recovery`、`etc/fox.cfg`、`FFiles/`、`twres/`、`nvt36523_spi.ko` |
| OF 内 fstab | `/data f2fs ... encryptable=footer`；`/metadata f2fs ... formattable,wrappedkey` |
| 原厂 vbmeta | 8192 B，alg=SHA256_RSA4096，flags=0，公钥 `2597c218…` |

---

## 七、离线取证：换 abl 会不会连 9008 都救不回？

担心点是「xbl 对 abl 有独立哈希/单调版本校验 → 换旧 abl 直接变砖」。三种可能逐一排查：

**1. xbl / uefi_sec 里找不到 abl 的哈希**

对两个 abl 各算 5 个区间的 sha256（整文件、`0..0x3000`、`0x3000..0x43000`、`0x1622..0x3000`、
`0x3d709..0x43000`），去 `xbl.elf` / `xbl_config.elf` / `uefi_sec.mbn`（含 ZUI15 版）里搜哈希字节
→ **零命中**。即**没有静态哈希表在管 abl**。

**2. 两版是同一套 ELF 布局、同一套签名框架**

```
ph0 type=0 off=0x0     filesz=148
ph1 type=0 off=0x1000  filesz=6712  memsz=8192   vaddr=0x9fa40000
ph2 type=1 off=0x3000  filesz=262144 memsz=262144 vaddr=0x9fa00000
```

两版三个 program header 完全一致；证书链区 `0x1622..0x3000` 与尾部签名附录 `0x3d709..0x43000`
的 sha256 **逐字节相同**（`deaf8138…` / `63597c72…`）→ 同一 Lenovo/Elm CA 链。

**3. 元数据区没有单调版本号**

`ph1`（8192 B）内两版差异只有 **7 段**，全是签名与证书有效期：

| 偏移 | 内容 |
|---|---|
| `0x108-0x1aa`（163 B） | RSA 签名 #1 |
| `0x1ac-0x237`（140 B） | RSA 签名 #2 |
| `0x2fb-0x305` / `0x30a-0x314` | 证书有效期：Z15 `231031→431026`；Z16 `240419→440414` |
| `0x384-0x483` / `0x522-0x576` / `0x578-0x621` | 其余签名数据 |

**综合判断**：换 ZUI15 abl 大概率不会被 xbl 拒绝；即便引导失败，PBL/Sahara（9008）不依赖 abl，
仍可用 `run_rollback.ps1` 或售后包全量刷回。

**还查了「abl 是否拿原厂 recovery 哈希做白名单」**：对原厂 recovery 算了 9 种候选摘要
（`sha256/sha1/md5` × 前 14577664 / 4096 / 65536 字节），去 `abl.elf`、`abl.img`、`xbl.elf`、
`uefi_sec.mbn`、`storsec.mbn` 里搜字节 → **零命中**。说明白名单里没有明文/裸哈希常量。

### 7.1 ZUI15 原厂分区坐标（从原厂 `rawprogram*.xml` 解析，已逐行核对）

| 分区 | LUN | 起始扇区 | 扇区数 | 文件 | 本地是否具备 |
|---|---|---|---|---|---|
| `xbl_a` / `xbl_b` | 1 / 2 | 6 | 896 | `xbl.img` | ✅ 3670016 B |
| `xbl_config_a` / `_b` | 1 / 2 | 902 | 32 | `xbl_config.img` | ✅ 131072 B |
| `abl_a` / `abl_b` | 4 | 56838 / 206574 | 256 | `abl.img` | ✅ 1048576 B |
| `boot_a` / `boot_b` | 4 | 65414 / 215150 | 24576 | `boot.img` | ✅ 100663296 B |
| `init_boot_a` / `_b` | 4 | 97518 / 297430 | 2048 | `init_boot.img` | ✅ 8388608 B |
| `vbmeta_a` / `vbmeta_b` | 4 | 90294 / 240030 | 16 | `vbmeta.img` | ✅ 65536 B |
| `vbmeta_system_a` / `_b` | 0 | 3235720 / 3235736 | 16 | `vbmeta_system.img` | ✅ 65536 B |
| `dtbo_a` / `dtbo_b` | 4 | 90310 / 240046 | 6144 | `dtbo.img` | ✅ 25165824 B |
| `recovery_a` / `_b` | 4 | 99566 / 247254 | 25600 | `recovery.img` | ✅ 104857600 B |
| `vendor_boot_a` / `_b` | 4 | 125166 / 272854 | 24576 | `vendor_boot.img` | ✅ 100663296 B |
| `super` / `metadata` | 0 | 89992 / 3235752 | 3145728 / 16384 | — | ❌ 未解包 |

逐条目核验：本地 17 个条目尺寸与声明**完全一致**，0 个超出、0 个不足；
其余「不足」条目都是本目录未解包的其它固件（`rpm/tz/hyp/modem/dsp/...`）。

---

## 八、进 OrangeFox 后的自动验证清单（`verify_in_recovery.ps1`）

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_in_recovery.ps1
# 可选：-NoFastbootD 跳过 fastbootd 测试（该测试会重启出 recovery）
```

覆盖 15 项，逐项 PASS/WARN/FAIL/SKIP，结果落到 `logs\verify_recovery_*.txt`：
身份标记（`ro.twrp.version`/`ro.orangefox.version`/`/etc/fox.cfg`/`/FFiles`）、内核与 cmdline、
触摸（`/proc/bus/input/devices` + dmesg + `nvt*.ko`）、动态分区（`/dev/block/mapper`、`dm-*`、`/proc/mounts`）、
FBE（`/data` 挂载、`ls /data`、dmesg 里 fbe/fscrypt/keymaster）、MTP/USB、`by-name`、FastbootD `is-userspace`。

**设计注意**：设备侧只发**不带管道/重定向/引号**的单条命令，过滤与聚合都在 PC 端做。
原因：Windows 侧向 adb 传参时管道与重定向会被本机 shell 吃掉，会让验证结果不可信。

**离线实测**（假设备桩）：

```
假 OrangeFox   : PASS 15 / FAIL 0 / WARN 0 / SKIP 0
假原厂 recovery : 正确识别为 stock
无设备         : FAIL(device online) 并提示先刷 OF
```

---

## 九、boot 分区实验（2026-10-03 实测）—— **结论：此路不通（已排除）**

> ⚠️ 本章最初写过「boot 分区不受 recovery 白名单限制、已成功进入 recovery」的结论。
> 后续**对照实验推翻了它**。以下为修正后的完整记录，请以本章为准。

### 9.1 做了什么

1. 用 avbtool 以 **AOSP testkey** 重签 vbmeta：保留原厂 30 个描述符，把 `boot` 描述符换成
   **我们镜像**的哈希（沿用原厂 salt `0b8f7e2f…`），并另出 flags=3 版本。
   产物：`avb\vbmeta_bootfix_flags0.img` / `_flags3.img`（8192 字节，公钥 sha1 `2597c218…`）。
2. 重建镜像 `OrangeFox-boot.img` = 原厂 boot 头 + **原厂 GKI 内核（46819840 B）** + OF ramdisk（23860970 B）。
   占用 67.4 MB / 96 MB。
3. `fastboot flash vbmeta_a` + `fastboot flash boot_a`（**只动 A 槽**），再 `fastboot reboot recovery`。

### 9.2 观察到的现象

| 观察点 | 结果 |
|---|---|
| 刷入 | `vbmeta_a` OKAY / `boot_a` 98304 KB OKAY，`slot-unbootable:a` yes → no |
| 重启后 | `adb devices` 显示 `recovery`，`adb get-state` = `recovery`，USB `VID_18D1&PID_D001` |
| `adb shell` | 任意命令 → `adbd F shell_service.cpp:380 Could not set SELinux context for subprocess` → SIGABRT |
| **屏幕** | 机主确认：**原厂 recovery 菜单**（不是 OrangeFox） |
| 系统 | 刷回原厂 boot 后 ZUI 16.0.544 正常启动，数据未受影响 |

### 9.3 决定性对照实验（推翻最初的结论）

用**纯原厂状态**（boot_a 原厂 + vbmeta_a 原厂 + recovery_a 原厂）再进一次 recovery：

| 配置 | `adb get-state` | `adb shell` |
|---|---|---|
| 纯原厂 | `recovery` | **崩溃，报同一个 `Could not set SELinux context`** |
| boot_a 放 OF 镜像（flags0 / flags3 均试） | `recovery` | 崩溃，**完全一致** |

→ 两条路径**行为无差别**，因此：

1. `adb shell` 崩溃是**原厂 recovery 的固有行为**，用它判断「OF 是否在跑」是**无效证据**；
2. `adb get-state=recovery` / USB `D001` 只是 **recovery 模式标识**，原厂 recovery 给的值一模一样，
   **同样不能**证明 OF 在运行；
3. 机主两次看到的都是**原厂 recovery 菜单** → 这台机器在 recovery 模式下**走的是 recovery 分区**，
   放进 `boot_a` 的 OF 镜像**看不出被执行的证据**；
4. `-Vbmeta flags3`（禁校验）与 `flags0` 结果相同 → 与 AVB 校验状态无关。

### 9.4 修正后的结论

- **「塞进 boot 分区绕过 recovery 白名单」在本机不成立**：recovery 模式下实际生效的是 recovery 分区，
  白名单依旧拦住第三方 recovery；
- 与白名单相关的事实**没有变化**：第三方 recovery 直刷 recovery 分区一律被拦/跳过；
- 此前「boot 分区不受白名单限制」的表述**已作废**。

### 9.5 本次真正的收获（仍然有效）

1. **vbmeta 可用 AOSP testkey 重签**：把 `boot` 描述符换成我们镜像的哈希后 **系统仍正常启动**
   （ZUI 16.0.544，`verifiedbootstate=orange`）→ **签名链被引导层接受**；
2. **分区结构事实**（纠正长期误解，见 9.6）；
3. **可复用产物**：`OrangeFox-boot.img`、两个重签 vbmeta、`flash_of_to_boot.ps1`；
4. **诊断教训**：`adb get-state=recovery` 与 `adb shell` 崩溃**都不能**作为「OF 是否启动」的判据；
   以后只能靠**屏幕**，或（shell 可用时）`ro.twrp.version` / `/FFiles`。

### 9.6 分区结构事实（本轮新查明）

| 分区 | 实际内容 | 依据 |
|---|---|---|
| `boot_a` | **只有 头(4096) + 内核(46819840) + AVB 块(896)**，**没有 ramdisk** | AVB footer：`original_image_size=46841856`、`vbmeta_offset=46841856` |
| `vendor_boot_a` | **正常启动用的 ramdisk 在这里**：`VNDRBOOT` v4 头，`vendor_ramdisk_size=11553237`（11.0 MB，legacy LZ4） | 解析 `ZUI15-extract\images\vendor_boot.img` |
| `recovery_a` | 出厂 recovery（100MB 分区；ZUI16 原厂镜像 sha256 `EA89E4C3…`） | 原厂 rawprogram + 指纹比对 |

`vendor_boot` 的 cmdline：`video=vfb:640x400,bpp=32,memsize=3072000 bootconfig`
（ABL 注入 `video=vfb`，虚拟帧缓冲，与显示初始化相关）。

### 9.7 本地镜像指纹对照（将来确认设备上是哪版用）

| 文件 | 大小 | sha256 前 20 |
|---|---|---|
| `cmp\stock-recovery.img`（= ZUI16 原厂） | 100663296 | `EA89E4C32E490B5EACD6` |
| ZUI16 包 `image\recovery.img` | 100663296 | `EA89E4C32E490B5EACD6` |
| ZUI15 包 `images\recovery.img` | 104857600 | `D3646E0F3154E249A73D` |
| `cmp\of-stocktpl.img` | 100663296 | `0D9D5FFE23F2F7D6157E` |
| `OrangeFox-stockhdr.img` | 104857600 | `81FBAB23FB721A15D84E` |
| `OrangeFox-new.img` | 104857600 | `30EF74EB1D19BD1C61DE` |
| `OrangeFox-boot.img` | 100663296 | `89375E0D944E1A88` |

### 9.8 提醒：900E 状态

刷回原厂 boot 后重启，设备一度停在 **`Qualcomm HS-USB Diagnostics 900E`**（`USB\VID_05C6&PID_900E`，COM6），
此状态下 `adb` / `fastboot` 均不可用，需按键（长按电源强制断电 → 音量键）重新进 fastboot / 9008。
本次由机主手动操作后回到系统，**数据全程未受影响**。

---

## 十、当前设备状态与结论汇总

- 设备：`HA1YPQJB`，ZUI `16.0.544`（`TB331FC_CN_OPEN_USER_Q00003.0_U_ZUI_16.0.544_ST_241115`），
  槽位 `_a`，`verifiedbootstate=orange`，系统正常、数据完好；
- boot_a / vbmeta_a 已恢复原厂（`cmp\stock-boot.img` + `avb\vbmeta_stock_backup.img`）；
- recovery 分区为原厂 → **recovery 白名单依旧是拦第三方 recovery 的那道墙**；
- 若要继续冲 OF，只剩两条实路：
  1. **9008 换 abl**（ZUI15 abl 已在包内，命令已修正为带 `--memoryname=ufs`）后再试；
  2. **APatch / KernelSU 刷 boot** 做 Root（不依赖 recovery）。
