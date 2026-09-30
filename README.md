# TB331FC Hub

联想 **小新 Pad 2024（TB331FC）** 开源资料中心：OrangeFox 移植研究、设备树、脚本、资源索引。

> **GitHub = 目录；网盘 = 仓库。**  
> 大文件（ZUI 全量包、GSI、super）请看 [资源索引.md](资源索引.md)，不要塞进 Git。

## 禁止

- **不要使用 TWRP**（本项目规则）。优先 OrangeFox；Root 可用 APatch / KernelSU。  
- 不要把 100MB+ 固件直接 push 到 GitHub。

## 目录

```
TB331FC-Hub（本仓库）
├── README.md
├── 资源索引.md              ← 大文件网盘入口
├── docs/                    ← 完整手册与报告
├── device/lenovo/TB331FC/   ← 设备树（文本）
├── scripts/                 ← 备份 / 校验脚本
├── tools/README.md          ← 工具获取说明
└── .github/workflows/       ← OrangeFox CI
```

## 快速开始

1. 读 [docs/01-complete-handbook.zh.md](docs/01-complete-handbook.zh.md)  
2. 大文件从 [资源索引.md](资源索引.md) 获取  
3. 需要 AI 接手：复制 [docs/05-ai-handoff-prompt.zh.md](docs/05-ai-handoff-prompt.zh.md)

## 构建 OrangeFox（摘要）

```bash
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
lunch fox_TB331FC-eng
mka adbd recoveryimage
```

## 结论（研究摘要）

- OrangeFox **可编译**。  
- ZUI 16 **ABL recovery 白名单**拦截第三方 rec（含 testkey 合法 vbmeta）。  
- 有效内容 1-bit 改动即拒；padding 不校验。  
- abl/xbl 仅 **9008** 可写。  
- 细节见 docs。

## License

MIT（文档与脚本）。OEM 固件版权归联想/高通等所有，本仓库不托管。