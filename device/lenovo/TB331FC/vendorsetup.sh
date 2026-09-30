#!/bin/bash
# OrangeFox build env for TB331FC.
# Do NOT call add_lunch_combo here: it is removed in modern AOSP/OF trees
# and will abort `lunch` when this file is sourced.
# Lunch targets come from COMMON_LUNCH_CHOICES in AndroidProducts.mk.

export FOX_AB_DEVICE=1
export OF_AB_DEVICE_WITH_RECOVERY_PARTITION=1
export FOX_DELETE_AROMAFM=1
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1