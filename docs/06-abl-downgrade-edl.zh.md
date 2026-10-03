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
├─ flash_of_to_boot.ps1       **把 OF 塞进 boot 分区**（含 vbmeta 重签步骤，只动一个槽）
├─ verify_in_recovery.ps1     **进 OF 后跑验证清单**（触摸/动态分区/FBE/MTP/FastbootD，出报告）
├─ tests\                     **离线分发测试**（假设备桩，不需要真机）
│  ├─ stub_device.cmd         假 adb/fastboot（用 TB331FC_FAKE_DEVICE 切换状态）
│  └─ test_dispatch.ps1       9 条用例，已全部通过
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
| 两版差异 | 整 1MB 比 **239155 字节**，差异区间精确落在 `0x1108-0x3d708`（= 元数据签名段 0x108-0x621 + 代码段 ph2 0x3000-0x43000）；**不是**「同一份二进制补零」，是两份不同构建 |
| 是否需要先 erase | 不需要。写入覆盖全部 256 扇区 = 整个 1MB，无残留 |
| 布局一致性 | ZUI15 与 ZUI16 两包的 `rawprogram4.xml` 中 abl_a/abl_b 完全一致（56838 / 206574 / 256 / LUN4） |
| OF 镜像 | `E:\rom\release\OrangeFox-TB331FC\OrangeFox-new.img` |
| OF 镜像结构 | v4 头，kernel=46819840（原厂内核），cmdline 空，ramdisk = legacy LZ4 @0x2ca8000 |
| OF ramdisk | 解压 48MB，含 `FFiles/`、`etc/fox.cfg`、`twres/`、`init.recovery.qcom.rc`、`nvt36523_spi.ko` |
| OF 内 fstab | `/data f2fs ... encryptable=footer`；`/metadata f2fs ... formattable,wrappedkey`（FBE 的关键是 metadata 包裹密钥）；system/vendor/product 均 `logical`（动态分区） |
| 可选 vbmeta | `E:\rom\release\OrangeFox-TB331FC\avb\vbmeta_stock_backup.img`（原厂 ZUI16，8192 B，sha256 `52ecb456…`，avbtool 公钥 sha1 `2597c218…` = AOSP testkey，flags=0，chain→vbmeta_system） |

---

## 七、离线取证：换 abl 会不会连 9008 都救不回？（本轮结论）

担心点是「xbl 对 abl 有独立哈希/单调版本校验 → 换旧 abl 直接变砖」。本轮把三种可能逐一排查：

**1. xbl / uefi_sec 里找不到 abl 的哈希**

对两个 abl 各算 5 个区间的 sha256（整文件、`0..0x3000`、`0x3000..0x43000`、`0x1622..0x3000`、
`0x3d709..0x43000`），再去 `xbl.elf` / `xbl_config.elf` / `uefi_sec.mbn`（含 ZUI15 版本）里搜哈希字节
→ **零命中**。即**没有静态哈希表在管 abl**。

**2. 两版是同一套 ELF 布局、同一套签名框架**

```
ph0 type=0 off=0x0     filesz=148
ph1 type=0 off=0x1000  filesz=6712  memsz=8192   vaddr=0x9fa40000
ph2 type=1 off=0x3000  filesz=262144 memsz=262144 vaddr=0x9fa00000
```

两版三个 program header 完全一致；证书链区 `0x1622..0x3000` 与尾部签名附录 `0x3d709..0x43000`
的 sha256 **逐字节相同**（`deaf8138…` / `63597c72…`）→ 同一 Lenovo/Elm CA 链。

**3. 元数据区没有单调版本号（不易被 anti-rollback 拒绝）**

`ph1`（8192 B）内两版差异只有 **7 段**，全是签名与证书有效期：

