#!/usr/bin/env bash
# Check metadata that is essential for a functioning live ISO.
set -euo pipefail
if [[ $# -ne 1 || ! -f "$1" ]]; then
    printf 'Usage: bash %s /path/to/airootfs.sfs\n' "$0" >&2
    exit 2
fi
listing="$(unsquashfs -lln -max-depth 2 "$1" etc/shadow home/liveuser)"
sudo_listing="$(unsquashfs -lln -max-depth 3 "$1" usr/bin/sudo)"
check() {
    local entries="$1" path="$2" mode="$3" owner="$4"
    if ! awk -v p="squashfs-root/$path" -v m="$mode" -v o="$owner" \
        '$NF == p && $1 == m && $2 == o {found=1} END {exit !found}' <<< "$entries"; then
        printf 'Invalid or missing metadata: %s (expected %s %s)\n' "$path" "$mode" "$owner" >&2
        return 1
    fi
}
check "$listing" etc/shadow '-r--------' '0/0'
check "$listing" home/liveuser 'drwxr-x---' '1000/1000'
check "$sudo_listing" usr/bin/sudo '-rwsr-xr-x' '0/0'
printf 'Critical root filesystem metadata is valid.\n'
