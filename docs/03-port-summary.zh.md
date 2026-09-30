# TB331FC OrangeFox 移植全程总结

> 机型：联想小新 Pad 2024（TB331FC）  
> 平台：骁龙 685 / SM6225（khaje）+ Adreno 610  
> 系统：ZUI 16.0.544（Android 14）  
> 目标：启动 OrangeFox Recovery

---

## 1. 目标与结果

| 项 | 结果 |
|---|---|
| OrangeFox 编译 | ✅ 成功（含原厂内核、空 cmdline） |
| 设备树 / CI / Release | ✅ 已发布到 `dsshhgg/TB331FC-TWRP` 的 `fox-12.1` |
| 在设备上进入 OF | ❌ 被 ABL 拦截 |
| 根因 | ABL 存在独立于 AVB 的 **recovery 白名单** |

---

## 2. 已交付产物

### 2.1 代码与 CI
- 分支：`fox-12.1`（`main` 仍为 TWRP）
- 设备树：`device/lenovo/TB331FC/`（`fox_TB331FC.mk`、`fox/fox.cfg`、A/B 变量等）
- 工作流：`.github/workflows/build-fox.yml`
- 编译命令：`lunch fox_TB331FC-eng` + `mka adbd recoveryimage`

### 2.2 镜像要点（已实测对齐）
| 字段 | 值 |
|---|---|
| kernel | 46.8MB 原厂 GKI（与 boot.img 一致） |
| ramdisk | OF ~23.8MB |
| cmdline | 空（去掉 `buildvariant=eng`） |
| header v4 / os_version / sig | 与原厂一致（0 / 0 / 0） |
| 镜像尺寸 | 96MB 有效 + padding → 分区 100MB |

### 2.3 本地路径
| 内容 | 路径 |
|---|---|
| OF 产物 / vbmeta | `E:\rom\release\OrangeFox-TB331FC\` |
| 社区测试报告 | `E:\rom\release\TB331FC-recovery-whitelist-report.md` |
| ZUI 15.1.105 售后包解压 | `E:\rom\release\ZUI15-extract\` |
| avbtool + AOSP testkey | `E:\rom\release\OrangeFox-TB331FC\avb\` |
| 原厂 ZUI 16 包（只读） | `E:\类\刷机\联想\TB331FC\` |

---

## 3. 关键实测数据

### 3.1 AVB / testkey
- 原厂 vbmeta 公钥 sha1：`2597c218aae470a130f61162feaae70afd97f011`
- 与 AOSP `testkey_rsa4096.pem` **完全一致**
- 说明「测试密钥被信任」，但**仍无法启动第三方 recovery**

### 3.2 启动行为对照

| vbmeta | recovery | 结果 |
|---|---|---|
| 原厂原样 | 原厂 | ✅ 可进 recovery |
| 原厂 + disable-verity | OF / TWRP | ⏭ 跳过 rec，进系统 |
| testkey flags=3 + chain | OF（原厂模板头） | ❌ 回 fastboot |
| testkey flags=0 + 全哈希 | OF（recovery 哈希已重算） | ❌ 回 fastboot |
| 原厂 | TWRP ramdisk + 原厂头 | ⏭ / ❌ |
| 原厂 | 有效内容改 1 bit + 匹配 testkey vbmeta | ❌ |
| 原厂 | padding 改 1 字节 | ✅ 仍可进 |

### 3.3 入口方式
| 入口 | 第三方 rec |
|---|---|
| `fastboot reboot recovery` | ❌ 一律回 fastboot |
| `adb reboot recovery` | 原厂 ✅ / 第三方被跳过 |
| 实体键 音量上+电源 | ❌ |

### 3.4 分区与 getvar
- `unlocked: yes` / `secure: yes`
- recovery：`0x6400000`（100MB）
- vbmeta 分区：`0x10000`（64KB）；ZUI16 文件 8KB，ZUI15 文件 64KB
- `abl` / `xbl`：**Critical Partition，fastboot 禁止刷写**
- 无 `vbmeta_vendor`；`version-bootloader` 为空

---

## 4. 根因结论

**ABL 在 AVB 之外还有 recovery 白名单**（硬编码哈希或独立签名）：

1. AVB 侧已可伪造（testkey + 更新 recovery 哈希）仍失败  
2. 有效内容改 1 bit 即拒绝 → 锁定约 14.5MB 有效区  
3. padding 可改 → 不是整分区哈希  
4. 三条入口均无效 → 不是 fastboot/adb 路径问题  
5. 伪装成原厂**不可行**（无联想私钥、无 SHA256 碰撞）

---

## 5. ZUI 15.1.105 售后包

| 项 | ZUI 15.1.105 | ZUI 16.0.544 |
|---|---|---|
| recovery.img | 100MB | 96MB |
| vbmeta.img | 64KB，**Flags=2**（HASHTREE_DISABLED） | 8KB，Flags=0 |
| abl | 1MB 分区镜像，payload 0x43000 | abl.elf 274432B |
| abl 代码差异 | 与 ZUI16 约 **87%** 字节不同 | — |
| 相同部分 | ELF 头、Lenovo CA、尾部 ~22KB | 同 |

- 9008 可刷（包内 MultiPortQLoader / QFIL）
- 命令行 `fh_loader` 写 **LUN4（abl）失败**：`Failed to open SDCC ... lun:4`
- **若旧 abl 无白名单，降级 abl 是唯一技术突破口**

---

## 6. 未竟与风险

| 事项 | 说明 |
|---|---|
| 9008 刷 ZUI15 abl | 命令行未成功；可用 **柚坛工具箱 / MultiPortQLoader GUI** |
| 全量 9008 | 可能清数据；有 9008 与两套官方包可救砖 |
| APatch / KernelSU | 不依赖 recovery 的 Root 路径，未做 |
| 设备当前 | 可进系统；recovery 分区或为 OF 测试镜像，可刷回原厂 |

---

## 7. 建议下一步

1. **柚坛工具箱（9008）刷 ZUI15 abl** → 再刷 OF → 试进 recovery  
2. 失败则接受白名单结论，Root 走 **APatch/KernelSU 刷 boot**  
3. 将《TB331FC-recovery-whitelist-report.md》发社区  

---

## 8. 构建备忘（可复现）

```bash
# OrangeFox 设备树：dsshhgg/TB331FC-TWRP 分支 fox-12.1
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
lunch fox_TB331FC-eng
mka adbd recoveryimage

# 刷入（原厂环境下第三方 rec 仍会被拦）
fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
fastboot flash recovery_a OrangeFox-*.img
fastboot reboot recovery
```

**注意**
- `fastboot boot` 本机不支持  
- 64KB vbmeta 在 ZUI16 上可能导致系统无法启动，优先原厂 8KB 尺寸  
- abl/xbl 必须 9008  

---

*文档生成时间：2026-09-29 · 会话内实测数据整理*