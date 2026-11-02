#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-mesa1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-mesa1-sources/sources ]]
[[ -x "$LFS/usr/bin/llvm-config" ]]
[[ -f "$LFS/usr/lib/pkgconfig/libdrm.pc" ]]
[[ -f "$HOST_SOURCES/mesa-25.1.8.tar.xz" ]]
mkdir -p "$ARTIFACTS"
sudo -n true

cleanup() {
  set +e
  local path
  for path in "$LFS/sources" "$LFS/dev/pts" "$LFS/sys" "$LFS/proc" "$LFS/run" "$LFS/dev"; do
    if mountpoint -q "$path"; then sudo -n umount "$path"; fi
  done
  if [[ -d "$HOST_SOURCES" ]]; then sudo -n chown -R "$(id -u):$(id -g)" "$HOST_SOURCES"; fi
  set -e
}
trap cleanup EXIT
sudo -n chown -R root:root "$LFS"
sudo -n mkdir -p "$LFS"/{dev,proc,sys,run,sources}
sudo -n install -m 0755 "$REPO/scripts/build-blfs-mesa1-chroot.sh" "$LFS/root/build-blfs-mesa1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-mesa1-chroot.sh

cleanup
sudo -n cat "$LFS/root/blfs-mesa1-report.txt" >"$ARTIFACTS/blfs-mesa1-report.txt"
sudo -n cat "$LFS/root/blfs-mesa1-progress.txt" >"$ARTIFACTS/blfs-mesa1-progress.txt"
sudo -n rm -f "$LFS/root/build-blfs-mesa1-chroot.sh" "$LFS/root/blfs-mesa1-report.txt" "$LFS/root/blfs-mesa1-progress.txt"
grep -q '^BLFS_MESA1_RESULT=ok$' "$ARTIFACTS/blfs-mesa1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-mesa1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_MESA1_EXEC_OK$' "$ARTIFACTS/blfs-mesa1-report.txt"
grep -q '^GL_RENDERER=.' "$ARTIFACTS/blfs-mesa1-report.txt"
grep -q '^VULKAN=absent$' "$ARTIFACTS/blfs-mesa1-report.txt"
grep -q '^VULKAN_ICD_ENTRIES=0$' "$ARTIFACTS/blfs-mesa1-report.txt"
grep -q '^OPENCL=absent$' "$ARTIFACTS/blfs-mesa1-report.txt"
grep -q '^GALLIUM_DRIVERS=llvmpipe$' "$ARTIFACTS/blfs-mesa1-report.txt"
[[ "$(grep -c '^BLFS_MESA1_BUILT=' "$ARTIFACTS/blfs-mesa1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-mesa1-report.txt"
trap - EXIT
