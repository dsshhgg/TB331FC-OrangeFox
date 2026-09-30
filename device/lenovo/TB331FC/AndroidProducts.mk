#
# Copyright (C) 2024 The Android Open Source Project
# SPDX-License-Identifier: Apache-2.0
#

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/omni_TB331FC.mk \
    $(LOCAL_DIR)/fox_TB331FC.mk \
    $(LOCAL_DIR)/twrp_TB331FC.mk

COMMON_LUNCH_CHOICES := \
    omni_TB331FC-eng \
    fox_TB331FC-eng \
    twrp_TB331FC-eng