| 偏移 | 内容 |
|---|---|
| `0x108-0x1aa`（163 B） | RSA 签名 #1 |
| `0x1ac-0x237`（140 B） | RSA 签名 #2 |
| `0x2fb-0x305` / `0x30a-0x314` | 证书有效期：Z15 `231031021601Z`→`431026021601Z`；Z16 `240419144749Z`→`440414144749Z` |
| `0x384-0x483` / `0x522-0x576` / `0x578-0x621` | 其余签名数据 |

即 **ZUI15 abl 签于 2023-10-31，ZUI16 abl 签于 2024-04-19**，没有递增版本计数器可供拒绝回滚。

**综合判断**：换 ZUI15 abl **大概率不会被 xbl 拒绝**；即便引导失败，PBL/Sahara（9008）不依赖 abl，
仍可用 `run_rollback.ps1` 或售后包全量刷回。这不是 100% 保证，但三个最可能的拒绝机制都已排除。

**顺带否掉一个假前提**：曾怀疑「ZUI15 的 abl.img 就是 ZUI16 abl 补零到 1MB，换了等于没换」。
实测两者 sha256 不同、差 239155 字节（差异区间 `0x1108-0x3d708`），
且 ZUI15 侧证书签于 2023-10-31、ZUI16 侧签于 2024-04-19 → **确实是两份不同构建**，降级有实质变化。

**还查了「abl 是否拿原厂 recovery 哈希做白名单」**：对原厂 recovery 算了 9 种候选摘要
（`sha256/sha1/md5` × 前 14577664 / 4096 / 65536 字节），去 `abl.elf`、`abl.img`、`xbl.elf`、
`uefi_sec.mbn`、`storsec.mbn` 里搜字节 → **零命中**。说明白名单实现里没有明文/裸哈希常量，
更可能是代码内逻辑或另一套签名校验（这部分只能真机实测，无法离线定论）。

### 7.1 ZUI15 原厂分区坐标（从原厂 `rawprogram*.xml` 解析，已核对）

万一 abl 写完需要救机，这就是「哪块在哪个 LUN 哪个扇区」的权威清单：

| 分区 | LUN | 起始扇区 | 扇区数 | 文件 | 本地是否具备 |
|---|---|---|---|---|---|
| `xbl_a` | 1 | 6 | 896 | `xbl.img` | ✅ 3670016 B |
| `xbl_config_a` | 1 | 902 | 32 | `xbl_config.img` | ✅ 131072 B |
| `xbl_b` | 2 | 6 | 896 | `xbl.img` | ✅ |
| `abl_a` | 4 | 56838 (0xde06000) | 256 | `abl.img` | ✅ 1048576 B |
| `abl_b` | 4 | 206574 (0x326ee000) | 256 | `abl.img` | ✅ |
| `boot_a` / `boot_b` | 4 | 65414 / 215150 | 24576 | `boot.img` | ✅ 100663296 B |
| `init_boot_a` / `init_boot_b` | 4 | 97518 / 297430 | 2048 | `init_boot.img` | ✅ 8388608 B |
| `vbmeta_a` / `vbmeta_b` | 4 | 90294 / 240030 | 16 | `vbmeta.img` | ✅ 65536 B |
| `vbmeta_system_a` / `_b` | 0 | 3235720 / 3235736 | 16 | `vbmeta_system.img` | ✅ 65536 B |
| `dtbo_a` / `dtbo_b` | 4 | 90310 / 240046 | 6144 | `dtbo.img` | ✅ 25165824 B |
| `recovery_a` / `_b` | 4 | 99566 / 247254 | 25600 | `recovery.img` | ✅ 104857600 B |
| `vendor_boot_a` / `_b` | 4 | 125166 / 272854 | 24576 | `vendor_boot.img` | ✅ 100663296 B |
| `super`（动态分区容器） | 0 | 89992 | 3145728 | `super.img` | ❌ 未解包（12GB） |
| `metadata`（FBE 包裹密钥） | 0 | 3235752 | 16384 | `metadata.img` | ❌ 未解包 |

