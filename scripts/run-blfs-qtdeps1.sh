#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-qtdeps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-qtdeps1-sources/sources ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ -x "$LFS/usr/bin/cmake" ]]
[[ -f "$LFS/usr/lib/pkgconfig/egl.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/icu-uc.pc" ]]
[[ -f "$HOST_SOURCES/xcb-util-0.4.1.tar.xz" ]]
[[ -f "$HOST_SOURCES/double-conversion-3.3.1.tar.gz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-qtdeps1-chroot.sh" "$LFS/root/build-blfs-qtdeps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-qtdeps1-chroot.sh

cleanup
sudo -n cat "$LFS/root/blfs-qtdeps1-report.txt" >"$ARTIFACTS/blfs-qtdeps1-report.txt"
sudo -n cat "$LFS/root/blfs-qtdeps1-progress.txt" >"$ARTIFACTS/blfs-qtdeps1-progress.txt"
sudo -n rm -f "$LFS/root/build-blfs-qtdeps1-chroot.sh" "$LFS/root/blfs-qtdeps1-report.txt" "$LFS/root/blfs-qtdeps1-progress.txt"
grep -q '^BLFS_QTDEPS1_RESULT=ok$' "$ARTIFACTS/blfs-qtdeps1-report.txt"
grep -q '^PACKAGE_COUNT=7$' "$ARTIFACTS/blfs-qtdeps1-report.txt"
grep -q '^XCB_PACKAGES=6$' "$ARTIFACTS/blfs-qtdeps1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_QTDEPS1_EXEC_OK$' "$ARTIFACTS/blfs-qtdeps1-report.txt"
grep -q '^ICU_EXISTING=77.1$' "$ARTIFACTS/blfs-qtdeps1-report.txt"
grep -q '^MESA_EXISTING=25.1.8$' "$ARTIFACTS/blfs-qtdeps1-report.txt"
grep -q '^QT=absent$' "$ARTIFACTS/blfs-qtdeps1-report.txt"
[[ "$(grep -c '^BLFS_QTDEPS1_BUILT=' "$ARTIFACTS/blfs-qtdeps1-progress.txt")" -eq 7 ]]
cat "$ARTIFACTS/blfs-qtdeps1-report.txt"
trap - EXIT
