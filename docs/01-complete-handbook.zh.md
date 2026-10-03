# TB331FC OrangeFox 完整手册（总集）
**联想小新 Pad 2024 · TB331FC · SM6225/khaje · ZUI 15/16 · 禁用 TWRP**

> 本文合并：移植总结、白名单报告、踩坑复盘、最完整复盘、AI 交接提示词、验证清单。  
> 可单独保存，也可整篇导入其他 AI 继续执行。

---

# 第一部分 · 项目结论（TL;DR）

| 项 | 结论 |
|---|---|
| 目标 | 启动 **OrangeFox Recovery** |
| 编译/CI/设备树 | ✅ 已完成（fox-12.1 / build-fox.yml） |
| 设备启动 OF | ❌ **不可行**：ABL 有一道独立的「联想原厂 recovery 签名」白名单（见第十六部分决定性实验） |
| 白名单认什么 | ✅ 已实测：认**联想原厂签名**，与 ZUI 版本无关（ZUI15 原厂 recovery 能进，我们的 OF 不能） |
| AOSP testkey | ⚠️ 只解决 AVB 层：重签 vbmeta（含 boot 哈希）后系统能正常启动，但过不了 ABL 的签名门槛 |
| 换 abl / 塞 boot 分区 | ❌ 均已实测排除 |
| Root 备选 | ✅ **APatch / KernelSU 刷 boot**（不依赖 recovery，唯一可行方向） |
| 救砖 | ZUI15/ZUI16 售后包 9008 |
| 规则 | **以后不要使用 TWRP** |

---

# 第二部分 · 设备事实

| 项 | 值 |
|---|---|
| 机型 | TB331FC / 小新 Pad 2024 |
| product | khaje |
| 分区 | A/B + 独立 recovery |
| recovery | 0x6400000 = 100MB |
| boot | 0x6000000 = 96MB |
| vbmeta 分区 | 0x10000 = 64KB |
| vbmeta 文件 | ZUI16=8KB Flags=0；ZUI15=64KB Flags=2 |
| abl / xbl | 0x100000 / 0x380000，**Critical** |
| unlocked / secure | yes / yes |
| version-bootloader | 空 |
| testkey sha1 | 2597c218aae470a130f61162feaae70afd97f011 |
| 原厂 boot kernel | 46819840 raw，cmdline 空 |
| 存储类型 | **UFS**（9008 写分区必须 `--memoryname=ufs`，否则 LUN4 打不开） |
| LUN4 扇区 | abl_a 56838 / abl_b 206574（4096B 扇区） |
| AVB recovery 哈希范围 | 14577664 有效字节（不含 padding） |
| 出厂 recovery 头 | v4，kernel=0，os_version=0，sig_size=0 |

**不支持**：`fastboot boot`、`fastboot fetch`  
**入口**：`adb reboot recovery` 或实体键；`fastboot reboot recovery` 对第三方 rec 不可靠

---

# 第三部分 · 路径索引

```
只读：
  E:\类\刷机\联想\TB331FC\
  E:\rom\240412_Lenovo_XiaoxinPad_2024_TB331FC_ZUI_15.1.105_纯净版_售后专用\

可写：
  E:\rom\release\OrangeFox-TB331FC\     # OF 镜像、vbmeta、avbtool、testkey
  E:\rom\release\ZUI15-extract\         # ZUI15 关键镜像
  E:\rom\port\tools\TB331FC-OrangeFox\ # 设备树
  本手册：E:\rom\release\TB331FC-OrangeFox-完整手册.md

GitHub：dsshhgg/TB331FC-TWRP 分支 fox-12.1
下载加速：https://gh-proxy.com/
```

**原厂目录禁止写入。**

---

# 第四部分 · 工程交付（已做）

1. 设备树：`fox_TB331FC.mk`、`fox/fox.cfg`、BoardConfig A/B、vendorsetup、AndroidProducts  
2. CI：`build-fox.yml`（lunch `fox_TB331FC-eng`，拉内核，清 cmdline，发 Release）  
3. 镜像：原厂内核 46.8MB + OF ramdisk；可对齐 96MB/osv=0/sig=0/空 cmdline  
4. 文档：本手册 + 白名单报告 + 验证清单  
5. 禁令：TWRP 不再使用

---

# 第五部分 · 实验矩阵