**逐条目核验结果**：ZUI15 解包目录里 **17 个条目尺寸与声明完全一致、0 个超出、0 个不足**；
44 个「不足」全部是**本目录未解包的其它固件**（`xbl.img` 之外还有 `rpm/tz/hyp/modem/dsp/keymaster/
devcfg/qupfw/bluetooth/super/metadata/gpt_*` 等），需要时从 ZUI15 原包再取。
`xbl.img` / `xbl_config.img` 尺寸校验通过（`896×4096=3670016`、`32×4096=131072`）。

**离线分发测试**（`tests\test_dispatch.ps1`，不需要真机）——9 条用例全通过：

```
no device -> plan F          fastboot flash -> recovery_a / recovery_b
fastboot  -> plan B          +DoVbmeta      -> vbmeta_a / vbmeta_b
system    -> plan C          recovery       -> plan D
unauthorized -> plan E       edl -> plan A（WMI 检测，文件桩无法伪造，标 MANUAL）
DISPATCH TESTS PASSED
```

这轮测试抓出一个真 bug：`one_click_of.ps1 -FlashOf -DoVbmeta` 原本**自己刷、没调用**
`flash_of_and_test.ps1`，导致 `-DoVbmeta` 是空操作；已改为委派并复测通过。

---

## 九、重大发现（2026-10-03 实测）：boot 分区**不受** recovery 白名单限制

这是本项目第一次**真正进入 recovery 模式**，路径是「不用 recovery 分区，把镜像塞进 boot」。

### 9.1 做了什么

1. 用 avbtool 以 **AOSP testkey** 重签 vbmeta：保留原厂 30 个描述符（去掉原 `boot` 描述符），
   加入**我们镜像**的 boot 哈希（沿用原厂 salt `0b8f7e2f…`），另有 flags=3 版本。产物：
   `E:\rom\release\OrangeFox-TB331FC\avb\vbmeta_bootfix_flags0.img` / `_flags3.img`
2. 重建镜像 `OrangeFox-boot.img` = 原厂 boot 头 + **原厂 GKI 内核（46819840 B）** + OF ramdisk（23860970 B）
3. `fastboot flash vbmeta_a` + `fastboot flash boot_a`（**只动 A 槽**，B 槽保持原厂）

### 9.2 结果（设备 `HA1YPQJB`）

| 观察点 | 实测值 | 含义 |
|---|---|---|
| 刷入 | `vbmeta_a` OKAY / `boot_a` 98304 KB OKAY | 写入成功 |
| `slot-unbootable:a` | **yes → no** | 引导层把它当可用镜像 |
| `fastboot reboot recovery` 后 | 出现 **USB `VID_18D1&PID_D001`**（Android Composite ADB Interface） | **这是 recovery 模式标识** |
| `adb get-state` | **recovery** | 设备确实进了 recovery |
| 屏幕 | 黑屏 | recovery 第二阶段/图形没起来 |
| `adb shell`（任意命令） | `adbd F shell_service.cpp:380 Could not set SELinux context for subprocess` → `libc Fatal signal 6 (SIGABRT)` | adbd 在跑但 sepolicy 不完整 |
| 回滚 | 刷回 `cmp\stock-boot.img` → 系统正常启动 | 可安全回退 |

系统侧复核（刷回原厂 boot 后）：

```
ro.build.display.id       = TB331FC_CN_OPEN_USER_Q00003.0_U_ZUI_16.0.544_ST_241115
ro.boot.slot_suffix       = _a
ro.boot.verifiedbootstate = orange
```
且**我们重签的 `vbmeta_a` 仍留在设备上、系统正常启动** → 说明 **testkey 签名链被引导层接受**。

### 9.3 结论

