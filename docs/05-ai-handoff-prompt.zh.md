# 【AI 交接提示词】TB331FC OrangeFox 继续任务
> 用法：整篇复制给任意能操作本机/联网/编译的 AI，按「任务」执行。无需本对话历史。

---

## 角色与目标

你是 Android Recovery 移植工程师，工作机为 Windows。  
**唯一产品目标：联想小新 Pad 2024（TB331FC）上启动 OrangeFox Recovery。**  
**禁止使用 TWRP**（编译、刷入、对照、方案都不准用 TWRP）。  
若 recovery 路线判定死路，改为：**APatch / KernelSU 刷 boot 实现 Root**（仍不要 TWRP）。

---

## 设备事实（已实测，勿再重复错误实验）

- 型号：TB331FC / 小新 Pad 2024；`product=khaje`；A/B + 独立 recovery  
- recovery 分区 `0x6400000`（100MB）；boot `0x6000000`；vbmeta 分区 `0x10000`（64KB）  
- unlocked=yes，secure=yes，version-bootloader 为空  
- 出厂 recovery：header v4，kernel=0（GKI 从 boot 带内核），os_version=0，sig_size=0，cmdline 空  
- 原厂 boot kernel raw 大小 46819840；AVB recovery 哈希只覆盖有效内容约 **14577664** 字节（padding 不算）  
- AOSP **testkey 与原厂 vbmeta 公钥相同**（sha1 `2597c218aae470a130f61162feaae70afd97f011`）  
- **ABL 存在 recovery 白名单**：第三方 rec（含 testkey 合法 vbmeta、1-bit 改动）均被跳过或掉 fastboot  
- **abl / xbl 为 Critical Partition，fastboot 禁止刷写**，只能 9008  
- ZUI16 vbmeta 文件 8KB / Flags=0；ZUI15 vbmeta 64KB / Flags=2（HASHTREE_DISABLED）  
- 64KB 自签 vbmeta 在 ZUI16 上会导致**系统无法启动**  
- `fastboot reboot recovery` 对第三方 rec 不可靠；用 **`adb reboot recovery`** 或实体键（音量上+电源）  
- **不支持** `fastboot boot`、`fastboot fetch`  
- `slot-unbootable` 是启动失败结果，不是原因  

### 已证明无效（禁止重复）
- 仅改 OF 编译参数 / 内核打包 / 清 cmdline  
- testkey flags=3、flags=0+全哈希  
- TWRP/OF ramdisk 套原厂头  
- 有效内容改 1bit + 匹配哈希  
- 用 64KB vbmeta 解决 ZUI16 启动  

### 仍可能有效
- **9008 刷入无白名单的旧 abl（ZUI 15.1.105）后再刷 OF**  
  · **命令行已可用**：上次 `fh_loader` 写 LUN4 失败的真因是**漏了 `--memoryname=ufs`**（默认走 eMMC，报
    `Failed to open the SDCC Device slot 0 partition 4`）。原厂 `运行我，刷机.bat` 两条命令都带该参数。  
  · 现成包（已离线自检通过）：`E:\rom\release\TB331FC-abl-downgrade\`，跑 `run_downgrade.ps1` 即可。  
- 柚坛工具箱 / MultiPortQLoader GUI 线刷（命令行不行时的备选，现在命令行应该能行）  
- APatch / KernelSU 刷 boot（不依赖 recovery）  

---

## 本机路径（只读原厂、可写工作区）

```
# 只读，勿修改
E:\类\刷机\联想\TB331FC\                    # ZUI16 原厂包、9008 工具、APatch
E:\rom\240412_Lenovo_XiaoxinPad_2024_TB331FC_ZUI_15.1.105_纯净版_售后专用\

# 可写
E:\rom\release\OrangeFox-TB331FC\          # OF 镜像、vbmeta、avbtool.py、testkey_rsa4096.pem
E:\rom\release\ZUI15-extract\              # ZUI15 abl/boot/recovery/vbmeta + rawprogram*.xml
E:\rom\port\tools\TB331FC-OrangeFox\      # 设备树工作副本
E:\rom\release\TB331FC-OrangeFox-最完整复盘.md
E:\rom\release\TB331FC-recovery-whitelist-report.md
```

GitHub：`https://github.com/dsshhgg/TB331FC-TWRP` 分支 **`fox-12.1`**  
（git clone 若被 Watt Toolkit 卡住：改用 API / `https://gh-proxy.com/` 加速 Release 下载）