| # | vbmeta | recovery | 结果 |
|---|---|---|---|
| 1 | 原厂 | 原厂 | ✅ 能进 rec |
| 2 | 原厂+disable | OF/TWRP | ⏭ 跳 rec 进系统 |
| 3 | testkey flags=3 | OF | ❌ 回 fastboot |
| 4 | testkey flags=0 全哈希 | OF | ❌ |
| 5 | 64KB vbmeta | 任意 | ❌ 系统起不来 |
| 6 | 原厂头+TWRP/OF ramdisk | 第三方 | ❌ |
| 7 | 匹配 testkey 哈希 | 原厂 rec 改 1bit | ❌ |
| 8 | 原厂 | padding 改 1B | ✅ 仍进 |
| 9 | 实体键 | OF | ❌ |
| 10 | ZUI15 boot + ZUI16 abl | OF | ❌ / 易不开机 |

**结论**：ABL 白名单锁定 recovery **有效内容**；AVB/testkey 可伪造但不够。

---

# 第六部分 · 踩坑全表

## 构建
1. lunch 必须 `fox_TB331FC-eng`  
2. 禁用 `FOX_VERSION`  
3. 勿用 `add_lunch_combo`  
4. CI 用 `set +e` 防 bash -e 秒退  
5. **清掉 cmdline `buildvariant=eng`**  
6. 禁用 ccache（只读 $HOME）  
7. 内核 46MB → Release 资产  
8. os_version=0、sig_size=0 对齐原厂  

## 网络工具
9. Watt Toolkit 卡 git  
10. 大文件用 gh-proxy.com  
11. LineageOS avbtool 分支 lineage-23.2  
12. avbtool 要 openssl；`E:` 冒号拆坏 chain 参数 → 相对路径  
13. PowerShell `$(…)`、编码/CRLF → UTF-8 整文件重写  
14. 脚本用完清理  

## 刷写
15. `fastboot reboot recovery` 不可靠  
16. 无 `fastboot boot` / `fetch`  
17. unbootable 是结果不是原因  
18. 64KB vbmeta 在 ZUI16 弄挂系统  
19. 哈希只盖 14.5MB 有效区  
20. testkey 相同仍失败  
21. 1-bit 也失败  
22. abl/xbl 只能 9008  
23. fh_loader LUN4 失败 —— **真因是漏 `--memoryname=ufs`**（默认 eMMC），非 LUN 参数错  
24. ZUI15/16 混刷危险  
25. flash.bat `-s %1` 会挂  
26. 勿写原厂包目录  

---

# 第七部分 · 机型通病

- ABL recovery 白名单  
- Critical Partition（abl/xbl）  
- A/B + 独立 rec  
- GKI 空内核 + 空 cmdline  
- vbmeta 尺寸/Flags 随 ZUI 版本变  
- 无 bootloader 版本串  
- 缺 fastboot boot/fetch  
- recovery 入口怪  
- 9008 是写 abl 唯一通道  

---

# 第八部分 · 构建与刷入命令

```bash
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
lunch fox_TB331FC-eng
mka adbd recoveryimage

fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
fastboot --disable-verity --disable-verification flash vbmeta_b vbmeta.img
fastboot flash recovery_a OrangeFox-*.img
fastboot flash recovery_b OrangeFox-*.img
fastboot --set-active=a
adb reboot recovery
```

救机（boot 链示例，Critical 仍需 9008）：
```bash
fastboot flash boot_a/b init_boot_a/b vendor_boot_a/b dtbo_a/b
fastboot flash vbmeta_a/b vbmeta_system_a/b recovery_a/b
fastboot --set-active=a && fastboot reboot
```

---

# 第九部分 · 验证清单（刷入后）

| 项 | 方法 | 结果 |
|---|---|---|
| 产物 | OrangeFox-*.img / vbmeta | ☐ |
| 启动 | adb reboot recovery / 实体键进 OF | ☐ |
| 触摸 | NVT36523 滑动 | ☐ |
| 显示 | 分辨率/DPI | ☐ |
| FBE | PIN 解密 /data | ☐ |
| 动态分区 | Mount system/vendor | ☐ |
| FastbootD | `fastboot getvar is-userspace` | ☐ |
| MTP | 电脑识别 | ☐ |
| 刷写 | Magisk/内核 ZIP | ☐ |
| 备份 | Nandroid | ☐ |

排错关键字：`touchscreen firmware not found`、`FBE failed`、`cannot mount`。

---

# 第十部分 · AI 交接提示词（可直接导入）

