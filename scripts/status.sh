#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 gregcmartin
set -euo pipefail
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
printf 'Kernel: %s\n' "$(uname -r)"
if command -v dkms >/dev/null; then dkms status -m rtw88; fi
for parameter in rtw_pci/disable_host_aspm rtw_pci/disable_aspm rtw_core/disable_lps_deep; do
    path="/sys/module/${parameter%/*}/parameters/${parameter#*/}"
    if [[ -f "$path" ]]; then
        printf '%s: %s\n' "$parameter" "$(cat "$path")"
    else
        printf '%s: not loaded\n' "$parameter"
    fi
done
found=0
for device in /sys/bus/pci/devices/*; do
    [[ -f "$device/vendor" && -f "$device/device" ]] || continue
    if [[ $(cat "$device/vendor") != 0x10ec || $(cat "$device/device") != 0xc821 ]]; then continue; fi
    found=1
    printf '\nRTL8821CE: %s\n' "${device##*/}"
    if [[ -L "$device/driver" ]]; then printf 'Driver: %s\n' "$(basename "$(readlink -f "$device/driver")")"; fi
    real_device=$(readlink -f "$device")
    for link in "$device" "$(dirname "$real_device")"; do
        printf '\nPCIe device/port: %s\n' "${link##*/}"
        lspci -s "${link##*/}" -vv | grep -E 'LnkCap:|LnkCtl:|LnkSta:|L1SubCtl[12]:' || true
        for counter in "$link"/aer_dev_correctable "$link"/aer_dev_nonfatal "$link"/aer_dev_fatal; do
            if [[ -r "$counter" ]]; then
                printf '%s\n' "${counter##*/}"
                cat "$counter"
            fi
        done
    done
    for interface in "$device"/net/*; do
        [[ -d "$interface" ]] || continue
        printf '\nInterface: %s\n' "${interface##*/}"
        iw dev "${interface##*/}" get power_save
    done
done
[[ $found -eq 1 ]] || printf 'No RTL8821CE found.\n'
