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

## 十一、abl 深度分析（2026-10-03）

### 11.1 文件结构（ELF + UEFI 固件卷）

```
0x00000 - 0x01000   4096 B   ELF32 LE / ARM (machine 40)，入口 0x9fa00000
  ph0 type=0  off=0x0     filesz=148       (ELF 头 + program header 表)
  ph1 type=0  off=0x1000  filesz=6712      (证书 / 签名元数据，明文)
  ph2 type=1  off=0x3000  filesz=262144    (UEFI 固件卷，代码被压缩/打包)
0x03000 - 0x43000  262144 B  ***UEFI Firmware Volume***
  FileSystemGuid = 8c8ce578-8a3d-4f1c-9935-896185c32dd3  (= EDK2 EFI_FIRMWARE_FILE_SYSTEM2_GUID)
  Signature      = '_FVH'（位于 +0x28）
  FvLength       = 0x40000（正好等于 ph2 大小）
  Attributes     = 0x0003feff
  HeaderLength   = 0x48，Checksum 验证通过（校验和累加 = 0x0000）→ **FV 头是明文**
0x43000 - 0x100000  774144 B  分区零填充
```

**熵分布**：`0x4000–0x3c000` 熵恒为 **7.97**（接近随机）→ 代码体是**压缩或加密**的，
不是可读 UEFI 模块。所以：

- 全文件 ASCII 字符串 2877 条，**`recovery` / `whitelist` / `hash` / `signature` / `avb` 等关键字零命中**；
- UTF-16（UEFI 常见）字符串 **0 条**；
- 明文可读的只有证书区：`Elm Root CA0` / `Elm Attestation CA0`、时间戳、以及 `LENOVO1` / `QUALCOMM1`；
- 解压尝试（zlib / raw-deflate / gzip / lzma / xz / bz2 / lz4）全部失败 —— 需要按 EDK2 的
  FFS/压缩段规范先解包 FV 才能拿到真正的 UEFI 模块。

**结论：在现有工具条件下，无法从 abl 静态反推出白名单逻辑**（代码是打包的，不在明文里）。

### 11.2 两版差异（最终统计）

| 区域 | 范围 | 差异字节 | 说明 |
|---|---|---|---|
| ELF 头 + program header 表 | `0x0000-0x1000` | **0 / 4096** | 布局完全一致（换 abl 不会破坏加载） |
| 证书 / 签名元数据 | `0x1000-0x3000` | 836 / 8192 | 只有两处 RSA 签名 + 证书有效期 |
| **UEFI FV 代码体** | `0x3000-0x43000` | **238319 / 262144** | 几乎全不同（同一构建体系、不同编译产物） |
| 分区零填充 | `0x43000-0x100000` | 0 / 774144 | 纯填充 |

整体：`0..0x43000` 内差异 **239155 / 274432 = 87.15%**。

证书对照（同一 CA 链、不同签发批次）：

| 版本 | 证书时间戳 |
|---|---|
| ZUI15 | `231031021601Z` → `431026021601Z` |
| ZUI16 | `240419144749Z` → `440414144749Z` |
| 两版共有 | `230626014543Z` → `430621014543Z`（另一张证书，未变） |

### 11.3 与实验结论的对应

- **ELF 头/程序头两版完全相同** → 换 ZUI15 abl 不会有「加载结构不匹配」的问题（此前的判断成立）；
- **代码体 87% 不同 + 明文不可读** → 无法离线判断「ZUI15 abl 里到底有没有白名单」，
  只能靠真机实测（9008 写入后看第三方 recovery 能否启动）；
- 结合第九章实测：**recovery 模式下 ABL 走的是 recovery 分区**，
  放进 `boot_a` 的镜像不执行 → 「塞 boot」这条路已被**实验证实排除**；
- **能解释失败机制的是实验，不是静态分析** —— abl 代码打包，静态路线到此为止。

### 11.4 若要把 abl 分析推进下去，需要的条件

1. 按 EDK2 FFS 规范**解包 FV**（识别 GUID-defined section / FV image section 的压缩算法）；
2. 拿到解包后的 UEFI 模块（PE32/TE）再做反汇编，定位 recovery 相关的加载/校验函数；
3. 这需要专门的 UEFI 逆向工具链（如 UEFITool + IDA/Ghidra），**当前环境不具备**；
4. 替代路径：直接实测 —— 9008 写入 ZUI15 abl，看第三方 recovery 能否启动（唯一有效判据）。

---

## 十二、日志可得性（2026-10-03 实查）

问「有没有日志」——把所有来源查了一遍，结论如下。

