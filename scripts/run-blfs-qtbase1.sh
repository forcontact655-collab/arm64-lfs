#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-qtbase1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-qtbase1-sources/sources ]]
[[ -x "$LFS/usr/bin/g++" ]]
[[ -f "$LFS/usr/lib/cmake/double-conversion/double-conversionConfig.cmake" ]]
[[ -f "$LFS/usr/lib/pkgconfig/xcb-cursor.pc" ]]
[[ -f "$HOST_SOURCES/qtbase-everywhere-src-6.9.2.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-qtbase1-chroot.sh" "$LFS/root/build-blfs-qtbase1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-qtbase1-chroot.sh

cleanup
for name in report progress config-summary; do
  sudo -n cat "$LFS/root/blfs-qtbase1-$name.txt" >"$ARTIFACTS/blfs-qtbase1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-qtbase1-chroot.sh" \
  "$LFS/root/blfs-qtbase1-report.txt" \
  "$LFS/root/blfs-qtbase1-progress.txt" \
  "$LFS/root/blfs-qtbase1-config-summary.txt"
grep -q '^BLFS_QTBASE1_RESULT=ok$' "$ARTIFACTS/blfs-qtbase1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-qtbase1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_QTBASE1_EXEC_OK$' "$ARTIFACTS/blfs-qtbase1-report.txt"
grep -q '^QTBASE=6.9.2$' "$ARTIFACTS/blfs-qtbase1-report.txt"
grep -q '^SQLITE=bundled$' "$ARTIFACTS/blfs-qtbase1-report.txt"
grep -q '^QT_SMOKE=BLFS_QTBASE1_EXEC_OK=6.9.2$' "$ARTIFACTS/blfs-qtbase1-report.txt"
grep -q '^XCB_PLUGIN=present$' "$ARTIFACTS/blfs-qtbase1-report.txt"
grep -q '^KDE=absent$' "$ARTIFACTS/blfs-qtbase1-report.txt"
[[ "$(grep -c '^BLFS_QTBASE1_BUILT=' "$ARTIFACTS/blfs-qtbase1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-qtbase1-report.txt"
trap - EXIT
