# TB331FC OrangeFox

Research & port notes for **OrangeFox Recovery** on Lenovo Xiaoxin Pad 2024 (**TB331FC**, SM6225/khaje).

**Do not use TWRP** for this device workflow (project rule). Prefer OrangeFox; Root via APatch/KernelSU on boot if recovery is blocked.

## TL;DR

- OrangeFox **build/CI/device tree** work.
- **ABL recovery whitelist** blocks third-party recovery on ZUI 16 even with valid AOSP testkey-signed vbmeta.
- Changing **1 byte** in recovery used-content is rejected; **padding is not checked**.
- `abl`/`xbl` are **critical partitions** (fastboot cannot flash; use 9008).
- Full notes: [`docs/01-complete-handbook.zh.md`](docs/01-complete-handbook.zh.md) → use `01-complete-handbook.zh.md`.

## Docs (Chinese)

| Doc | Content |
|---|---|
| [complete handbook](docs/01-complete-handbook.zh.md) | Everything in one file |
| [whitelist report](docs/02-recovery-whitelist-report.zh.md) | ABL whitelist evidence |
| [port summary](docs/03-port-summary.zh.md) | What we built |
| [pitfalls](docs/04-pitfalls-device-issues.zh.md) | Traps & device issues |
| [AI handoff](docs/05-ai-handoff-prompt.zh.md) | Paste-to-another-AI prompt |

## Device tree

`device/lenovo/TB331FC/` — makefiles, fstab, fox.cfg, vendorsetup (text only; **no OEM kernel/modules**).

## Build (OrangeFox 12.1 tree)

```bash
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
lunch fox_TB331FC-eng
mka adbd recoveryimage
# clear cmdline before flash (builder may inject buildvariant=eng)
```

## Not in this repo

- Lenovo / Qualcomm firmware, stock kernel, vendor modules (proprietary)
- Prebuilt recovery images containing OEM blobs

Get official packages yourself (ZUI service packages) and keep them offline.

## License

Documentation: MIT. Device tree scripts: MIT.  
OEM components remain property of their owners.