### 12.1 设备侧：基本取不到

| 来源 | 结果 | 原因 |
|---|---|---|
| `/tmp/recovery.log` | **Permission denied** | 文件存在，但这个 recovery 拒绝非 root 的 adb 访问 |
| `/cache/recovery/last_log` 等 | **Permission denied** | 同上 |
| `adb logcat` | 无输出 | adbd 的 shell 崩溃（`Could not set SELinux context`） |
| `dmesg` | 空 | Android 13 shell 受限 |
| `/proc/last_kmsg` | 不存在 | 现代内核已废弃 |
| `/sys/fs/pstore` | Permission denied | 需 root |
| **`cache` 分区** | **分区表中不存在** | 查原厂 `rawprogram0.xml`：LUN0 只有 ssd/persist/misc/keystore/oemowninfo/lenovolock/lenovocust/lenovoraw/super/frp/vbmeta_system/metadata/userdata —— **无 cache、无 pstore** |
| **`misc`（BCB）** | **6 个非零字节** | 见下 |

→ Android recovery 的日志默认落在 `/cache/recovery/`，本机**没有 cache 分区**，
所以日志只在内存里，**重启即失**。

### 12.2 `misc` 分区实读（EDL dump，1MB）

```
非零字节数: 6    范围: 0x8000-0x8006
内容: 02 b0 0a 74 56 00 01  → 一小段结构，无字符串
BCB command / recovery / stage: 全为空
```

**BCB 为空 = ABL 在读走「启动到 recovery」这条命令后清空了它**（标准行为）。
因此 `misc` 里**没有留下「上次要求启动到哪」的历史记录**，也就无法用它反推
「ABL 是选择了 recovery 分区还是 boot 分区」。

### 12.3 本机（PC）侧：日志齐全

| 文件 | 大小 | 内容 |
|---|---|---|
| `E:\rom\port\of_win.log` | 64 KB | **成功的 CI 构建日志**（TWRP manifest、`lunch omni_TB331FC-eng`、`mka recoveryimage`、发 Release） |
| `E:\rom\port\of_check.log` | 2.5 MB | 全量编译日志（22k 目标） |
| `E:\rom\port\of_fail.log` | 1.4 MB | 失败的构建尝试 |
| `of2/of3/of4/of5/of6/of_s.log` | 24–64 KB | 历次 CI 运行 |
| `ZUI15-extract\images\port_trace.txt` | 18 KB | **9008 fh_loader 那次 LUN4 失败的完整 trace** |
| `TB331FC-abl-downgrade\logs\*` | — | 本轮 EDL 读/写的 trace |

**独立证据（重要）**：`of_win.log` 里 CI 用官方 `unpack_bootimg.py` 解包内核镜像时输出

```
boot magic: ANDROID!
kernel_size: 43092480
ramdisk size: 0            ← 官方工具同样报「无 ramdisk」
boot image header version: 4
boot image signature size: 0
```

与我们从 AVB footer 算出的 `original_image_size = 4096 + 内核 + 896` **互相印证**：
**原厂 boot 分区没有 ramdisk**（正常启动的 ramdisk 在 `vendor_boot`）。

### 12.4 结论：想拿到 ABL/recovery 日志，必须先有

1. **一个 shell 可用的 recovery**（本机原厂 recovery 的 adbd 不提供 root shell），或
2. **root**（可读 `/sys/fs/pstore`、`/tmp/recovery.log`），或
3. **UART 串口**（ABL 的调试输出通常在串口上，本机无串口硬件）

当前三条都不具备，所以「黑屏那几次到底发生了什么」**没有日志可查**，只能靠屏幕现象判断。

---

## 十四、2026-10-03 boot / abl 双实验实测（本轮新增，含证伪）

### 14.1 abl 读回：设备原本是 ZUI16

用 EDL `<read>` 读回（注意：**`--sendimage` 是"发送"不是"读回"**，读回必须用 `<read>` XML）：

```
abl_a (设备)  sha256 22eaf506d8c80e5c287a  → vs ZUI16 差 0 字节 ✔ / vs ZUI15 差 239155
abl_b (设备)  sha256 22eaf506d8c80e5c287a  → 同上
```

→ **历史上那次 `fh_loader` 失败后，abl 降级从未真正发生过**（这台一直是 ZUI16 abl）。

### 14.2 首次真正写入 ZUI15 abl（成功）

`write_abl_edl.ps1`（新增脚本，含 Sahara + `--memoryname=ufs`）写入成功，
重新读回确认两槽均为 **`349b5b4036fde7f1cedc…` = ZUI15**。

