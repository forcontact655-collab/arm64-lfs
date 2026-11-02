#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-qt5compat1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-qt5compat1-sources/sources ]]
[[ -x "$LFS/opt/qt6/bin/qmake6" ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6ShaderTools/Qt6ShaderToolsConfig.cmake" ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6ShaderToolsTools/Qt6ShaderToolsToolsConfig.cmake" ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6Svg/Qt6SvgConfig.cmake" ]]
[[ -f "$HOST_SOURCES/qtdeclarative-everywhere-src-6.9.2.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-qt5compat1-chroot.sh" "$LFS/root/build-blfs-qt5compat1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-qt5compat1-chroot.sh

cleanup
for name in report progress config-summary; do
  sudo -n cat "$LFS/root/blfs-qt5compat1-$name.txt" >"$ARTIFACTS/blfs-qt5compat1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-qt5compat1-chroot.sh" \
  "$LFS/root/blfs-qt5compat1-report.txt" \
  "$LFS/root/blfs-qt5compat1-progress.txt" \
  "$LFS/root/blfs-qt5compat1-config-summary.txt"
grep -q '^BLFS_QTDECLARATIVE1_RESULT=ok$' "$ARTIFACTS/blfs-qt5compat1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-qt5compat1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_QTDECLARATIVE1_EXEC_OK$' "$ARTIFACTS/blfs-qt5compat1-report.txt"
grep -q '^QTDECLARATIVE=6.9.2$' "$ARTIFACTS/blfs-qt5compat1-report.txt"
grep -q '^QML_SMOKE=BLFS_QTDECLARATIVE1_EXEC_OK=6.9.2$' "$ARTIFACTS/blfs-qt5compat1-report.txt"
grep -q '^QUICK_CONTROLS=present$' "$ARTIFACTS/blfs-qt5compat1-report.txt"
grep -q '^KDE=absent$' "$ARTIFACTS/blfs-qt5compat1-report.txt"
[[ "$(grep -c '^BLFS_QTDECLARATIVE1_BUILT=' "$ARTIFACTS/blfs-qt5compat1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-qt5compat1-report.txt"
trap - EXIT
