#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-display1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-display1-sources/sources ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ -x "$LFS/usr/bin/cmake" ]]
[[ -f "$LFS/usr/lib/pkgconfig/libpsl.pc" ]]
[[ -f "$HOST_SOURCES/harfbuzz-11.4.1.tar.xz" ]]
[[ -f "$HOST_SOURCES/wayland-1.24.0.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-display1-chroot.sh" "$LFS/root/build-blfs-display1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-display1-chroot.sh

cleanup
sudo -n cat "$LFS/root/blfs-display1-report.txt" >"$ARTIFACTS/blfs-display1-report.txt"
sudo -n cat "$LFS/root/blfs-display1-progress.txt" >"$ARTIFACTS/blfs-display1-progress.txt"
sudo -n rm -f "$LFS/root/build-blfs-display1-chroot.sh" "$LFS/root/blfs-display1-report.txt" "$LFS/root/blfs-display1-progress.txt"
grep -q '^BLFS_DISPLAY1_RESULT=ok$' "$ARTIFACTS/blfs-display1-report.txt"
grep -q '^PACKAGE_COUNT=16$' "$ARTIFACTS/blfs-display1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_DISPLAY1_EXEC_OK$' "$ARTIFACTS/blfs-display1-report.txt"
grep -q '^KDE=absent$' "$ARTIFACTS/blfs-display1-report.txt"
[[ "$(grep -c '^BLFS_DISPLAY1_BUILT=' "$ARTIFACTS/blfs-display1-progress.txt")" -eq 16 ]]
cat "$ARTIFACTS/blfs-display1-report.txt"
trap - EXIT
