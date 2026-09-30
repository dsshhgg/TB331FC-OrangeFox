#
# Copyright (C) 2024 The Android Open Source Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/lenovo/TB331FC

# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a73
TARGET_CPU_VARIANT_RUNTIME := cortex-a73

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

# Bootloader
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true

# Platform
TARGET_BOARD_PLATFORM := bengal
TARGET_BOARD_PLATFORM_GPU := qcom-adreno610
BOARD_USES_QCOM_HARDWARE := true

# Kernel (GKI, header v4, empty recovery kernel like stock)
BOARD_KERNEL_PAGESIZE := 4096
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := kernel
# Canonical build/make variable name (same as working TB321FU tree)
BOARD_BOOTIMG_HEADER_VERSION := 4
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_CMDLINE :=
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)

# Stock recovery.img contains no kernel (GKI): bootloader loads it from boot.
# Two knobs work together to reproduce the stock layout exactly:
# 1. TARGET_PREBUILT_KERNEL := device/lenovo/TB331FC/prebuilt/kernel satisfies TWRP's kernel.mk check
#    (it errors with "NO KERNEL" when neither kernel source nor a prebuilt
#    is defined) and produces an empty kernel payload, like stock.
# 2. BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := false makes build/make skip
#    the --cmdline argument entirely: TeamWin android-12.1 unconditionally
#    appends "buildvariant=eng" to the recovery header cmdline otherwise,
#    and the Lenovo bootloader falls back to fastboot on a non-empty cmdline.
TARGET_PREBUILT_KERNEL := device/lenovo/TB331FC/prebuilt/kernel
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := false

# Use LZ4 Ramdisk compression (stock uses LZ4)
BOARD_RAMDISK_USE_LZ4 := true

# A/B
AB_OTA_UPDATER := true

# Partitions (sizes from stock dump)
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_BOOTIMAGE_PARTITION_SIZE := 104857600
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296

BOARD_HAS_LARGE_FILESYSTEM := true

# Dynamic Partitions (from stock recovery.fstab: ext4 logical)
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := lenovo_dynamic_partitions
BOARD_LENOVO_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext vendor vendor_dlkm odm product
BOARD_LENOVO_DYNAMIC_PARTITIONS_SIZE := 9122611200

# Filesystems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_SYSTEM_EXTIMAGE := true

# Workaround for error copying vendor files to recovery ramdisk
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4

# Recovery
TARGET_SYSTEM_PROP := \
    $(DEVICE_PATH)/system.prop

TARGET_RECOVERY_FSTAB := \
    $(DEVICE_PATH)/recovery.fstab

TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_USES_LOGD := true

# TWRP Configuration
TW_THEME := portrait_hdpi
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := en
TW_SCREEN_BLANK_ON_BOOT := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_USE_TOOLBOX := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_NTFS_3G := true
TW_HAS_MTP := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_EXCLUDE_APEX := true
TW_EXCLUDE_TWRPAPP := true
TW_INCLUDE_FASTBOOTD := true
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 1020
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone7/temp"
TW_BATTERY_SYSFS_WAIT_SECONDS := 6

# Vendor modules loaded by TWRP kernel_module_loader
TW_LOAD_VENDOR_MODULES += "nvt36523_spi.ko nopmi-chg.ko panel_event_notifier.ko spi-msm-geni.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true

# Crypto (FBE) - Qualcomm
TW_INCLUDE_CRYPTO               := true
TW_INCLUDE_CRYPTO_FBE           := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_QCOM_FBE_DECRYPTION  := true

# Security patch level
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
PLATFORM_VERSION := 99
PLATFORM_VERSION_LAST_STABLE = $(PLATFORM_VERSION)

# Verified Boot - The stock vbmeta_a.img contains a Hash descriptor for the
# recovery partition (stock digest 6e345d34..., image 14585856). The
# bootloader verifies the recovery image hash on every boot, so a custom
# TWRP recovery (different hash) is rejected and falls back to fastboot -
# this is the real boot blocker (NOT the cmdline or the 2099-12 patch level;
# the working TB321FU uses the identical security-patch/version values).
# The stock vbmeta is testkey-signed (pubkey sha1 2597c218...), the same key
# this tree signs with, so the device trusts our signatures.
#
# Fix: --flags 3 makes the build's vbmeta AVB-verification-DISABLED and
# testkey-signed (= device-trusted). Flash it to the vbmeta partition before
# recovery (shipped in the release + documented in flash steps) to disable
# the stock recovery-hash enforcement so the custom recovery boots.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# ========== OrangeFox ==========
OF_USE_TWRP_SAR_DETECT := true
OF_DISABLE_DM_VERITY := true
OF_DISABLE_FORCED_ENCRYPTION := true
OF_NO_TREBLE_COMPATIBILITY_CHECK := true
OF_SUPPORT_INPUT_1_2_HAPTICS := true
OF_STATUS_INDICATOR := true
OF_ALLOW_DISABLE_NAVBAR := true
OF_QUICK_BACKUP_LIST := "boot"
FOX_USE_SPECIFIC_MAGISK_ZIP := false

# ========== A/B device ==========
# Mark as A/B device (new name; old OF_AB_DEVICE still recognized)
FOX_AB_DEVICE := 1

# Critical: A/B with a dedicated recovery partition (not ramdisk-in-boot).
# Without this, the OF installer writes recovery into the boot partition.
OF_AB_DEVICE_WITH_RECOVERY_PARTITION := 1

# ========== Dynamic partitions ==========
OF_DYNAMIC_PARTITIONS := true

# Recovery repack
TW_INCLUDE_REPACKTOOLS := true

TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab