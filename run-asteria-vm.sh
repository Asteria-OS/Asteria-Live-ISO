#!/usr/bin/env bash
# Start the Asteria ISO with a disposable VM disk, never a host disk.
set -euo pipefail
if [[ $# -ne 1 || ! -f "$1" ]]; then
    printf 'Usage: bash %s /path/to/asteriaos.iso\n' "$0" >&2
    exit 2
fi
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
vm_dir="$repo_dir/work/test-vm"
mkdir -p "$vm_dir"
disk="$vm_dir/asteria-test.qcow2"
vars="$vm_dir/OVMF_VARS.fd"
code=/usr/share/edk2/x64/OVMF_CODE.4m.fd
template=/usr/share/edk2/x64/OVMF_VARS.4m.fd
if [[ ! -r "$code" || ! -r "$template" ]]; then
    printf 'UEFI firmware not found under /usr/share/edk2/x64.\n' >&2
    exit 1
fi
[[ -e "$disk" ]] || qemu-img create -f qcow2 "$disk" 48G
[[ -e "$vars" ]] || cp "$template" "$vars"
args=(-machine q35 -m "${ASTERIA_VM_MEMORY:-4096}" -smp "${ASTERIA_VM_CPUS:-4}"
      -drive "if=pflash,format=raw,readonly=on,file=$code"
      -drive "if=pflash,format=raw,file=$vars"
      -drive "file=$disk,format=qcow2,if=virtio"
      -drive "file=$1,media=cdrom,readonly=on"
      -nic user,model=virtio-net-pci -boot menu=on)
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    args+=(-accel kvm -cpu host)
else
    printf 'KVM unavailable; using slower software emulation.\n' >&2
    args+=(-accel tcg -cpu max)
fi
exec qemu-system-x86_64 "${args[@]}"
