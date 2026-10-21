#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 gregcmartin
# Shared variables are consumed by install.sh and uninstall.sh.
# shellcheck disable=SC2034

VERSION=0.6-gole1
STATE=/var/lib/gole2-linux-wifi-fixes
SOURCE=/usr/src/rtw88-$VERSION
MODULE_CONFIG=/etc/modprobe.d/90-gole2-wifi-fixes.conf
NM_CONFIG=/etc/NetworkManager/conf.d/90-gole2-wifi-fixes.conf

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

refresh_initramfs() {
    if command -v dracut >/dev/null; then
        dracut --force --kver "$(uname -r)"
    elif command -v update-initramfs >/dev/null; then
        update-initramfs -u -k "$(uname -r)"
    else
        die 'No supported initramfs generator found.'
    fi
}

restore_profiles() {
    local uuid previous current available failed=0
    [[ -f "$STATE/profile-powersave.tsv" ]] || return 0
    available=$(nmcli -g UUID connection show) || return 1
    while IFS=$'\t' read -r uuid previous; do
        [[ "$uuid" =~ ^[0-9a-fA-F-]{36}$ && "$previous" =~ ^[0-3]$ ]] || {
            printf 'Skipping invalid saved profile setting.\n' >&2
            failed=1
            continue
        }
        # Missing profiles were deleted by the user. Other read failures must
        # preserve the backup and fail the uninstall instead of losing it.
        grep -Fxq "$uuid" <<< "$available" || continue
        current=$(nmcli -g 802-11-wireless.powersave connection show uuid "$uuid" 2>/dev/null) || {
            failed=1
            continue
        }
        if [[ "${current%% *}" == 2 ]]; then
            nmcli connection modify uuid "$uuid" 802-11-wireless.powersave "$previous" || failed=1
        fi
    done < "$STATE/profile-powersave.tsv"
    return "$failed"
}
