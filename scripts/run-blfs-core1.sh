#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-sources/sources ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ -x "$LFS/usr/bin/meson" ]]
[[ -f "$HOST_SOURCES/glib-2.84.4.tar.xz" ]]
[[ -f "$HOST_SOURCES/cmake-4.1.0.tar.gz" ]]
mkdir -p "$ARTIFACTS"
sudo -n true

cleanup() {
  set +e
  local path
  for path in "$LFS/sources" "$LFS/etc/resolv.conf" "$LFS/dev/pts" "$LFS/sys" "$LFS/proc" "$LFS/run" "$LFS/dev"; do
    if mountpoint -q "$path"; then sudo -n umount "$path"; fi
  done
  if [[ -d "$HOST_SOURCES" ]]; then sudo -n chown -R "$(id -u):$(id -g)" "$HOST_SOURCES"; fi
  set -e
}
trap cleanup EXIT
sudo -n chown -R root:root "$LFS"
sudo -n mkdir -p "$LFS"/{dev,proc,sys,run,sources}
sudo -n install -m 0755 "$REPO/scripts/build-blfs-core1-chroot.sh" "$LFS/root/build-blfs-core1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n rm -f "$LFS/etc/resolv.conf"
sudo -n touch "$LFS/etc/resolv.conf"
sudo -n mount --bind /etc/resolv.conf "$LFS/etc/resolv.conf"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-core1-chroot.sh

cleanup
sudo -n cat "$LFS/root/blfs-core1-report.txt" >"$ARTIFACTS/blfs-core1-report.txt"
sudo -n cat "$LFS/root/blfs-core1-progress.txt" >"$ARTIFACTS/blfs-core1-progress.txt"
sudo -n rm -f "$LFS/root/build-blfs-core1-chroot.sh" "$LFS/root/blfs-core1-report.txt" "$LFS/root/blfs-core1-progress.txt"
grep -q '^BLFS_CORE1_RESULT=ok$' "$ARTIFACTS/blfs-core1-report.txt"
grep -q '^PACKAGE_COUNT=15$' "$ARTIFACTS/blfs-core1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_CORE1_EXEC_OK$' "$ARTIFACTS/blfs-core1-report.txt"
grep -q '^KDE=absent$' "$ARTIFACTS/blfs-core1-report.txt"
[[ "$(grep -c '^BLFS_CORE1_BUILT=' "$ARTIFACTS/blfs-core1-progress.txt")" -eq 15 ]]
cat "$ARTIFACTS/blfs-core1-report.txt"
trap - EXIT