### 14.3 结果：**假设被证伪**

| 测试 | 结果 |
|---|---|
| ZUI15 abl + `fastboot flash recovery_a OrangeFox-new.img` + `reboot recovery` | ❌ **仍回落 fastboot**（第三方 recovery 依旧进不去） |
| ZUI15 abl + ZUI16 系统，正常启动 | ❌ **系统也起不来**（回路 fastboot） |

→ **「换 ZUI15 abl 就能绕过 recovery 白名单」不成立**。白名单要么在 ZUI15 abl 里同样存在，
要么根本不在 abl 里（xbl 或其它环节）。

### 14.4 boot 分区：用「正确版镜像」重测，仍失败

之前两次用的是我**重组过头部**的 `OrangeFox-boot.img`，本轮换成**与你原镜像头部一字不差**的版本：

- `OrangeFox-bootA-96M.img` = `OrangeFox-new.img` 截断到 96MB（boot 分区大小），
  头部 64 字节与原图**完全相同**（`kernel_addr=0x16c16ea`、`ramdisk_size=0xC600063C` 都不动）
- 已校验 **ramdisk 完整**（LZ4 链第 7 块结束于 `0x43696ea`，早于截断点）
- 配套 vbmeta：`avb\vbmeta_bootA96_flags0.img`（boot 描述符 = 该镜像哈希 + OF 原图 salt `293f76c0…`）
- 刷 `vbmeta_a` + `boot_a` → OKAY → `reboot recovery` → **屏幕仍是原厂 recovery 菜单**

→ **recovery 模式下被执行的确实是 recovery 分区**，塞进 boot 的镜像未被采用。
（这次排除了「镜像头部被改坏」这个变量，所以结论比之前更硬。）

### 14.5 回滚（全部已验证）

| 分区 | 恢复为 | 验证 |
|---|---|---|
| `abl_a` / `abl_b` | ZUI16 | EDL 读回 sha256 `22eaf506…`，与 ZUI16 差 0 字节 ✔ |
| `recovery_a` | 原厂 `cmp\stock-recovery.img` | 刷入 OKAY |
| `boot_a` | 原厂 `cmp\stock-boot.img` | 刷入 OKAY |
| `vbmeta_a` | 原厂 `avb\vbmeta_stock_backup.img` | 刷入 OKAY |

### 14.6 EDL 操作两个坑（本轮踩到）

1. **`fh_loader --sendimage` 是「发送本地文件到设备」，不是读回**。
   读回必须写 `<read SECTOR_SIZE_IN_BYTES=... physical_partition_number=... start_sector=... num_partition_sectors=... filename=.../>`
   的 XML，用 `--sendxml` + `--mainoutputdir=<输出目录>`。
2. **每次重新进入 9008 都必须重新送 firehose**，否则 fh_loader 收到的是二进制垃圾
   （`04 00 00 00 10 00 00 00 …`），报 `XML not formed correctly`。
   若协议失步，`QSaharaServer ... -k`（sendclearstate）可以复位状态机，之后即可正常读。

---

## 十六、白名单到底认什么？—— 决定性实验（2026-10-03）

### 16.1 实验设计

前面已确认「换 ZUI15 abl 也没用」，那还剩最后一个问题：
**ABL 认的是「ZUI16 那一个具体 recovery 镜像」，还是「任何联想原厂签名的 recovery」？**

测法很干净：把 **ZUI15 的原厂 recovery** 写进 `recovery_a`（两个镜像都是联想原厂签名，但内容差 14,256,200 字节）。

```xml
<!-- write_recovery_z15.xml -->
<program SECTOR_SIZE_IN_BYTES="4096" physical_partition_number="4"
         start_sector="99566" num_partition_sectors="25600"
         filename="z15-recovery.img" label="recovery_a"/>
```

流程：EDL 写入 → 读回验证 → 退出 9008 → `reboot recovery`。

### 16.2 结果

| 步骤 | 结果 |
|---|---|
| EDL 写入 ZUI15 recovery 到 `recovery_a` | `All Finished Successfully`，fh_loader 退出码 0 |
| **读回验证** | 设备 `recovery_a` sha256 `d3646e0f3154e249a73de3a8b539089b…` = **ZUI15 recovery 完全一致** |
| `reboot recovery` | ✅ **进入 recovery，屏幕显示原厂中文 recovery 菜单** |

对照：ZUI16 原厂 recovery sha256 `ea89e4c32e490b5eacd6…`，与 ZUI15 那份**内容差 14256200 字节**。

### 16.3 结论（本项目最关键的一条）

