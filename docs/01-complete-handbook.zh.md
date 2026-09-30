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
| 设备启动 OF | ❌ **ABL recovery 白名单**拦截 |
| AOSP testkey | ✅ 与原厂公钥相同，仍不够 |
| 伪装原厂 | ❌ 有效内容锁定 |
| Root 备选 | APatch / KernelSU 刷 boot |
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
23. fh_loader LUN4 失败  
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

*TB331FC OrangeFox 完整手册 · 2026-09-30*
