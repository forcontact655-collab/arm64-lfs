#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma6-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA6_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma6-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/bin/plasmashell" \
  "$LFS/opt/kf6/bin/startplasma-x11" \
  "$LFS/opt/kf6/lib/cmake/LibKWorkspace/LibKWorkspaceConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/LibNotificationManager/LibNotificationManagerConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/LibTaskManager/LibTaskManagerConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/LibColorCorrect/LibColorCorrectConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KRunnerAppDBusInterface/KRunnerAppDBusInterfaceConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KSMServerDBusInterface/KSMServerDBusInterfaceConfig.cmake" \
  "$LFS/opt/qt6/lib/cmake/Qt6Location/Qt6LocationConfig.cmake" \
  "$LFS/opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/share/plasma/shells/org.kde.plasma.desktop" \
  "$LFS/opt/kf6/bin/knetattach" \
  "$LFS/usr/lib/libwacom.so"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in libwacom-2.16.1.tar.xz plasma-desktop-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA6_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma6-chroot.sh" "$LFS/root/build-blfs-plasma6-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma6-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma6-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma6-$name.txt" >"$ARTIFACTS/blfs-plasma6-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA6_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma6-chroot.sh" \
  "$LFS/root/blfs-plasma6-report.txt" "$LFS/root/blfs-plasma6-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma6-report.txt"
for expected in \
  'BLFS_PLASMA6_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=knetattach-version' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'KNETATTACH_VERSION_STATUS=0' 'KNETATTACH_VERSION_OUTPUT=knetattach 6.4.4' \
  'KNETATTACH_SMOKE=native-version-no-wizard-or-network' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=libwacom+plasma-desktop' 'LIBWACOM=2.16.1' 'PLASMA_DESKTOP=6.4.4' \
  'TABLET_KCM=built-with-libwacom-no-hardware' 'LIBWACOM_TESTS=disabled' 'INPUT_RUNTIME=not-tested-no-devices' \
  'SHELL_PACKAGE=org.kde.plasma.desktop-installed-not-started' \
  'TASKMANAGER_APPLET=installed-not-loaded' \
  'PLASMA_DESKTOP_TESTS=not-run-BUILD_TESTING_OFF' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA5=preserved-pipeline-180' 'PLASMA_WORKSPACE=preserved-pipeline-180' \
  'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMA=desktop-built-not-running' 'PLASMA_SHELL=not-started' 'PLASMASHELL=not-started' \
  'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'NETWORK=not-used-by-version-smoke' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' \
  'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA6_BUILT=' "$ARTIFACTS/blfs-plasma6-progress.txt")" -eq 2 ]]
cat "$REPORT"
