# TB331FC（联想小新 Pad 2024）第三方 Recovery 测试报告

## 结论（TL;DR）

在 **ZUI 16.0.544** 原厂启动链下，**OrangeFox / TWRP 均无法进入**。

联想 ABL 存在一道**独立于 AVB 的 recovery 白名单**：只放行原厂签名 recovery 镜像。
即使 AOSP testkey 与原厂公钥一致、即使 vbmeta 校验已按合法方式重签，第三方 recovery 仍被拦截。

## 设备信息

| 项目 | 值 |
|---|---|
| 机型 | TB331FC / 小新 Pad 2024 |
| 平台 | SM6225 (bengal/khaje) + Adreno 610 |
| 系统 | ZUI 16.0.544 (Android 14) |
| 解锁 | unlocked: yes / secure: yes |
| 分区 | A/B + 独立 recovery（0x6400000 = 100MB） |

## 关键证据

### 1. AOSP testkey 确实被信任

原厂 vbmeta 公钥 sha1：

```
2597c218aae470a130f61162feaae70afd97f011
```

与 `testkey_rsa4096.pem` 提取的公钥指纹**完全一致**。
说明「测试密钥漏洞」在密钥层面成立。

### 2. 仍无法启动第三方 recovery

| # | vbmeta | recovery | 结果 |
|---|---|---|---|
| 1 | 原厂原样 | 原厂 | ✅ 可进 recovery |
| 2 | 原厂 + disable-verity | OrangeFox / TWRP | ⏭ 跳过 rec，进系统 |
| 3 | testkey flags=3 + chain | OF（原厂镜像头） | ❌ 回 fastboot |
| 4 | testkey flags=0 + 全哈希描述符 | OF（recovery 哈希已按 OF 重算） | ❌ 回 fastboot |
| 5 | 原厂 + disable-verity | TWRP ramdisk + 原厂头（96MB/kernel=0/osv=0/sig=0） | ⏭ 跳过 rec，进系统 |
| 6 | 64KB 自签 vbmeta | 任意 | ❌ 系统无法启动 |

### 3. 镜像侧已对齐原厂仍失败

OrangeFox 产物已做到：

- 打包原厂 GKI 内核（46.8MB，与 boot.img 一致）
- cmdline 为空（去掉 `buildvariant=eng`）
- 头字段对齐原厂（os_version=0、sig_size=0、96MB 尺寸）
- recovery AVB 哈希与 vbmeta 描述符一致

**仍被拦截。**

## 推断

拦截点在 **abl（Android Bootloader）**，不读 vbmeta 描述符、不认 testkey 签名，
只认联想官方对 recovery 镜像的白名单/独立签名。

9/27 社区 TWRP 包曾能进入，在 ZUI 16.0.544 干净原厂链上**不可复现**。实体按键（音量上+电源）亦无法进入第三方 recovery。

## 对社区的建议

1. TB331FC 在 ZUI 16.0.544 上**不要期待** TWRP/OrangeFox 卡刷 recovery  
2. Root 路径优先考虑 **KernelSU / APatch 刷 boot**（不依赖 recovery）  
3. 研发注意：AVB 绕过 ≠ recovery 可启动；需单独研究 abl 白名单

## 测试方法备忘

- 进 recovery 推荐：`adb reboot recovery` 或实体键（音量上+电源）  
- `fastboot reboot recovery` 在本机不可靠  
- `fastboot fetch` 不支持  
- 64KB padding 的 vbmeta 会导致系统无法启动，请用 **8KB** 或原厂尺寸

---

*测试环境：Windows + fastboot 35.x；镜像构建见 dsshhgg/TB331FC-TWRP 分支 fox-12.1*
## 最终确认（实体按键）

| 入口 | 结果 |
|---|---|
| `adb reboot recovery` | 第三方 rec 被跳过 / 回 fastboot |
| `fastboot reboot recovery` | 回 fastboot |
| **实体键 音量上+电源** | **进不去** |

三条入口均无法启动 TWRP/OrangeFox。**abl recovery 白名单结论成立。**
## 伪装/最小改动实验（最终否定）

| 实验 | 结果 |
|---|---|
| magiskboot 同内容 repack | 与原厂 SHA256 一致（格式可无损） |
| padding 32MB 处改 1 字节 + 原厂 vbmeta | ✅ 仍可进 recovery |
| ramdisk 有效内容改 1 bit + **已更新哈希的 testkey vbmeta** | ❌ 回 fastboot |
| OF/TWRP 全量 ramdisk + 各种 vbmeta | ❌ |

**结论**：recovery **有效内容（约 14.5MB）** 被 AVB 之外的机制锁定。
只改 padding 无法改变启动逻辑；改内容则无法通过校验。
第三方 recovery **无法伪装成原厂**（无联想私钥、无 SHA256 碰撞）。

## 对想做伪装的后来者

1. 先做「1-bit 有效内容 + 匹配哈希 vbmeta」实验，再决定是否投入 OF 适配  
2. padding 可自由使用（可用于藏数据，不能改 recovery 功能）  
3. Root 请走 **boot 分区**（APatch / KernelSU），不要依赖 recovery  

---

## 2026-10-03 补充：决定性实验（把结论钉死）

本报告的推断已由两个后续实验完整验证，**「白名单 = 联想原厂签名」现在是实测结论，不再是推断**。

**实验一：换 abl 无效**

| 步骤 | 结果 |
|---|---|
| EDL 读回设备 abl | **ZUI16**（sha256 `22eaf506…`，与 ZUI15 差 239155 字节） |
| 用 `--memoryname=ufs` 写入 ZUI15 abl | ✅ 成功，读回确认两槽 = `349b5b40…` |
| 刷 OF 到 `recovery_a` + `reboot recovery` | ❌ **仍回落 fastboot** |
| ZUI15 abl 配 ZUI16 系统 | ❌ 系统也起不来 |

→ **「换旧 abl 绕过白名单」证伪。**

**实验二：白名单认「联想签名」，不认具体镜像**

| 刷入 `recovery_a` 的镜像 | 结果 |
|---|---|
| ZUI15 **原厂** recovery（联想签名，与 ZUI16 那份内容差 14,256,200 字节） | ✅ **能进 recovery** |
| 我们编译的 OF（testkey 签名 + 正确 boot 哈希 + 完整 ramdisk） | ❌ 被拦 |
| 原厂 recovery 改 1 bit | ❌ 被拦 |

→ **门槛是联想对 recovery 镜像的签名**，与 ZUI 版本无关；
AOSP testkey 只在 **AVB 层**有效（重签 vbmeta 会被接受、系统能正常启动），
**ABL 另有一层独立签名校验，不看 AVB**。

**结论**：没有联想私钥，第三方 recovery 在这台设备上**无法启动**；
后续应直接走 **APatch / KernelSU 刷 boot**。

**附带两个操作要点（后来者省时）**
- EDL 写 abl/分区**必须** `--memoryname=ufs`，否则报 `Failed to open SDCC ... lun:4`
- `fh_loader --sendimage` 是「发送本地文件」，**读回**要用 `<read .../>` 的 XML + `--sendxml` + `--mainoutputdir`
- 每次重进 9008 都要重新送 firehose；协议失步时用 `QSaharaServer ... -k` 复位