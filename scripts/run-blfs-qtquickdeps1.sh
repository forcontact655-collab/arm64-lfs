#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-qtquickdeps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-qtquickdeps1-sources/sources ]]
[[ -x "$LFS/opt/qt6/bin/qmake6" ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6/Qt6Config.cmake" ]]
[[ -f "$HOST_SOURCES/qtshadertools-everywhere-src-6.9.2.tar.xz" ]]
[[ -f "$HOST_SOURCES/qtsvg-everywhere-src-6.9.2.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-qtquickdeps1-chroot.sh" "$LFS/root/build-blfs-qtquickdeps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-qtquickdeps1-chroot.sh

cleanup
for name in report progress config-summary-qtshadertools config-summary-qtsvg; do
  sudo -n cat "$LFS/root/blfs-qtquickdeps1-$name.txt" >"$ARTIFACTS/blfs-qtquickdeps1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-qtquickdeps1-chroot.sh" \
  "$LFS/root/blfs-qtquickdeps1-report.txt" \
  "$LFS/root/blfs-qtquickdeps1-progress.txt" \
  "$LFS/root/blfs-qtquickdeps1-config-summary-qtshadertools.txt" \
  "$LFS/root/blfs-qtquickdeps1-config-summary-qtsvg.txt"
grep -q '^BLFS_QTQUICKDEPS1_RESULT=ok$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
grep -q '^PACKAGE_COUNT=2$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_QTQUICKDEPS1_EXEC_OK$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
grep -q '^QTSHADERTOOLS=6.9.2$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
grep -q '^QTSVG=6.9.2$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
grep -q '^SVG_SMOKE=BLFS_QTQUICKDEPS1_EXEC_OK=6.9.2$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
grep -q '^SVG_IMAGE_PLUGIN=present$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
grep -q '^KDE=absent$' "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
[[ "$(grep -c '^BLFS_QTQUICKDEPS1_BUILT=' "$ARTIFACTS/blfs-qtquickdeps1-progress.txt")" -eq 2 ]]
cat "$ARTIFACTS/blfs-qtquickdeps1-report.txt"
trap - EXIT
