#
# Copyright (C) 2023 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Configure core_64_bit.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

# Configure full_base_telephony.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Builder / Maintainer
BUILD_USERNAME := Wanderer

# Build type: RELEASE (no official or unofficial)
LINEAGE_BUILDTYPE := RELEASE

# MindTheGapps build flag (default to true, overridable by environment)
WITH_GAPPS ?= true
TARGET_CORE_GAPPS := true
TARGET_IS_GROUPER := true

# Ensure clean AOSP replacement packages are bundled for Core GApps profile
PRODUCT_PACKAGES += \
    DeskClock \
    ExactCalculator \
    LatinIME \
    libjni_latinimegoogle \
    ThemePicker \
    WallpaperPicker2 \
    Jelly \
    Gallery2

# Include SetupWizard for GApps
ifeq ($(WITH_GAPPS),true)
PRODUCT_PACKAGES += \
    SetupWizard
endif

# Inherit MindTheGapps configurations if present
ifeq ($(WITH_GAPPS),true)
$(call inherit-product-if-exists, vendor/gapps/arm64/arm64-vendor.mk)
endif

# Inherit common lineage configurations
$(call inherit-product-if-exists, vendor/lineage/config/common_full_phone.mk)

# Inherit custom release signing keys
$(call inherit-product-if-exists, vendor/wanderer-priv/keys/keys.mk)

# Inherit device configurations
$(call inherit-product, device/xiaomi/breeze/device.mk)

# Inherit from the proprietary version
$(call inherit-product, vendor/xiaomi/breeze/breeze-vendor.mk)

## Device identifier
PRODUCT_DEVICE := breeze
PRODUCT_NAME := lineage_breeze
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := 2406ERN9CI
PRODUCT_MANUFACTURER := Xiaomi

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="breeze_in-user 16 BP2A.250605.031.A3 OS3.0.303.0.WNUINXM release-keys" \
    BuildFingerprint=Redmi/breeze_in/breeze:16/BP2A.250605.031.A3/OS3.0.303.0.WNUINXM:user/release-keys \
    DeviceName=breeze \
    DeviceProduct=breeze_in

# GMS
PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

# Quick Settings Dialogs
PRODUCT_PRODUCT_PROPERTIES += \
    persist.sys.qs_bt_show_dialog=1 \
    persist.sys.qs_data_show_dialog=1