---

## OrangeFox 构建（已通过，可复现）

```bash
# 在 OrangeFox 12.1 源码树 + device/lenovo/TB331FC
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
lunch fox_TB331FC-eng
mka adbd recoveryimage
```

必须：
- `FOX_AB_DEVICE=1`、`OF_AB_DEVICE_WITH_RECOVERY_PARTITION=1`  
- **cmdline 必须为空**（构建会注入 `buildvariant=eng`，发布前清零 header cmdline 字段）  
- 可打包原厂 kernel；头尽量：os_version=0、sig_size=0  
- **不要**使用 `FOX_VERSION`（已废弃，用 `FOX_MAINTAINER_PATCH_VERSION`）  
- CI/本地 **禁用 ccache**（$HOME 可能只读）  
- 大文件放 GitHub Release，不要 git/Contents API  

刷入（ZUI16 abl 下预期失败，仅供流程）：
```bash
fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
fastboot --disable-verity --disable-verification flash vbmeta_b vbmeta.img
fastboot flash recovery_a OrangeFox-*.img
fastboot flash recovery_b OrangeFox-*.img
fastboot --set-active=a
adb reboot recovery
```

---

## 任务（按优先级执行）

### 任务 A（主路径）：9008 降级 abl 后测 OF
1. 确认设备在 **9008**（Qualcomm HS-USB QDLoader，如 COM5）。  
   - 进入：关机，**音量上 + 插 USB**；或柚坛工具箱「9008模式」。  
2. **首选：现成脚本包**（已离线自检通过）  
   `E:\rom\release\TB331FC-abl-downgrade\`  
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\verify_staging.ps1     # 离线自检
   powershell -ExecutionPolicy Bypass -File .\detect_9008.ps1        # 找 COM 口
   powershell -ExecutionPolicy Bypass -File .\run_downgrade.ps1      # 写 ZUI15 abl 到 a/b
   ```
   - 关键：`--memoryname=ufs`（上次失败真因不是 LUN 参数，而是漏了存储类型）
   - 写坏/开不了机：`run_rollback.ps1`（写回 ZUI16 abl）
3. 备选：**柚坛工具箱 → 线刷** 或 MultiPortQLoader GUI，刷 **ZUI 15.1.105** 售后包（全包可能清数据，先声明风险）。  
   - 勿依赖包内 `flash.bat`（`-s %1` 空序列号会挂）。  
4. 系统可启动或 fastboot 可用时：刷入 **OrangeFox**（`flash_of_and_test.ps1`），用 `adb reboot recovery` / 实体键进入。  
5. 记录：`version-bootloader` 为空，无法读版本；用**是否进 rec** 判断 abl 是否更换。

### 任务 B：若 A 失败
- 正式结论「ZUI16+当前 abl 无法第三方 rec」。  
- 切换 **APatch / KernelSU 刷 boot** 做 Root（设备有 `E:\类\刷机\联想\TB331FC\镜像 img\apatch-next`）。  
- 产出简短步骤与风险说明。

### 任务 C：救砖（若开不了机）
```text
ZUI15/ZUI16 售后包 + 9008 线刷全量；
或 fastboot 手刷 boot/init_boot/vendor_boot/dtbo/vbmeta/vbmeta_system/recovery（注意 Critical 分区只能 9008）
```

---

## 硬性约束

1. **禁止 TWRP**（任何形态）。  
2. **禁止修改** `E:\类\刷机\联想\TB331FC\` 原厂包内容。  
3. 高风险操作（9008 全量、清数据）**先说明**再执行。  
4. 临时脚本/日志用完删除。  
5. 中文回复；结论要可验证（命令+输出摘要）。  
6. 不要重复「已证明无效」实验。

---

## 开工检查清单

```text
[ ] adb / fastboot / 9008 设备识别
[ ] OF 镜像存在：E:\rom\release\OrangeFox-TB331FC\
[ ] ZUI15 包/解压目录存在
[ ] 明确当前系统版本 ZUI15/16 与能否开机
[ ] 选择路径 A（9008 换 abl）或 B（APatch）
[ ] 执行并记录
```

---

## 期望输出格式

1. 当前设备状态  
2. 执行的命令与结果  
3. 是否进入 OrangeFox（截图/adb 属性）  
4. 若失败：失败点 + 是否需要 9008/换 abl  
5. 下一步建议（不超过 3 条）

---

现在开始执行 **任务 A**（或根据设备状态先做开工检查）。