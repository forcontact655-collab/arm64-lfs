#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma2-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() {
  printf 'BLFS_PLASMA2_PRECONDITION_FAILED=%s\n' "$1" >&2
  exit 1
}
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma2-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Package/KF6PackageConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Screen/KF6ScreenConfig.cmake" \
  "$LFS/usr/lib/libsensors.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/cmake/KScreenLocker/KScreenLockerConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KGlobalAccelD/KGlobalAccelDConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KWayland/KWaylandConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Aurorae/AuroraeConfig.cmake" \
  "$LFS/opt/kf6/bin/kinfocenter" \
  "$LFS/usr/include/security/pam_appl.h" \
  "$LFS/usr/lib64/libpam.so"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -f "$HOST_SOURCES/Linux-PAM-1.7.1.tar.xz" ]] || preflight_fail missing-source-linux-pam
for name in kscreenlocker kinfocenter kglobalacceld kwayland aurorae; do
  [[ -f "$HOST_SOURCES/$name-6.4.4.tar.xz" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA2_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma2-chroot.sh" "$LFS/root/build-blfs-plasma2-chroot.sh"
sudo -n install -m 0644 "$REPO/scripts/blfs-plasma2-kinfocenter-opengl-only.patch" "$LFS/root/blfs-plasma2-kinfocenter-opengl-only.patch"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma2-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma2-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma2-$name.txt" >"$ARTIFACTS/blfs-plasma2-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA2_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma2-chroot.sh" \
  "$LFS/root/blfs-plasma2-kinfocenter-opengl-only.patch" \
  "$LFS/root/blfs-plasma2-report.txt" "$LFS/root/blfs-plasma2-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma2-report.txt"
for expected in \
  'BLFS_PLASMA2_RESULT=ok' 'PACKAGE_COUNT=6' 'SOURCE_COUNT=6' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=BLFS_PLASMA2_EXEC_OK' 'NATIVE_SMOKE_OUTPUT=BLFS_PLASMA2_EXEC_OK=6.9.2=6.4.4=pam-success=locker-type=accel-type=kwayland-object=aurorae-metadata' 'NATIVE_SMOKE_STATUS=0' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'LINUX_PAM=1.7.1' 'PACKAGES=linux-pam+kscreenlocker+kinfocenter+kglobalacceld+kwayland+aurorae' \
  'KSCREENLOCKER=6.4.4' 'KINFOCENTER=6.4.4' 'KGLOBALACCELD=6.4.4' 'KWAYLAND=6.4.4' 'AURORAE=6.4.4' \
  'LINUX_PAM_TEST_SUITE=ninja-test-passed' 'PAM_LIBDIR=/usr/lib64' 'PAM_SMOKE=native-strerror-no-auth' 'PAM_CONFIG=standard-files-present-or-created' 'KSCREENLOCKER_SMOKE=native-typeinfo-no-lock-no-dbus' 'KINFOCENTER_SMOKE=library-qml-and-symlink-only' 'KINFOCENTER_VULKAN=disabled-qt-vulkan-unavailable-opengl-only' 'KINFOCENTER_OPENGL_HELPER=installed-not-run-no-display' 'KINFOCENTER_LAUNCHER=deferred-systemsettings-not-built' \
  'KGLOBALACCELD_VERSION_EXEC=passed-6.17.0-kf6-version-no-dbus-registration' 'KWAYLAND_SMOKE=native-object-no-compositor' 'AURORAE_SMOKE=native-plugin-metadata-not-loaded' \
  'NATIVE_SMOKE=cmake-targets+pam-strerror+typeinfo+kwayland-object+aurorae-metadata' 'TEST_SUITES=not-run-BUILD_TESTING_OFF' \
  'PLASMA1=preserved-pipeline-163' 'PLASMA=core-libraries-and-second-stage-built-not-running' 'PLASMA_DESKTOP=not-built' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA2_BUILT=' "$ARTIFACTS/blfs-plasma2-progress.txt")" -eq 6 ]]
cat "$REPORT"
