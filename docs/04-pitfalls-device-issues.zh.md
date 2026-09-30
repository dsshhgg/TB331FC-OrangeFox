# TB331FC OrangeFox 全程复盘：工作、深坑、机型通病

> 设备：联想小新 Pad 2024（TB331FC）  
> 平台：SM6225 / khaje + Adreno 610  
> 系统：ZUI 16.0.544（曾试 ZUI 15.1.105）  
> 目标：OrangeFox Recovery（用户要求：**以后不要用 TWRP**）

---

## 一、我做过的所有事情

### 1. 工程侧（编译 / CI / 仓库）
| 事项 | 结果 |
|---|---|
| 解压迁移包，改设备树 `fox_TB331FC` / BoardConfig / vendorsetup | ✅ |
| GitHub `fox-12.1` 分支、`build-fox.yml` | ✅ CI 能出包 |
| 打包原厂 GKI 内核 46.8MB 进 recovery | ✅ |
| 清空 cmdline（去掉 `buildvariant=eng`） | ✅ |
| 镜像头对齐原厂（96MB、kernel 可 0/46MB、osv=0、sig=0） | ✅ |
| 减肥开关、A/B 变量、fox.cfg | ✅ |
| 产出 `OrangeFox-R12.0-Unofficial-TB331FC.img` + vbmeta | ✅ |
| 社区报告 + 移植总结文档 | ✅ |

### 2. 刷写 / 实验侧
| 实验 | 结论 |
|---|---|
| 多轮 OF / 官方 TWRP / 原厂 recovery 刷写 | 原厂 rec 可进，第三方不可 |
| AOSP testkey 签名 vbmeta | 公钥与原厂**一致**，仍拦 |
| flags=3 / flags=0 + 全哈希描述符 | 仍拦 |
| 有效内容改 1 bit + 匹配哈希 | ❌ |
| padding 改 1 字节 | ✅ 可进 |
| 槽位 unbootable 标记 | 是失败**结果**不是原因 |
| ZUI15 boot 链 + 64KB vbmeta | 与 ZUI16 abl 不兼容/混刷 |
| 9008 写 abl LUN4 | 失败 |
| 柚坛工具箱 9008/基本刷入 | 识别 fastboot，GUI 焦点不稳 |
| 最后：ZUI15 boot/recovery/vbmeta 手刷救机 | 已执行 |

### 3. 文件与路径（只读原厂包未改）
- 原厂：`E:\类\刷机\联想\TB331FC\`（ZUI16、9008 工具、APatch）
- ZUI15 售后包：`E:\rom\240412_...ZUI_15.1.105_...` / `E:\rom\release\ZUI15-extract`
- OF/avb/报告：`E:\rom\release\`

---

## 二、踩过的坑 / 陷阱（按类别）

### A. 构建与 CI
1. **lunch 名**：OrangeFox 用 `fox_TB331FC-eng`（`twrp_` 也能编但 OF 变量可能不全）。
2. **`FOX_VERSION` 已废弃** → `FOX_MAINTAINER_PATCH_VERSION`，否则 ckati 直接失败。
3. **`add_lunch_combo` 在新 AOSP 不存在**，写在 vendorsetup 里会弄挂 `lunch`。
4. **GitHub Actions `bash -e`** 会在 `source envsetup` / lunch 失败时秒退且无日志 → 用 `set +e` + tee。
5. **`buildvariant=eng` 被写进 recovery cmdline** → 联想 BL 对非空 cmdline 直接掉 fastboot（必须清零）。
6. **ccache 目录只读**：runner 上 `/home/runner/.ccache` 不能写 → 直接关 ccache。
7. **46MB 内核不能走 Contents API** → 放 Release `stock-kernel.gz`，CI 再下载解压。
8. **OS_VERSION 99 / 2099-12** 会编出怪异 os_version（3321890364）→ 原厂是 **0**。
9. **镜像自带 sig_size=4096** vs 原厂 **0** → 不对齐可能被拒。

### B. 网络 / 工具
10. **Watt Toolkit 代理**：`git clone` 卡死，GitHub 直连也慢。
11. **下载 100MB 镜像**：官方源 ~30KB/s；**`https://gh-proxy.com/` 约 8MB/s** 才可用。
12. **GitHub raw/jsdelivr 404**：LineageOS 分支名是 `lineage-23.2` 不是 `lineage-21`。
13. **avbtool 要 openssl**：用 Git 自带 `C:\Program Files\Git\usr\bin`，并注意 **`E:` 盘符冒号会拆坏 `--chain_partition` 参数**（用相对路径）。
14. **PowerShell**：`$(DEVICE_PATH)` 被当子表达式；CRLF/编码导致 Edit/Replace 失败 → 整文件重写 + UTF-8。

