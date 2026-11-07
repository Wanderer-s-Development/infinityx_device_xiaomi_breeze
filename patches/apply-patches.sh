#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2026 Project Infinity-X
# SPDX-License-Identifier: Apache-2.0
#
# Automated patch applicator for Project Infinity-X on Xiaomi Breeze (Redmi 13 5G / POCO M6 Plus 5G)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
if [[ "$(basename "${SCRIPT_DIR}")" == "patches" ]]; then
    PATCHES_DIR="${SCRIPT_DIR}"
else
    PATCHES_DIR="${SCRIPT_DIR}/patches"
fi
ANDROID_BUILD_TOP="$(cd "${PATCHES_DIR}/../../../.." && pwd)"

echo "=========================================================="
echo " Applying Project Infinity-X Patches for Xiaomi Breeze"
echo " Build Root: ${ANDROID_BUILD_TOP}"
echo " Patches Dir: ${PATCHES_DIR}"
echo "=========================================================="

declare -A PATCH_MAP=(
    ["frameworks_base"]="frameworks/base"
    ["hardware_lineage_interfaces"]="hardware/lineage/interfaces"
    ["packages_apps_Settings"]="packages/apps/Settings"
    ["packages_apps_WallpaperPicker2"]="packages/apps/WallpaperPicker2"
    ["system_update_engine"]="system/update_engine"
    ["vendor_extras"]="vendor/extras"
    ["vendor_infinity"]="vendor/infinity"
    ["vendor_pixel_gms"]="vendor/pixel/gms"
    ["vendor_pixel_sounds"]="vendor/pixel/sounds"
    ["vendor_pixel_themepicker"]="vendor/pixel/themepicker"
)

TOTAL_APPLIED=0
TOTAL_SKIPPED=0
TOTAL_FAILED=0

for dir_key in "${!PATCH_MAP[@]}"; do
    target_repo="${ANDROID_BUILD_TOP}/${PATCH_MAP[$dir_key]}"
    patch_subdir="${PATCHES_DIR}/${dir_key}"

    if [ ! -d "${target_repo}" ]; then
        echo "[-] Skipping ${dir_key}: Target directory ${target_repo} does not exist"
        continue
    fi

    if [ ! -d "${patch_subdir}" ]; then
        continue
    fi

    echo ""
    echo "[*] Repository: ${PATCH_MAP[$dir_key]}"

    for patch_file in "${patch_subdir}"/*.patch; do
        [ -e "${patch_file}" ] || continue
        patch_name="$(basename "${patch_file}")"

        # Check if already applied (reverse applies cleanly)
        if git -C "${target_repo}" apply --check --reverse "${patch_file}" >/dev/null 2>&1; then
            echo "    [ALREADY APPLIED] ${patch_name}"
            TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
            continue
        fi

        # Check if can apply forward
        if git -C "${target_repo}" apply --check "${patch_file}" >/dev/null 2>&1; then
            # Apply with git am or git apply
            if git -C "${target_repo}" am -3 "${patch_file}" >/dev/null 2>&1; then
                echo "    [APPLIED via git am] ${patch_name}"
                TOTAL_APPLIED=$((TOTAL_APPLIED + 1))
            elif git -C "${target_repo}" apply "${patch_file}" >/dev/null 2>&1; then
                echo "    [APPLIED via git apply] ${patch_name}"
                TOTAL_APPLIED=$((TOTAL_APPLIED + 1))
            else
                echo "    [FAILED] ${patch_name}"
                TOTAL_FAILED=$((TOTAL_FAILED + 1))
            fi
        else
            echo "    [CONFLICT / CANNOT APPLY] ${patch_name}"
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
        fi
    done
done

echo ""
echo "=========================================================="
echo " Summary: ${TOTAL_APPLIED} applied, ${TOTAL_SKIPPED} already applied, ${TOTAL_FAILED} failed"
echo "=========================================================="

if [ ${TOTAL_FAILED} -gt 0 ]; then
    exit 1
fi
