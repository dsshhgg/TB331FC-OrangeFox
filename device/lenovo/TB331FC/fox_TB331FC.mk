#
# OrangeFox product makefile - Lenovo Xiaoxin Pad 2024 (TB331FC)
#

# Inherit TWRP hardware config (partitions, modules, fstab, init rc)
$(call inherit-product, device/lenovo/TB331FC/device.mk)

# Same arch flags as core_64_bit_only.mk (required or lunch aborts on
# "Building a 32-bit-app-only product on a 64-bit device")
TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_SUPPORTS_64_BIT_APPS := true

# OrangeFox / TWRP common (theme, crypto, UI)
$(call inherit-product, vendor/twrp/config/common.mk)

# Product identity
PRODUCT_NAME := fox_TB331FC
PRODUCT_DEVICE := TB331FC
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Xiaoxin Pad 2024
PRODUCT_MANUFACTURER := Lenovo

# Device version string (shown on OrangeFox main screen)
TW_DEVICE_VERSION := TB331FC-Fox-12.1

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="TB331FC_PRC-user 13 TKQ1.230227.001 ZUI_15.1.045_230928_PRC release-keys"

# ---------------------------------------------------------------------------
# OrangeFox build variables
# ---------------------------------------------------------------------------
FOX_AB_DEVICE := 1
OF_AB_DEVICE_WITH_RECOVERY_PARTITION := 1
OF_DYNAMIC_PARTITIONS := true


# 8GB device: do not enable large swap
FOX_USE_SWAP := 0

# Slim: keep recovery.img under the 100MB partition after packing kernel
FOX_DELETE_AROMAFM := 1
FOX_DISABLE_APP_MANAGER := 1
TW_NO_SCREEN_BLANK := true
TW_INCLUDE_NTFS_3G := false
TW_EXCLUDE_MTP := true
# FOX_VERSION is obsolete in this OF tree; use FOX_MAINTAINER_PATCH_VERSION if needed
# FOX_MAINTAINER_PATCH_VERSION := 0

# ---------------------------------------------------------------------------
# A/B + OTA
# ---------------------------------------------------------------------------
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    system \
    vendor \
    odm \
    product \
    system_ext

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := false