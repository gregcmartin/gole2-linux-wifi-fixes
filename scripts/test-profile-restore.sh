#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 gregcmartin
# Exercises recovery with an isolated NetworkManager stub; no system writes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"
STATE=$(mktemp -d)
trap 'rm -rf -- "$STATE"' EXIT
uuid_a=00000000-0000-4000-8000-000000000001
uuid_b=00000000-0000-4000-8000-000000000002
uuid_c=00000000-0000-4000-8000-000000000003
scenario=success
nmcli() {
    if [[ $1 == -g && $2 == UUID ]]; then
        [[ $scenario != unavailable ]] || return 1
        printf '%s\n%s\n' "$uuid_a" "$uuid_b"
    elif [[ $1 == -g && $2 == 802-11-wireless.powersave ]]; then
        [[ $scenario != read_failure ]] || return 1
        if [[ $6 == "$uuid_a" ]]; then printf '2 (disable)\n'; else printf '1 (ignore)\n'; fi
    elif [[ $1 == connection && $2 == modify ]]; then
        [[ $scenario != write_failure ]] || return 1
        printf '%s %s\n' "$4" "$6" >> "$STATE/changes"
    else
        printf 'Unexpected nmcli invocation.\n' >&2
        return 1
    fi
}
printf '%s\t3\n%s\t0\n%s\t3\n' "$uuid_a" "$uuid_b" "$uuid_c" > "$STATE/profile-powersave.tsv"
restore_profiles
[[ $(cat "$STATE/changes") == "$uuid_a 3" ]]
printf 'PASS: restore original value; preserve user edits; skip deleted profile.\n'
for scenario in unavailable read_failure write_failure; do
    if restore_profiles; then
        printf 'FAIL: expected failure for %s\n' "$scenario" >&2
        exit 1
    fi
    [[ -f "$STATE/profile-powersave.tsv" ]]
done
printf 'PASS: NetworkManager failures preserve recovery data and return failure.\n'
scenario=success
printf 'invalid-uuid\t3\n' >> "$STATE/profile-powersave.tsv"
if restore_profiles 2>/dev/null; then
    printf 'FAIL: invalid saved state was accepted.\n' >&2
    exit 1
fi
printf 'PASS: invalid recovery data is rejected.\n'
