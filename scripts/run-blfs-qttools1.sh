#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-qttools1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-qttools1-sources/sources ]]
[[ -x "$LFS/opt/qt6/bin/qmake6" ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6Qml/Qt6QmlConfig.cmake" ]]
[[ -f "$LFS/opt/qt6/lib/cmake/Qt6Quick/Qt6QuickConfig.cmake" ]]
[[ -f "$LFS/usr/share/ECM/cmake/ECMConfig.cmake" ]]
[[ -f "$HOST_SOURCES/qttools-everywhere-src-6.9.2.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-qttools1-chroot.sh" "$LFS/root/build-blfs-qttools1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-qttools1-chroot.sh

cleanup
for name in report progress config-summary; do
  sudo -n cat "$LFS/root/blfs-qttools1-$name.txt" >"$ARTIFACTS/blfs-qttools1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-qttools1-chroot.sh" \
  "$LFS/root/blfs-qttools1-report.txt" \
  "$LFS/root/blfs-qttools1-progress.txt" \
  "$LFS/root/blfs-qttools1-config-summary.txt"
grep -q '^BLFS_QTTOOLS1_RESULT=ok$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_QTTOOLS1_EXEC_OK$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^QT=6.9.2$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^QTTOOLS=6.9.2$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^ECM=6.17.0$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^LINGUIST_TOOLS=present$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^TRANSLATION_SMOKE=BLFS_QTTOOLS1_EXEC_OK=6.9.2=translation-ok$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^QDOC=disabled$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^DESIGNER=disabled$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^ASSISTANT=disabled$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^KDE=ecm-only$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^KDE_FRAMEWORKS=absent$' "$ARTIFACTS/blfs-qttools1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-qttools1-report.txt"
[[ "$(grep -c '^BLFS_QTTOOLS1_BUILT=' "$ARTIFACTS/blfs-qttools1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-qttools1-report.txt"
trap - EXIT
