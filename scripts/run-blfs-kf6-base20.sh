#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-kf6-base20-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-kf6-base20-sources/sources ]]
for path in Qt6Core Qt6Gui Qt6Widgets Qt6DBus Qt6Qml Qt6Quick Qt6Svg Qt6QuickControls2; do [[ -f "$LFS/opt/qt6/lib/cmake/$path/${path}Config.cmake" ]]; done
for path in KF6WindowSystem KF6Archive KF6Config KF6ColorScheme KF6CoreAddons KF6GuiAddons KF6KirigamiPlatform; do [[ -f "$LFS/opt/kf6/lib/cmake/$path/${path}Config.cmake" ]]; done
[[ -x "$LFS/usr/bin/dbus-run-session" ]]
[[ ! -e "$LFS/opt/kf6/lib/cmake/KF6StatusNotifierItem" && ! -e "$LFS/opt/kf6/lib/cmake/KF6Svg" ]]
for name in kstatusnotifieritem-6.17.0.tar.xz ksvg-6.17.0.tar.xz; do [[ -f "$HOST_SOURCES/$name" ]]; done
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-kf6-base20-chroot.sh" "$LFS/root/build-blfs-kf6-base20-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-kf6-base20-chroot.sh
cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-kf6-base20-$name.txt" >"$ARTIFACTS/blfs-kf6-base20-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-kf6-base20-chroot.sh" \
  "$LFS/root/blfs-kf6-base20-report.txt" "$LFS/root/blfs-kf6-base20-progress.txt"
REPORT="$ARTIFACTS/blfs-kf6-base20-report.txt"
for expected in \
  'BLFS_KF6_BASE20_RESULT=ok' 'PACKAGE_COUNT=2' 'DEPENDENCY_COUNT=0' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_KF6_BASE20_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_KF6_BASE20_EXEC_OK=6.9.2=notifier=properties=svg=render' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'ECM=6.17.0' 'KF6_VERSION=6.17.0' 'PACKAGES=kstatusnotifieritem+ksvg' 'DEPENDENCIES=none' \
  'STATUS_NOTIFIER=native-properties-private-dbus' 'SVG=native-offscreen-render' 'DBUS_SESSION=smoke-only-stopped' \
  'NETWORK_RUNTIME=not-tested' 'WINDOW_RUNTIME=not-tested-no-window-shown' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' \
  'BASE19=preserved-pipeline-138' 'BASE18=preserved-pipeline-136' 'PLASMA=absent' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_KF6_BASE20_BUILT=' "$ARTIFACTS/blfs-kf6-base20-progress.txt")" -eq 2 ]]
cat "$REPORT"
trap - EXIT
