#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() {
  printf 'BLFS_PLASMA1_PRECONDITION_FAILED=%s\n' "$1" >&2
  exit 1
}
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma1-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake"; do
  [[ ! -e "$path" ]] || preflight_fail "existing-$path"
done
for path in \
  "$LFS/opt/qt6/lib/cmake/Qt6WaylandClient/Qt6WaylandClientConfig.cmake" \
  "$LFS/usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Package/KF6PackageConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Kirigami/KF6KirigamiConfig.cmake"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for name in kdecoration libkscreen libksysguard breeze breeze-gtk layer-shell-qt plasma-activities libplasma; do
  [[ -f "$HOST_SOURCES/$name-6.4.4.tar.xz" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA1_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma1-chroot.sh" "$LFS/root/build-blfs-plasma1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma1-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma1-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma1-$name.txt" >"$ARTIFACTS/blfs-plasma1-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA1_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma1-chroot.sh" \
  "$LFS/root/blfs-plasma1-report.txt" "$LFS/root/blfs-plasma1-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma1-report.txt"
for expected in \
  'BLFS_PLASMA1_RESULT=ok' 'PACKAGE_COUNT=8' 'SOURCE_COUNT=8' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA1_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA1_EXEC_OK=6.9.2=6.4.4=default' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=kdecoration+libkscreen+libksysguard+breeze+breeze-gtk+layer-shell-qt+plasma-activities+libplasma' \
  'KDECORATION=6.4.4' 'LIBKSCREEN=6.4.4' 'LIBKSYSGUARD=6.4.4' 'BREEZE=6.4.4' 'BREEZE_GTK=6.4.4' 'LAYER_SHELL_QT=6.4.4' 'PLASMA_ACTIVITIES=6.4.4' 'LIBPLASMA=6.4.4' \
  'NATIVE_SMOKE=cmake-targets+decoration-state+plasma-theme-offscreen' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' 'ACTIVITIES_RUNTIME=not-tested-no-service' \
  'PLASMA=core-libraries-built-not-running' 'PLASMA_DESKTOP=not-built' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA1_BUILT=' "$ARTIFACTS/blfs-plasma1-progress.txt")" -eq 8 ]]
cat "$REPORT"
