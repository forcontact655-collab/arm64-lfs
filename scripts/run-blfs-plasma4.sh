#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma4-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() {
  printf 'BLFS_PLASMA4_PRECONDITION_FAILED=%s\n' "$1" >&2
  exit 1
}
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma4-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/bin/kwin_x11" \
  "$LFS/opt/kf6/bin/kwin_wayland" \
  "$LFS/opt/kf6/lib/cmake/KWinX11" \
  "$LFS/opt/kf6/lib/cmake/KWin" \
  "$LFS/opt/qt6/lib/cmake/Qt6Sensors" \
  "$LFS/usr/lib/libinput.so"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivitiesStats/PlasmaActivitiesStatsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KPipeWire/KPipeWireConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KScreenLocker/KScreenLockerConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake" \
  "$LFS/usr/lib/liblcms2.so" \
  "$LFS/usr/bin/Xvfb"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for name in qtsensors-everywhere-src-6.9.2.tar.xz libinput-1.29.0.tar.gz kwin-x11-6.4.4.tar.xz kwin-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA4_RUN_PRECONDITIONS=ok\n'
mkdir -p "$ARTIFACTS"
sudo -n true || preflight_fail sudo
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma4-chroot.sh" "$LFS/root/build-blfs-plasma4-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma4-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma4-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma4-$name.txt" >"$ARTIFACTS/blfs-plasma4-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA4_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma4-chroot.sh" \
  "$LFS/root/blfs-plasma4-report.txt" "$LFS/root/blfs-plasma4-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma4-report.txt"
for expected in \
  'BLFS_PLASMA4_RESULT=ok' 'PACKAGE_COUNT=4' 'SOURCE_COUNT=4' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA4_EXEC_OK+kwin-version' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA4_EXEC_OK=6.9.2=libinput-context=sensors-type' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=qtsensors+libinput+kwin-x11+kwin' \
  'QT_SENSORS=6.9.2' 'LIBINPUT=1.29.0' 'KWIN_X11=6.4.4' 'KWIN_WAYLAND=6.4.4' \
  'QT_SENSORS_SMOKE=native-typeinfo-no-backend' 'LIBINPUT_SMOKE=native-context-no-device' \
  'KWIN_X11_VERSION_STATUS=0' 'KWIN_X11_VERSION_OUTPUT=kwin 6.4.4' 'KWIN_X11_SMOKE=native-version-under-Xvfb-no-window-manager-start' \
  'KWIN_WAYLAND_VERSION_STATUS=0' 'KWIN_WAYLAND_VERSION_OUTPUT=kwin 6.4.4' 'KWIN_WAYLAND_SMOKE=native-version-no-compositor-start' \
  'QT_SENSORS_TEST_SUITE=not-run-QT_BUILD_TESTS_OFF' 'LIBINPUT_TEST_SUITE=disabled-no-hardware-test-stack' 'KWIN_TEST_SUITE=not-run-BUILD_TESTING_OFF' \
  'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' 'INPUT_RUNTIME=not-tested-no-devices' 'SENSOR_RUNTIME=not-tested-no-backend' \
  'PLASMA3=preserved-pipeline-176' 'PLASMA=kwin-built-not-running' 'KWIN=built-version-only-not-running' 'COMPOSITOR=not-started' 'PLASMA_WORKSPACE=not-built' 'PLASMA_DESKTOP=not-built' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA4_BUILT=' "$ARTIFACTS/blfs-plasma4-progress.txt")" -eq 4 ]]
cat "$REPORT"