### C. 刷写 / 引导（最大的坑）
15. **`fastboot reboot recovery` 在本机不可靠**：第三方 rec 一律回 fastboot；原厂要用 **`adb reboot recovery`** 或实体键。
16. **`fastboot boot` 不支持**（`unknown command`），不能临时试镜像。
17. **`fastboot fetch` 不支持**，不能读回分区校验。
18. **`slot-unbootable:a:yes` 是启动失败结果**，不是根因；清标记没用。
19. **64KB padding vbmeta 在 ZUI16 会导致系统都启不来**；原厂 vbmeta 文件 **8KB**（分区仍 64KB）。
20. **AVB recovery 哈希只覆盖 ~14.5MB 有效内容**，padding 可改、内容不能改。
21. **testkey 与原厂公钥相同（漏洞存在）仍进不去 rec** → 说明还有 **ABL recovery 白名单**。
22. **1-bit 有效内容改动 + 正确 testkey vbmeta = 仍拒** → 伪装/魔改原厂 recovery **此路不通**。
23. **abl / xbl = Critical Partition**，fastboot：`Flashing is not allowed` → **只能 9008**。
24. **9008 `fh_loader` 写 LUN4（abl）失败**：`Failed to open SDCC ... lun:4`；需 GUI（柚坛/MultiPortQLoader）或正确 firehose XML。
25. **混刷 ZUI15 boot + ZUI16 abl** 风险高，容易「开不了机」。
26. **售后包 `flash.bat` 带 `-s %1`**，空序列号会挂死，要手敲 fastboot 命令。
27. **原厂目录 `E:\类\刷机\联想\TB331FC` 是原厂包**，只读使用，不要往里拷产物。

### D. 产品/流程
28. **曾用 TWRP 对照**，用户后来明确：**以后禁止 TWRP**（已写入项目记忆）。
29. **GitHub 推送**：大文件走 Release 资产，不要走 git/Contents API。
30. **脚本用完要清理**（临时 py/log/半截下载），避免目录污染。

---

## 三、这台机子的问题（TB331FC 通病）

| 问题 | 说明 |
|---|---|
| **ABL recovery 白名单** | 第三方 rec（TWRP/OF）无论 AVB 是否合法都会被跳过或掉 fastboot |
| **Critical Partition** | abl/xbl 不能 fastboot 刷，救砖/降级必须 9008 |
| **A/B + 独立 recovery** | 写错 A/B 变量会刷到 boot；槽位失败会标 unbootable |
| **GKI 空内核 recovery** | 出厂 recovery 无 kernel，靠 boot 带内核；打包内核非必须但 cmdline 必须空 |
| **vbmeta 尺寸/Flags 随版本变** | ZUI15：64KB、Flags=2；ZUI16：8KB、Flags=0 |
| **bootloader 版本号为空** | `version-bootloader` 无字符串，无法判断 abl 是否更换 |
| **`fastboot boot` / `fetch` 缺失** | 不能临时启动/读回，排错手段少 |
| **进 recovery 入口怪** | `fastboot reboot recovery` 常失败，靠 adb/实体键 |
| **9008 是生命线** | 官方售后包 + MultiPortQLoader；命令行 firehose 对 LUN 敏感 |
| **解锁后仍 secure:yes** | 正常，不等于放开第三方 rec |

---

## 四、结论（可写进社区）

1. **OF 源码/CI 已通**，镜像规格可对齐原厂。  
2. **拦在 ABL 白名单**，不是编译问题、不是 AVB/testkey 问题。  
3. **不能伪装成原厂**（有效内容锁定）。  
4. **唯一 OF 可能性**：9008 换上无白名单的旧 **abl**（ZUI15），再刷 OF。  
5. Root 更稳的路：**APatch / KernelSU 刷 boot**（不依赖 recovery）。  
6. 救砖：**ZUI15/ZUI16 售后包 9008 线刷**。

---

## 五、推荐命令速查

```bash
# 编 OrangeFox
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
lunch fox_TB331FC-eng
mka adbd recoveryimage

# 刷 OF（当前 ZUI16 abl 下预期被拦）
fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
fastboot flash recovery_a OrangeFox-*.img
fastboot --set-active=a
adb reboot recovery   # 或实体键，别只信 fastboot reboot recovery
```

---

*复盘整理 · 2026-09-30 · 实测数据来自本机 TB331FC*