```text
【角色】Android Recovery 工程师，Windows 主机。
【目标】TB331FC 启动 OrangeFox；禁止 TWRP。失败则 APatch/KSU 刷 boot。
【已知】ABL recovery 白名单；testkey 与原厂相同仍拦；1-bit 改动拒；abl 仅 9008 可写；
       fastboot 无 boot/fetch；recovery 入口用 adb reboot recovery 或实体键；
       ZUI16 vbmeta 8KB、ZUI15 64KB Flags=2；64KB vbmeta 会弄挂 ZUI16 系统。
【路径】只读 E:\类\刷机\联想\TB331FC；可写 E:\rom\release\、E:\rom\port\tools\TB331FC-OrangeFox；
       ZUI15 包 E:\rom\240412_...；GitHub dsshhgg/TB331FC-TWRP@fox-12.1。
【构建】lunch fox_TB331FC-eng；mka adbd recoveryimage；清 cmdline；禁 ccache；禁 FOX_VERSION。
【任务A】9008 线刷 ZUI15 abl（柚坛/MultiPortQLoader）→ 刷 OF → adb reboot recovery。
【任务B】A 失败则 APatch/KSU 刷 boot。
【任务C】救砖：ZUI15/ZUI16 售后包 9008 全量。
【约束】不改原厂目录；高风险先声明；清理临时文件；中文输出命令+结果。
【开工】检查 adb/fastboot/9008、OF 镜像、ZUI15 包、系统版本 → 执行任务 A。
【输出】状态 / 命令结果 / 是否进 OF / 失败点 / 下一步≤3条。
```

---

# 第十一部分 · 关键数字速查

```
testkey sha1     = 2597c218aae470a130f61162feaae70afd97f011
kernel (stock)   = 46819840
recovery hash sz = 14577664
OF ramdisk       ≈ 23860970
recovery part    = 104857600
vbmeta part      = 65536
ZUI16 vbmeta     = 8192
ZUI15 vbmeta     = 65536 (flags=2)
abl payload      = 0x43000
```

---

# 第十二部分 · 最终建议

0. **先做**：跑 `E:\rom\release\TB331FC-abl-downgrade\verify_staging.ps1` 自检，
   设备一接上就按该目录 README 执行「9008 换 ZUI15 abl」（这次带 `--memoryname=ufs`）。
1. 要 **OF**：9008 换 ZUI15 **abl** 后再测。  
2. 要 **Root**：APatch/KernelSU 刷 boot。  
3. **开不了机**：9008 售后包救砖。  
4. 社区可发：白名单结论 + testkey 数据 + 1-bit 实验。  
5. 全程 **OrangeFox only**。

---


---

# 第十三部分 · 致谢与参考

- LineageOS android_external_avb@lineage-23.2（avbtool + testkey）
- gh-proxy.com（GitHub Release 加速）
- 柚坛工具箱、MultiPortQLoader、刷机匣（EDL 刷写工具）
- 酷安 TB331FC 社区、XDA 联想平板讨论帖
- 所有提供 ZUI 15 售后包、OF 迁移包、GSI 套件的社区贡献者

---

# 第十四部分 · abl 降级包（离线准备完成，未执行）

> 本轮新增。设备当时不便连接，故把「换 abl」所需的一切离线备好并自检通过。

## 14.1 上次 9008 写 abl 失败的真正原因（已定位）

历史命令：

```
tools\fh_loader.exe --port=\\.\COM5 --lun=4 --search_path=. --sendxml=abl_only.xml --noprompt --noreset --showpercentagecomplete
```

**漏了 `--memoryname=ufs`**。fh_loader 默认按 eMMC 通信，目标端回：

```
ERROR: Failed to open the SDCC Device slot 0 partition 4
ERROR: Failed to open device, type:eMMC, slot:0, lun:4 error:3
→ NAK → program FAILED
```

依据：原厂 ZUI16 包 `运行我，刷机.bat` 的两条 fh_loader 命令**都带 `--memoryname=ufs`**，
而这台是 **UFS** 存储。所以不是 LUN/扇区写错，是**存储类型没声明**。

## 14.2 交付物

