#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 gregcmartin
set -Eeuo pipefail
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

[[ $# -eq 0 || ( $# -eq 1 && "$1" == --check ) ]] || die 'Usage: sudo ./install.sh [--check]'
[[ $EUID -eq 0 ]] || die 'Run with sudo.'
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || die 'This installer supports x86-64 Linux only.'
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == ubuntu ]] || die 'This installer supports Ubuntu only.'
KERNEL=$(uname -r)
[[ $KERNEL == 6.8.* ]] || die "Only the 6.8 kernel series is supported by this experimental installer; running $KERNEL."
found=0
for device in /sys/bus/pci/devices/*; do
    [[ -f "$device/vendor" && -f "$device/device" ]] || continue
    if [[ $(cat "$device/vendor") == 0x10ec && $(cat "$device/device") == 0xc821 ]]; then
        found=$((found + 1))
    fi
done
[[ $found -eq 1 ]] || die 'Expected exactly one RTL8821CE (10ec:c821).'
command -v nmcli >/dev/null || die 'NetworkManager is required.'
nmcli general status >/dev/null
command -v dracut >/dev/null || command -v update-initramfs >/dev/null || die 'A supported initramfs generator is required.'
for path in "$STATE" "$SOURCE" "$MODULE_CONFIG" "$NM_CONFIG"; do
    [[ ! -e "$path" && ! -L "$path" ]] || die "Already exists: $path. Resolve/uninstall the existing installation first."
done
if command -v dkms >/dev/null; then
    installed=$(dkms status)
    if grep -Eqi '(^|[[:space:]])(rtw88|rtl8821ce|rtl88|8821ce)[^/[:space:]]*/' <<< "$installed"; then
        die 'A potentially conflicting Realtek DKMS driver is already registered; uninstall it using its own instructions first.'
    fi
fi
if [[ -d /sys/firmware/efi ]]; then
    command -v mokutil >/dev/null || die 'Install mokutil first (sudo apt install mokutil), then retry.'
    sb=$(mokutil --sb-state) || die 'Unable to determine Secure Boot state.'
    grep -q 'SecureBoot disabled' <<< "$sb" || die 'This experimental installer requires Secure Boot disabled; signing/enrollment is not validated.'
fi
if [[ ${1:-} == --check ]]; then
    printf 'Platform/conflict checks passed. Kernel: %s. Dependencies and headers will be checked by apt during installation.\n' "$KERNEL"
    exit 0
fi

exec 9>/run/lock/gole2-linux-wifi-fixes.lock
flock -n 9 || die 'Another install or uninstall is running.'
# Repeat the ownership check after acquiring the lock.
for path in "$STATE" "$SOURCE" "$MODULE_CONFIG" "$NM_CONFIG"; do
    [[ ! -e "$path" && ! -L "$path" ]] || die "Already exists: $path."
done

printf 'Installing experimental GOLE Wi-Fi driver. Use Ethernet for recovery. No automatic reboot or live driver replacement.\n'
apt-get update
apt-get install -y dkms build-essential gcc-13 "linux-headers-$KERNEL" linux-firmware pciutils iw mokutil
[[ -e /lib/modules/$KERNEL/build/Makefile ]] || die 'Matching kernel headers are missing.'
firmware_found=0
for path in /lib/firmware/rtw88/rtw8821c_fw.bin{,.zst,.xz,.gz}; do
    [[ ! -f "$path" ]] || firmware_found=1
done
[[ $firmware_found -eq 1 ]] || die 'RTL8821C firmware is missing from linux-firmware.'

install -d -m 700 "$STATE"
rollback() {
    local result=$?
    trap - EXIT INT TERM
    if [[ $result -ne 0 ]]; then
        printf 'Installation failed; removing this attempted installation.\n' >&2
        set +e
        restore_profiles
        dkms remove -m rtw88 -v "$VERSION" --all
        rm -f -- "$MODULE_CONFIG" "$NM_CONFIG"
        rm -rf -- "$SOURCE"
        refresh_initramfs
        printf 'Saved profile settings remain in %s for recovery.\n' "$STATE" >&2
    fi
    exit "$result"
}
trap rollback EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

install -d -m 755 "$SOURCE"
install -m 644 "$ROOT"/driver/* "$SOURCE/"
install -m 644 "$ROOT/LICENSE" "$SOURCE/LICENSE"
dkms add -m rtw88 -v "$VERSION"
CC=gcc-13 JOBS=3 dkms build -m rtw88 -v "$VERSION" -k "$KERNEL"
CC=gcc-13 JOBS=3 dkms install -m rtw88 -v "$VERSION" -k "$KERNEL"
modinfo -k "$KERNEL" -p rtw_pci | grep -q '^disable_host_aspm:' || die 'Installed module lacks the new host ASPM option.'

# Save numeric settings before changing any profiles. Never copy credentials.
profiles=$(nmcli -t -f UUID,TYPE connection show)
while IFS=: read -r uuid type; do
    [[ $type == 802-11-wireless ]] || continue
    previous=$(nmcli -g 802-11-wireless.powersave connection show uuid "$uuid")
    previous=${previous%% *}
    [[ "$uuid" =~ ^[0-9a-fA-F-]{36}$ && "$previous" =~ ^[0-3]$ ]] || die 'Unexpected NetworkManager profile value.'
    printf '%s\t%s\n' "$uuid" "$previous" >> "$STATE/profile-powersave.tsv"
done <<< "$profiles"
if [[ -f "$STATE/profile-powersave.tsv" ]]; then
    while IFS=$'\t' read -r uuid previous; do
        nmcli connection modify uuid "$uuid" 802-11-wireless.powersave 2
    done < "$STATE/profile-powersave.tsv"
fi
install -d -m 755 /etc/modprobe.d /etc/NetworkManager/conf.d
cat > "$MODULE_CONFIG" <<'CONFIG'
# Managed by gole2-linux-wifi-fixes. Experimental RTL8821CE workaround.
blacklist rtw88_8821ce
blacklist rtw88_8821c
blacklist rtw88_pci
blacklist rtw88_core
options rtw_pci disable_host_aspm=y disable_aspm=y
options rtw_core disable_lps_deep=y
CONFIG
cat > "$NM_CONFIG" <<'CONFIG'
# Managed by gole2-linux-wifi-fixes.
[connection]
wifi.powersave=2
CONFIG
chmod 644 "$MODULE_CONFIG" "$NM_CONFIG"
refresh_initramfs
printf '%s\n' "$VERSION" > "$STATE/installed-version"
trap - EXIT INT TERM
printf '\nInstalled for %s. Save your work, then reboot manually.\nAfter boot: sudo ./scripts/status.sh\nRecovery/removal: sudo ./uninstall.sh\n' "$KERNEL"
