#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma-kirigami-addons1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma-kirigami-addons1-sources/sources ]]
for path in Qt6Core Qt6Gui Qt6Qml Qt6Quick Qt6QuickControls2; do [[ -f "$LFS/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6Kirigami KF6GlobalAccel KF6I18n KF6Config KF6CoreAddons KF6GuiAddons; do [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ ! -e "$LFS/opt/kf6/lib/cmake/KF6KirigamiAddons" ]]
[[ -f "$HOST_SOURCES/kirigami-addons-1.9.0.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma-kirigami-addons1-chroot.sh" "$LFS/root/build-blfs-plasma-kirigami-addons1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma-kirigami-addons1-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-plasma-kirigami-addons1-$name.txt" >"$ARTIFACTS/blfs-plasma-kirigami-addons1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-plasma-kirigami-addons1-chroot.sh" \
  "$LFS/root/blfs-plasma-kirigami-addons1-report.txt" "$LFS/root/blfs-plasma-kirigami-addons1-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma-kirigami-addons1-report.txt"
for expected in \
  'BLFS_PLASMA_KIRIGAMI_ADDONS1_RESULT=ok' 'PACKAGE_COUNT=1' 'DEPENDENCY_COUNT=0' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA_KIRIGAMI_ADDONS1_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA_KIRIGAMI_ADDONS1_EXEC_OK=6.9.2=1.9.0=components=24' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KIRIGAMI_ADDONS=1.9.0' 'PACKAGES=kirigami-addons' 'DEPENDENCIES=none' \
  'QML=native-components-import-unshown' 'WINDOW_RUNTIME=not-tested-no-window-shown' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' \
  'BASE21=preserved-pipeline-143' 'PLASMA=not-built' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA_KIRIGAMI_ADDONS1_BUILT=' "$ARTIFACTS/blfs-plasma-kirigami-addons1-progress.txt")" -eq 1 ]]
cat "$REPORT"
trap - EXIT