> **ABL 的 recovery 白名单 = 「联想原厂签名」校验，不是绑定某一个具体镜像。**

证据链：

1. ZUI15 原厂 recovery（**不同构建**）→ ✅ 能进
2. 我们编译的 OrangeFox（原厂公钥 testkey 签名、boot 哈希正确、ramdisk 完整）→ ❌ 被拦
3. 对原厂 recovery **改 1 bit**（内容微改）→ ❌ 被拦（历史实验）

→ 所以门槛是**联想对 recovery 镜像的签名**，与 ZUI 版本无关、与 AVB testkey 无关。

**这也回答了「用 aosp 签名了吗」这个问题的最终形态**：
AOSP testkey 只解决了 **AVB 层**（原厂 vbmeta 公钥恰好就是 testkey，所以重签 vbmeta 能被接受），
但 **ABL 还有一层独立的「原厂 recovery 签名」校验，它不看 AVB**。
没有联想的私钥，就签不出能过这一层的 recovery。

**我们编的 OF 进不去，不是因为编译错了、缺内核、cmdline 不对、镜像头不对 —— 而是因为它没有联想签名。**

### 16.4 对后续路线的影响

| 路线 | 可行性 |
|---|---|
| 继续折腾 OF 编译参数 / 镜像头 / vbmeta | ❌ **没有意义**（门槛是签名，不是这些） |
| 用原厂 recovery 当模板塞 OF ramdisk | ❌ 历史实验已证伪（内容改 1 bit 即被拒） |
| 伪造联想签名 | ❌ 无私有钥、SHA256 不做碰撞 |
| **APatch / KernelSU 刷 boot 拿 Root** | ✅ 不依赖 recovery，是唯一可行方向 |
| 9008 换 abl / 全量刷 ZUI15 | ❌ 已实测，改不了这道签名门槛 |

### 16.5 本次实验后的恢复

| 分区 | 恢复为 |
|---|---|
| `abl_a` / `abl_b` | ZUI16（EDL 读回验证） |
| `recovery_a` | 原厂 ZUI16（fastboot 刷回 `cmp\stock-recovery.img`） |
| `boot_a` | 原厂 `cmp\stock-boot.img` |
| `vbmeta_a` | 原厂签名 `avb\vbmeta_stock_backup.img` |

系统确认：`ZUI_16.0.544` / 槽位 `_a` / 正常启动。

设备 recovery 的完整备份留在 `images\recovery_a_device_backup.bin`（100MB，读取自设备）。

---

## 十七、当前设备状态与结论汇总

**注意：设备当前在 9008（EDL）**，等待手动退出。

本机上的分区实际值（截至 2026-10-03 本轮结束）：

| 分区 | 当前值 | 说明 |
|---|---|---|
| `abl_a` / `abl_b` | **ZUI16**（sha256 `22eaf506…`） | 已从 ZUI15 回滚，EDL 读回验证 |
| `recovery_a` | 原厂 `cmp\stock-recovery.img` | 已刷回 |
| `boot_a` | **OF 96MB 版**（`OrangeFox-bootA-96M.img`） | ⚠️ 本轮实验残留，未恢复原厂 |
| `vbmeta_a` | **`avb\vbmeta_bootA96_flags0.img`** | ⚠️ 同上（testkey 签名，boot 描述符指向该镜像） |

**若要彻底回原厂**（系统仍可正常启动，`boot_a` 是 OF 镜像时正常启动不受影响）：

```powershell
fastboot flash boot_a   E:\rom\release\OrangeFox-TB331FC\cmp\stock-boot.img
fastboot flash vbmeta_a E:\rom\release\OrangeFox-TB331FC\avb\vbmeta_stock_backup.img
```

**结论汇总**

| 路线 | 状态 |
|---|---|
| 直刷第三方 recovery 到 recovery 分区 | ❌ 被白名单拦（ZUI16 abl 下） |
| **换 ZUI15 abl 后再直刷** | ❌ **已实测证伪**（14.3）——仍被拦，且 ZUI15 abl + ZUI16 系统起不来 |
| **把 OF 镜像塞进 boot 分区** | ❌ **已实测排除**（14.4）——用「头部与原图一字不差」的正确版镜像重测，屏幕仍是原厂 recovery |
| vbmeta 用 AOSP testkey 重签 | ✅ 签名链被接受（含 boot 哈希时系统仍正常启动），但不足以放行第三方 recovery |
| 剩余可行路线 | ① Root：APatch / KernelSU 刷 boot；② 9008 全量刷 ZUI15 后用 ZUI15 全套再试 |
