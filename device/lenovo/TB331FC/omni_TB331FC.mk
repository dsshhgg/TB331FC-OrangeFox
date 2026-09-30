#
# OrangeFox product for Lenovo TB331FC
#
$(call inherit-product, device/lenovo/TB331FC/device.mk)

TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_SUPPORTS_64_BIT_APPS := true

# OrangeFox / TWRP common
$(call inherit-product, vendor/twrp/config/common.mk)

PRODUCT_DEVICE := TB331FC
PRODUCT_NAME := omni_TB331FC
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Lenovo TB331FC
PRODUCT_MANUFACTURER := Lenovo

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="TB331FC_PRC-user 13 TKQ1.230227.001 ZUI_15.1.045_230928_PRC release-keys"
