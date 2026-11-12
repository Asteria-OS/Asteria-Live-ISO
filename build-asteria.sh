#!/usr/bin/env bash
# Build a copied profile in a fresh workspace without modifying mkarchiso.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
work_root="${ASTERIA_BUILD_WORK_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/asteria-build}"
mkdir -p "$work_root" "$repo_dir/out"

# The airootfs needs real Unix permissions, setuid bits and symlinks. Building
# on NTFS/FUSE with synthesized modes can produce an unusable and unsafe ISO.
probe="$(mktemp -d "$work_root/.fs-check.XXXXXXXX")"
trap 'rm -rf -- "$probe"' EXIT
touch "$probe/file"
chmod 600 "$probe/file"
if [[ "$(stat -c '%a' "$probe/file")" != 600 ]] ||
   ! ln -s file "$probe/link" || [[ "$(readlink "$probe/link")" != file ]]; then
    printf 'Build filesystem cannot preserve Unix permissions or symlinks: %s\n' "$work_root" >&2
    exit 1
fi
chmod 4755 "$probe/file"
if [[ "$(stat -c '%a' "$probe/file")" != 4755 ]]; then
    printf 'Build filesystem cannot preserve setuid permissions: %s\n' "$work_root" >&2
    exit 1
fi
rm -rf -- "$probe"
trap - EXIT

run_dir="$(mktemp -d "$work_root/asteria.XXXXXXXX")"
profile="$run_dir/profile"
work_dir="$run_dir/mkarchiso"
output_dir="$repo_dir/out/$(basename "$run_dir")"
mkdir -p "$work_dir" "$output_dir"

cp -a "$repo_dir/archiso" "$profile"
cp "$profile/packages_desktop.x86_64" "$profile/packages.x86_64"
date +%y%m%d > "$profile/airootfs/etc/version-tag"
printf 'desktop\n' > "$profile/airootfs/etc/edition-tag"
printf 'ZPOOL_VDEV_NAME_PATH=1\n' > "$profile/airootfs/etc/environment"
ln -sfn /usr/lib/systemd/system/plasmalogin.service "$profile/airootfs/etc/systemd/system/display-manager.service"
ln -sfn /dev/null "$profile/airootfs/etc/systemd/system/cachyos-rate-mirrors.timer"

printf 'Profile: %s\nWork: %s\nOutput: %s\n' "$profile" "$work_dir" "$output_dir"
printf '%s\n' 'Building with mkarchiso; package downloads and working user namespaces are required.'
mkarchiso -v -w "$work_dir" -o "$output_dir" "$profile"
rootfs="$work_dir/iso/arch/x86_64/airootfs.sfs"
if ! bash "$repo_dir/validate-rootfs.sh" "$rootfs"; then
    printf 'Build output failed metadata validation and must not be used: %s\n' "$output_dir" >&2
    exit 1
fi
printf 'Build completed. ISO output: %s\n' "$output_dir"
