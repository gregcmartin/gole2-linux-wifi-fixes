#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 gregcmartin
set -Eeuo pipefail
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"
[[ $# -eq 0 ]] || die 'Usage: sudo ./uninstall.sh'
[[ $EUID -eq 0 ]] || die 'Run with sudo.'
exec 9>/run/lock/gole2-linux-wifi-fixes.lock
flock -n 9 || die 'Another install or uninstall is running.'
[[ -d "$STATE" ]] || die 'No installation state found; nothing removed.'
if [[ -f "$STATE/installed-version" ]]; then
    [[ $(cat "$STATE/installed-version") == "$VERSION" ]] || die 'Version mismatch; use the matching uninstaller.'
fi
restore_profiles || die "Could not restore every profile; saved values remain in $STATE. Resolve NetworkManager errors and retry."
installed=$(dkms status -m rtw88 -v "$VERSION")
if [[ -n "$installed" ]]; then
    dkms remove -m rtw88 -v "$VERSION" --all
fi
rm -f -- "$MODULE_CONFIG" "$NM_CONFIG"
rm -rf -- "$SOURCE"
refresh_initramfs
rm -rf -- "$STATE"
printf 'Removed. The loaded driver remains active until reboot. Use Ethernet and reboot when ready.\n'