`E:\rom\release\TB331FC-abl-downgrade\`

| 文件 | 作用 |
|---|---|
| `verify_staging.ps1` | 离线自检（只读，全部检查已通过） |
| `detect_9008.ps1` | 探测 9008 端口 |
| `run_downgrade.ps1` | 写 ZUI15 abl → `abl_a`/`abl_b`（UFS 模式，支持 `-WhatIf`） |
| `run_rollback.ps1` | 写回 ZUI16 abl（保命） |
| `flash_of_and_test.ps1` | 状态诊断 + 刷 OF + 测进入 |
| `images\abl_zui15.img` | 1048576 B，sha256 `349b5b40…` |
| `images\abl_zui16_padded.img` | 1048576 B，sha256 `22eaf506…`（原厂 274432 B 补零） |
| `images\write_abl_zui15.xml` / `write_abl_zui16.xml` | abl_a @LUN4 扇区 56838、abl_b @206574 |
| `tools\fh_loader.exe`、`QSaharaServer.exe` | EDL 工具 |

> 脚本刻意写成**纯 ASCII 输出**：本机 Windows PowerShell 5.1 按 GBK 读脚本文件，
> 中文会乱码并触发语法错误。中文说明集中在同目录 `README.md`。

## 14.3 本轮镜像独立核对

- `OrangeFox-new.img`：`ANDROID!` + **v4 头**，`kernel_size=46819840`（原厂内核已打包），
  `cmdline` 为空，ramdisk 为 **legacy LZ4**（magic `0x184C2102`）位于 `0x2ca8000`，
  解压 **48MB**，内含 `FFiles/`、`etc/fox.cfg`、`twres/`、`init.recovery.qcom.rc`、
  `vendor/lib/modules/1.1/nvt36523_spi.ko`（触摸驱动）→ **镜像本身完整**。
- vbmeta 核对：`avb\vbmeta_stock_backup.img` = 8192 B（ZUI16 原厂，alg=SHA256_RSA4096，flags=0）；
  ZUI15 `images\vbmeta.img` = 65536 B（同 alg，flags=0，尾部 56KB 零填充）；
  两者 aux 结构一致（6080），我们自签那版 aux=1088，与二者都不同。

## 14.4 下一步（设备接上后按序）

1. `verify_staging.ps1` → `detect_9008.ps1` → `run_downgrade.ps1`（9008 写 ZUI15 abl）
2. 长按电源+音量下退出 9008；能进系统就 `flash_of_and_test.ps1` 刷 OF 并 `adb reboot recovery`
3. 进不去 → 记录现象（fastboot / 黑屏 / 卡 Logo）；开不了机 → `run_rollback.ps1`
4. 顺手可做：`E:\LTBox-win_x86_64-v3.3.3` 已在机上（v3.1.4+ 的 testkey 漏洞检测），
   可作「引导层还有什么可利用点」的旁证

---

# 第十五部分 · boot 分区实验（2026-10-03）—— **结论：此路不通（已排除）**

> ⚠️ 本节最初写成「突破：boot 分区不受白名单限制」。**对照实验推翻了它**，以下为修正版。

## 15.1 手法

1. **重签 vbmeta**（AOSP testkey）：保留原厂 30 个描述符，把 `boot` 描述符换成我们镜像的哈希
   （沿用原厂 salt `0b8f7e2f…`），另出 flags=3 版。产物 `avb\vbmeta_bootfix_flags0.img` / `_flags3.img`。
2. **重建镜像** `OrangeFox-boot.img` = 原厂 boot 头 + 原厂 GKI 内核（46819840 B）+ OF ramdisk（23860970 B）。
3. `fastboot flash vbmeta_a` + `fastboot flash boot_a`（只动 A 槽）。

## 15.2 现象

`vbmeta_a`/`boot_a` 刷入 OKAY、`slot-unbootable:a` yes→no；重启后 `adb` 显示 `recovery`、
`adb get-state=recovery`、USB `VID_18D1&PID_D001`；`adb shell` 任意命令 → `Could not set SELinux
context` → SIGABRT；**屏幕是原厂 recovery 菜单**；刷回原厂 boot 后系统正常，数据无损。

## 15.3 决定性对照（推翻结论）

用**纯原厂状态**再进一次 recovery：

| 配置 | `adb get-state` | `adb shell` |
|---|---|---|
| 纯原厂（boot/vbmeta/recovery 全原厂） | `recovery` | **崩溃，报同一个 SELinux 错误** |
| boot_a 放 OF 镜像（flags0 / flags3） | `recovery` | 崩溃，完全一致 |

→ 行为**无差别**，因此：

1. `adb shell` 崩溃是**原厂 recovery 的固有行为**，不能作为 OF 故障判据；
2. `adb get-state=recovery` / USB `D001` 只是 recovery 模式标识，**不能证明 OF 在运行**；
3. 屏幕显示的是**原厂 recovery 菜单** → recovery 模式下走的是 **recovery 分区**，
   塞进 `boot_a` 的镜像看不出被执行；flags3 与 flags0 结果相同 → 与 AVB 校验无关。

## 15.4 修正后的结论

- **「塞 boot 分区绕过 recovery 白名单」在本机不成立**，白名单依旧是拦第三方 recovery 的那道墙；
- 此前「boot 分区不受白名单限制」的说法**作废**。

## 15.5 仍然有效的收获

1. **vbmeta 可用 AOSP testkey 重签**：boot 描述符换成我们镜像哈希后**系统仍正常启动**（`verifiedbootstate=orange`）；
2. **分区结构事实**：`boot_a` = 头(4096)+内核(46819840)+AVB 块(896)，**无 ramdisk**；
   `vendor_boot_a` 才是正常启动的 ramdisk（`VNDRBOOT` v4，11553237 B，legacy LZ4，
   cmdline `video=vfb:640x400,bpp=32,memsize=3072000 bootconfig`）；
   ZUI16 原厂 recovery 镜像 sha256 `EA89E4C3…`；
3. **诊断教训**：`adb get-state=recovery` 与 `adb shell` 崩溃**都不能**判断 OF 是否启动，只能看屏幕；
4. 可复用产物：`OrangeFox-boot.img`、两个重签 vbmeta、`flash_of_to_boot.ps1`。

## 15.6 坑：刷完重启落到 900E

刷回原厂 boot 后重启，设备一度停在 **`Qualcomm HS-USB Diagnostics 900E`**（`VID_05C6&PID_900E`，COM6），
`adb`/`fastboot` 均不可用，需按键（长按电源强制断电 → 音量键）重新进 fastboot / 9008。
本次由机主手动操作后回到系统，**数据全程未受影响**。

---

# 第十六部分 · 白名单决定性实验：认「联想签名」，不是认具体镜像（2026-10-03）

## 16.1 设计

前面已排除「换 abl」「塞 boot」，还剩最后一问：
**ABL 认的是 ZUI16 那一个具体 recovery 镜像，还是任何联想原厂签名的 recovery？**

做法：把 **ZUI15 的原厂 recovery**（同为联想签名，内容与原机那份差 **14256200 字节**）
通过 9008 EDL 写入 `recovery_a`（LUN4 扇区 99566，25600 扇区）。

## 16.2 结果

| 步骤 | 实测 |
|---|---|
| EDL 写入 | `All Finished Successfully`，fh_loader 退出码 0 |
| 读回验证 | 设备 `recovery_a` sha256 `d3646e0f3154e249a73de3a8b539089b…` = **ZUI15 recovery 完全一致** |
| `reboot recovery` | ✅ **进入 recovery，屏幕显示原厂中文 recovery 菜单** |

对照数据：ZUI16 原厂 recovery sha256 `ea89e4c32e490b5eacd6…`。

## 16.3 结论

> **ABL 的 recovery 白名单 = 联想原厂签名校验，与 ZUI 版本、与 AVB testkey 无关。**

三条证据：

| 组合 | 结果 |
|---|---|
| ZUI15 原厂 recovery（不同构建） | ✅ 能进 |
| 我们编译的 OF（testkey 签名 + 正确 boot 哈希 + 完整 ramdisk） | ❌ 被拦 |
| 原厂 recovery 改 1 bit | ❌ 被拦（历史实验） |

**「AOSP testkey」的边界**：原厂 vbmeta 公钥恰好就是 AOSP testkey，所以**重签 vbmeta 会被接受**
（实测：含我们 boot 哈希的 testkey vbmeta，系统照常启动）——但那只是 **AVB 层**。
ABL 另有一层**独立的原厂 recovery 签名**校验，**它不看 AVB**。

→ **OF 进不去的根本原因是没有联想签名**，不是编译错误、缺内核、cmdline、镜像头或 vbmeta 的问题。

## 16.4 后续路线判定

| 路线 | 判定 |
|---|---|
| 继续调 OF 编译参数 / 镜像头 / vbmeta | ❌ 无意义（门槛是签名） |
| 用原厂 recovery 模板塞 OF ramdisk | ❌ 已证伪（改 1 bit 即拒） |
| 伪造联想签名 | ❌ 无私钥、无碰撞 |
| **APatch / KernelSU 刷 boot 拿 Root** | ✅ 唯一可行方向 |
| 9008 换 abl / 全量刷 ZUI15 | ❌ 已实测，动摇不了这道门槛 |

## 16.5 实验后设备恢复（全部完成）

| 分区 | 恢复为 | 验证 |
|---|---|---|
| `abl_a/b` | ZUI16 | EDL 读回 sha256 `22eaf506…` 差 0 字节 |
| `recovery_a` | 原厂 ZUI16 | fastboot 刷回 OKAY |
| `boot_a` | 原厂 | fastboot 刷回 OKAY |
| `vbmeta_a` | 原厂签名 | fastboot 刷回 OKAY |

系统：`ZUI_16.0.544` / 槽位 `_a` / 正常启动，数据完好。
设备 recovery 完整备份：`E:\rom\release\TB331FC-abl-downgrade\images\recovery_a_device_backup.bin`（100MB）。

---

*TB331FC OrangeFox 完整手册 · 2026-09-30*
