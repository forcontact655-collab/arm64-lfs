#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma5-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA5_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma5-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/bin/kwin_x11" \
  "$LFS/opt/kf6/bin/kwin_wayland" \
  "$LFS/opt/kf6/lib/cmake/KWinDBusInterface/KWinDBusInterfaceConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/ScreenSaverDBusInterface/ScreenSaverDBusInterfaceConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaQuick/PlasmaQuickConfig.cmake" \
  "$LFS/opt/qt6/lib/cmake/Qt6Sensors/Qt6SensorsConfig.cmake" \
  "$LFS/usr/lib/libinput.so" \
  "$LFS/usr/lib/cmake/PolkitQt6-1/PolkitQt6-1Config.cmake"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/qt6/lib/cmake/Qt6Location/Qt6LocationConfig.cmake" \
  "$LFS/opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake" \
  "$LFS/opt/kf6/bin/plasmashell" \
  "$LFS/opt/kf6/lib/cmake/LibKWorkspace/LibKWorkspaceConfig.cmake"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in qtlocation-everywhere-src-6.9.2.tar.xz plasma-workspace-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA5_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma5-chroot.sh" "$LFS/root/build-blfs-plasma5-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma5-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma5-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma5-$name.txt" >"$ARTIFACTS/blfs-plasma5-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA5_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma5-chroot.sh" \
  "$LFS/root/blfs-plasma5-report.txt" "$LFS/root/blfs-plasma5-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma5-report.txt"
for expected in \
  'BLFS_PLASMA5_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA5_EXEC_OK' \
  'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA5_EXEC_OK=6.9.2=geo-coordinate=location-type=kworkspace-autostart-path' \
  'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=qtlocation+plasma-workspace' \
  'QTLOCATION=6.9.2' 'PLASMA_WORKSPACE=6.4.4' \
  'QT_LOCATION_SMOKE=native-coordinate-and-location-type-no-provider' \
  'KWORKSPACE_SMOKE=native-autostart-path-no-file-or-session' \
  'NATIVE_SMOKE=cmake-targets+execution-no-shell-or-session' \
  'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA4=preserved-pipeline-178' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMA=workspace-built-not-running' 'PLASMASHELL=built-not-started' 'STARTPLASMA=built-not-run' \
  'PLASMA_SHELL=not-started' 'PLASMA_DESKTOP=not-built' 'COMPOSITOR=not-started' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' \
  'CAMERA=not-accessed' 'SMOKE_NETWORK=not-used' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA5_BUILT=' "$ARTIFACTS/blfs-plasma5-progress.txt")" -eq 2 ]]
cat "$REPORT"
