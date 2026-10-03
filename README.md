# TB331FC Hub

联想 **小新 Pad 2024（TB331FC）** 开源资料中心：OrangeFox 移植研究、设备树、脚本、资源索引。

> **GitHub = 目录；网盘 = 仓库。**
> 大文件（ZUI 全量包、GSI、super）请看 [资源索引.md](资源索引.md)，不要塞进 Git。
> 123 网盘：https://1824924518.share.123pan.cn/123pan/Y4m2jv-Ox0lv

---

## ⚠️ 先读这一段，能省你几周

**在 TB331FC 上，第三方 recovery（OrangeFox / TWRP / PBRP）无法启动。**
这不是编译问题、不是内核/cmdline/vbmeta 问题，而是**联想在 ABL 里校验 recovery 镜像的原厂签名**。

**决定性证据（2026-10-03 实测）**

| 刷进 `recovery_a` 的镜像 | 结果 |
|---|---|
| ZUI15 **原厂** recovery（同为联想签名，内容与 ZUI16 那份差 14,256,200 字节） | ✅ **能进 recovery** |
| 我们编译的 OrangeFox（AOSP testkey 签名 + 正确 boot 哈希 + 完整 ramdisk） | ❌ 被拦 |
| 原厂 recovery 有效内容改 1 bit | ❌ 被拦 |

⇒ 门槛是「**联想对 recovery 镜像的签名**」，与 ZUI 版本无关。

**AOSP testkey 的边界**：原厂 vbmeta 公钥恰好就是 AOSP testkey，所以**重签 vbmeta 会被接受**
（实测：含我们 boot 哈希的 testkey vbmeta，系统照常启动）——但那只是 **AVB 层**；
**ABL 另有一层独立签名校验，不看 AVB**。没有联想私钥，就签不出能过这一层的 recovery。

### 已经实测证伪、不要再浪费时间的路线

| 路线 | 结果 |
|---|---|
| 调 OF 编译参数 / 打包内核 / 清 cmdline / 镜像头对齐原厂 | ❌ 无关，门槛是签名 |
| vbmeta 用 testkey 重签（flags=0 / flags=3 / 全哈希描述符） | ❌ 只过 AVB 层，放行不了 recovery |
| 原厂 recovery 当模板塞 OF ramdisk（改 1 bit / padding 改动） | ❌ 内容一变即拒 |
| **9008 换 ZUI15 abl** 后再刷 OF | ❌ **已实测**：写入成功、读回确认，仍被拦 |
| **把 OF 镜像塞进 boot 分区**（含头部与原镜像一字不差的 96MB 版） | ❌ recovery 模式下走的是 recovery 分区，boot 里的镜像不被执行 |
| 仅刷 `vbmeta` 各种组合 | ❌ 同上 |

### 建议的路

- **要 Root**：走 **APatch / KernelSU 刷 boot**（不依赖 recovery）—— 见下
- **要救砖**：9008 + ZUI15/ZUI16 售后包（见 [资源索引.md](资源索引.md)）
- **本项目规则**：**不使用 TWRP**

### 已验证的 Root 素材（TB331FC / ZUI 16.0.544）

| 文件 | 检查结果 |
|---|---|
| `boot-apn.img` | 96MB；内核 **47002080** = 原厂 46819840 + 注入 182240 字节（APatch 正常特征） |
| `vbmeta-必刷.img` | 8192 B；公钥 sha1 **`2597c218…`** = 与原厂相同的 AOSP testkey；fingerprint = `ZUI_16.0.544_241115`（与本机系统一致） |

刷入（**boot 与 vbmeta 必须成对刷**，否则 AVB 哈希不匹配）：

```bash
fastboot flash boot_a   boot-apn.img          # 只动 A 槽，B 槽保留原厂做退路
fastboot flash vbmeta_a vbmeta-必刷.img
fastboot reboot
```

回滚：`fastboot flash boot_a <原厂boot.img>` + `fastboot flash vbmeta_a <原厂vbmeta.img>`。
刷 boot 不清数据。如果 `vbmeta-必刷.img` 引导失败，可改用自签 vbmeta（testkey + flags=3 禁校验，
做法见 [06](docs/06-abl-downgrade-edl.zh.md) 第十四节）。

---

## 文档索引

| 文档 | 内容 | 时效 |
|---|---|---|
| [01 完整手册](docs/01-complete-handbook.zh.md) | 16 部分总集：结论、设备事实、实验矩阵、坑表、命令、AI 交接提示词 | ✅ 最新 |
| [02 白名单报告](docs/02-recovery-whitelist-report.zh.md) | 白名单实验全记录 + 2026-10-03 决定性实验补充 | ✅ 已更新 |
| [03 移植总结](docs/03-port-summary.zh.md) | 早期移植流程与根因（含已修正的旧结论） | ⚠️ 含历史结论，看标注 |
| [04 踩坑与机型问题](docs/04-pitfalls-device-issues.zh.md) | 34 条坑位、机型通病 | ✅ 有效 |
| [05 AI 交接提示词](docs/05-ai-handoff-prompt.zh.md) | 给 AI/后来者的开工提示词（已更新结论） | ✅ 已更新 |
| [06 abl/boot 实验与 EDL 工具](docs/06-abl-downgrade-edl.zh.md) | **最详尽**：EDL 读写方法、分区坐标、abl 分析、日志可得性、决定性实验 | ✅ 最新 |
| [07 验证清单](docs/07-verification-checklist.zh.md) | 刷机后逐项验证（含本机不适用的项已修正） | ✅ 已修正 |

**只想看结论**：本页 + `06` 的第十六节。
**想复刻实验**：`06` 全文（含可直接运行的 PowerShell 脚本与 `--memoryname=ufs`、`<read>` XML 等关键细节）。

---

## 目录结构

```
TB331FC-Hub（本仓库）
├── README.md
├── 资源索引.md               ← 大文件网盘入口（含 MD5）
├── docs/                     ← 7 篇文档（见上表）
├── device/lenovo/TB331FC/    ← OrangeFox 设备树（纯文本）
├── scripts/                  ← 备份 / 校验 / 验证脚本
├── tools/README.md           ← 工具获取说明
└── .github/workflows/        ← OrangeFox CI（build-fox.yml）
```

## 构建 OrangeFox（可编译，但设备上跑不起来）

```bash
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
lunch fox_TB331FC-eng
mka adbd recoveryimage
```

- CI 会拉原厂内核 `stock-kernel.gz`（46819840 B）→ `prebuilt/kernel`
- 产物 `OrangeFox-R12.x-Unofficial-TB331FC.img`；设备端受签名门槛限制，**仅供研究/参考**

## 机型关键事实

| 项 | 值 |
|---|---|
| 代号 | `TB331FC` / 小新 Pad 2024 / SM6225 khaje |
| 分区 | A/B + **独立 recovery** |
| recovery 分区 | `0x6400000` = 100MB |
| boot 分区 | `0x6000000` = 96MB（**只含内核，无 ramdisk**） |
| vendor_boot | 正常启动的 ramdisk 在这里（`VNDRBOOT` v4，11553237 B） |
| vbmeta 分区 | `0x10000` = 64KB（原厂文件 8KB，公钥 = AOSP testkey `2597c218…`） |
| abl / xbl | `0x100000` / `0x380000`，**Critical，只能 9008 写** |
| 不支持 | `fastboot boot`、`fastboot fetch` |
| EDL 写分区 | **必须** `--memoryname=ufs`（UFS 存储） |

## License

MIT（文档与脚本）。OEM 固件版权归联想/高通等所有，本仓库不托管。