1. **recovery 分区那道白名单是真的**（此前所有第三方 recovery 直刷 recovery 分区都被拦/跳过）；
2. **boot 分区不在白名单范围内** —— 把镜像塞进 boot 后，引导层**放行并进入了 recovery 模式**；
3. 因此「AVB 层面」这条路是通的（testkey 签名 + 正确的 boot 哈希 = 系统都照常启动）；
4. 剩下的失败点是 **OF recovery 自身在 boot 路径下的启动/显示/初始化**，不是引导层拦截。

### 9.4 下次可试（未执行，B 方案暂缓）

- 用 `-Vbmeta flags3`（禁校验）再试，减少 recovery 受到的约束；
- 把 **原厂 boot ramdisk 与 OF ramdisk 合并**成同一镜像：正常情况下能启动系统、进 recovery 时跑 OF ——
  这样失败也不用救机（当前失败会导致系统也起不来，必须手动回 fastboot 刷回）；
  ⚠️ **2026-10-03 复核：此方案前提不成立**，见 9.6——原厂 boot 分区没有 ramdisk 可合并；
- 查黑屏根因方向：fb/panel 驱动初始化、recovery 的 `init.recovery.*.rc` 是否执行到、sepolicy 是否加载完整。

### 9.6 关键结构事实（本轮新查明，纠正了此前的误解）

| 分区 | 实际内容 | 依据 |
|---|---|---|
| `boot_a` | **只有 头(4096) + 内核(46819840) + AVB 块(896)**，**没有 ramdisk** | AVB footer：`original_image_size=46841856`、`vbmeta_offset=46841856` |
| `vendor_boot_a` | **正常启动用的 ramdisk 在这里**：`VNDRBOOT` v4 头，`vendor_ramdisk_size=11553237`（11.0 MB，legacy LZ4） | 直接解析 `ZUI15-extract\images\vendor_boot.img` |
| `recovery_a` | 出厂 recovery 镜像（100MB 分区，`recovery.img` 由原厂 96MB 模板 + kernel=0） | 原厂 rawprogram |

`vendor_boot` 的 cmdline：`video=vfb:640x400,bpp=32,memsize=3072000 bootconfig`
（ABL 会注入 `video=vfb`，即虚拟帧缓冲；**显示初始化相关**）。

**由此解释**：
- 正常启动 = 用 vendor_boot 的 ramdisk（我们没动它）→ 系统正常；
- recovery 模式 = 用 **boot 分区**的 ramdisk → 我们放 OF 镜像后**成功进入 recovery 模式**（USB `D001`）；
- 所以「把原厂 boot ramdisk 与 OF ramdisk 合并」这个方案**前提不成立**——原厂 boot 里没有 ramdisk 可合并。
- 黑屏的原因**不在 ramdisk 是否被加载**（它被加载了，adbd 都起来了），而在 **OF recovery 自身的启动/显示初始化**
  （可能方向：`init.recovery.*.rc` 是否执行到、`msm_drm.ko`/panel 驱动加载顺序、sepolicy 未完整加载）。
  系统内无 root、`pstore` 与块设备均不可读，**无法从系统侧取证**，只能真机实测。

### 9.7 修正：上次黑屏是从 `boot_a` 启动的，**不是** recovery 分区

机主确认：`recovery_a` **仍是原厂镜像**。因此 9.2 那次「进入 recovery 模式（USB `D001`）」，
**用的是 `boot_a` 里的 OF 镜像**（recovery 分区完全没参与）。

推论（进一步收紧）：

1. ABL 在 recovery 模式下**会加载 boot 分区的 ramdisk** —— 我们把 OF 镜像放进 boot 后，
   它被正确加载并执行到了 `adbd` 起来（`adb get-state=recovery`）；
2. 这条路**与 recovery 分区白名单无关**，所以「塞 boot」确实是有效的绕过手段；
3. 黑屏只可能是 **OF recovery 自身**问题（显示初始化 / 第二阶段 init / sepolicy），
   不是「ABL 不认这个镜像」。

