# TB331FC OrangeFox 移植验证清单

刷入设备后逐项打勾。全部通过即移植成功。

> **自动化**：`E:\rom\release\TB331FC-abl-downgrade\verify_in_recovery.ps1`
> 已把下面「三、核心功能」的大部分项做成可执行检查（进 OF 后跑，自动出 PASS/WARN/FAIL 报告）。
> 本文件保留人工确认项（滑屏手感、显示效果、MTP 实际传文件、刷 ZIP、备份恢复）。

## 一、编译产物检查（刷机前）

| 验证项 | 方法 | 状态 |
|---|---|---|
| 产物存在 | `out/target/product/TB331FC/` 下有 `OrangeFox-R12.1-*.zip` 与 `recovery.img` | ☐ |
| 镜像结构 | 解包 `recovery.img`：头部 v4、`kernel_size`（本次为原厂内核 46819840）、cmdline 空、ramdisk 为 legacy LZ4 且含 `FFiles/`、`etc/fox.cfg`、`twres/` | ☐ |

## 二、刷入与启动

| 验证项 | 方法 | 状态 |
|---|---|---|
| vbmeta | 先刷 `vbmeta_a` / `vbmeta_b`（AVB 禁用）；原厂 ZUI16 vbmeta 为 8192 B | ☐ |
| recovery | 刷 `recovery_a` / `recovery_b` | ☐ |
| 启动 | **`adb reboot recovery`** 或实体键（音量上+电源）进入 OrangeFox 主界面 | ☐ |

> ⚠️ 本机实测纠正两条：
> 1. **不支持 `fastboot boot`**（unknown command）→ 不能「只启动不刷入」；
> 2. **`fastboot reboot recovery` 对第三方 rec 不可靠** → 用 `adb reboot recovery` 或实体键。

## 三、核心功能

| 验证项 | 方法 | 状态 |
|---|---|---|
| 触摸 | 滑动/点击菜单（Novatek NVT36523 SPI）；也可看 dmesg 里 `nvt36523` | ☐ |
| 显示 | 分辨率、DPI 正常，无花屏 | ☐ |
| FBE 解密 | 设 PIN 后进 OF 输密码，`/data` 可读；终端里 `fox decrypt <PIN>`（OrangeFox 命令名，非 `twrp`） | ☐ |
| 动态分区 | Mount 菜单挂载/卸载 system、vendor、product；`/proc/mounts` 里出现 `/dev/block/mapper/*` 或 `/dev/block/dm-*` | ☐ |
| FastbootD | Advanced → Enter fastboot；`fastboot getvar is-userspace` 返回 `yes` | ☐ |
| MTP | 电脑可识别设备并访问内部存储 | ☐ |
| 刷写 | 成功刷入 Magisk 或内核 ZIP 且系统能启动 | ☐ |
| 备份/恢复 | Nandroid 备份 boot/data/system 后再恢复 | ☐ |

## 四、日志排错（异常时）

```bash
adb logcat > recovery_log.txt
adb shell dmesg > recovery_dmesg.txt
```

重点关键字：
- `touchscreen firmware not found` — 触摸固件
- `FBE failed to decrypt` — 解密
- `cannot mount /vendor` / `init: cannot mount` — 挂载

## 五、刷入顺序（务必）

```bash
fastboot flash vbmeta_a vbmeta.img
fastboot flash vbmeta_b vbmeta.img
fastboot flash recovery_a recovery.img
fastboot flash recovery_b recovery.img
adb reboot recovery        # 不是 fastboot reboot recovery
```
## 六、构建命令（编译时用）

```bash
cd ~/android/fox_12.1
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export LC_ALL=C
lunch fox_TB331FC-eng    # OrangeFox 用 fox_ 前缀，不是 twrp_
mka adbd recoveryimage
```

git 代理卡顿时：

```bash
git config --global --unset http.proxy
git config --global --unset https.proxy
# 同步源码务必浅克隆
git clone --depth=1 ...
```

刷入后若卡 Logo / 黑屏回退 fastboot：不要反复刷；先确认 vbmeta 已刷、abl 版本是否已被白名单拦，
再考虑 9008 换 abl（见 `E:\rom\release\TB331FC-abl-downgrade\README.md`）。