本地指纹对照（用于将来确认设备上 recovery 分区到底是哪版）：

| 文件 | 大小 | sha256 前 20 |
|---|---|---|
| `cmp\stock-recovery.img`（= ZUI16 原厂） | 100663296 | `EA89E4C32E490B5EACD6` |
| ZUI16 包 `image\recovery.img` | 100663296 | `EA89E4C32E490B5EACD6`（同 ZUI16 上表一致） |
| ZUI15 包 `images\recovery.img` | 104857600 | `D3646E0F3154E249A73D` |
| `cmp\of-stocktpl.img` | 100663296 | `0D9D5FFE23F2F7D6157E` |
| `OrangeFox-stockhdr.img` | 104857600 | `81FBAB23FB721A15D84E` |
| `OrangeFox-new.img` | 104857600 | `30EF74EB1D19BD1C61DE` |

### 9.5 提醒：900E 状态
刷回原厂 boot 后重启，设备一度停在 **`Qualcomm HS-USB Diagnostics 900E`（USB `VID_05C6&PID_900E`，COM6）**：
此状态下 `adb` / `fastboot` 都不可用，需要用按键（长按电源强制断电后按音量键）重新进 fastboot 或 9008。
本次由机主手动操作后回到系统，**数据全程未受影响**。

---

## 十、进 OrangeFox 后的自动验证清单（`verify_in_recovery.ps1`）

目标里「验证触摸 / FBE / 动态分区」不再是纯人工打勾，而是有脚本出报告：

```powershell
powershell -ExecutionPolicy Bypass -File .\verify_in_recovery.ps1
# 可选：-NoFastbootD 跳过 fastbootd 测试（该测试会重启出 recovery）
```

覆盖 15 项，逐项 PASS/WARN/FAIL/SKIP，结果落到 `logs\verify_recovery_*.txt`：

| # | 检查 | 判据 |
|---|---|---|
| 1 | device online | `adb devices` 出现 `recovery`/`device` |
| 2 | OrangeFox markers | `ro.twrp.version` / `ro.orangefox.version` / `/etc/fox.cfg` / `/FFiles` |
| 3-4 | kernel up / cmdline clean | `/proc/version` 有 Linux；cmdline 不含 `buildvariant=eng` |
| 5-6 | touch driver + dmesg | `/proc/bus/input/devices`、`nvt*.ko`、dmesg 里 nvt/novatek |
| 7-8 | dynamic partitions / system·vendor 挂载 | `/dev/block/mapper`、`dm-*`、`/proc/mounts` |
| 9-11 | data 挂载 / 可读 / FBE 日志 | `/data` 挂载行、`ls /data`、dmesg 里 fbe·fscrypt·keymaster |
| 12 | MTP/USB | `sys.usb.config`、android_usb state |
| 13-14 | mount 表 / by-name 分区 | 挂载条目数、`by-name/super` |
| 15 | fastbootd | `fastboot getvar is-userspace` = yes |

**设计注意**：脚本在**设备侧只发不带 `|` `>` 引号的单条命令**，所有过滤/聚合都在 PC 端做。
原因是实测发现 Windows 侧向 adb 传参时，管道和重定向会被本机 shell 吃掉
（例如 `cat /proc/bus/input/devices | grep -i nvt` 会被拆坏），这会让验证结果不可信。

**离线实测**（用假设备桩）：

```
假 OrangeFox  : PASS 15 / FAIL 0 / WARN 0 / SKIP 0
假原厂 recovery: 正确识别为 stock（OrangeFox markers = WARN，其余多为 WARN）
无设备        : FAIL(device online) 并提示先刷 OF
```

> 顺带修掉两个自家脚本的小毛病：结果数组为空时 `.Count` 返回空（已用 `@()` 包住）；
> `by-name` 检查在拿不到条目时改为同时看 `by-name/super` 软链，判据更稳。
