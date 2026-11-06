#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma14-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA14_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma14-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/qt6/lib/cmake/QCoro6/QCoro6Config.cmake" \
  "$LFS/usr/lib/cmake/PlasmaWaylandProtocols/PlasmaWaylandProtocolsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaActivities/PlasmaActivitiesConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/LibKWorkspace/LibKWorkspaceConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Screen/KF6ScreenConfig.cmake" \
  "$LFS/opt/kf6/libexec/polkit-kde-authentication-agent-1"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/libexec/org_kde_powerdevil" \
  "$LFS/opt/kf6/lib/libpowerdevilcore.so.6.4.4" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.battery" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.brightness"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -f "$HOST_SOURCES/powerdevil-6.4.4.tar.xz" ]] || preflight_fail missing-source-powerdevil
printf 'BLFS_PLASMA14_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma14-chroot.sh" "$LFS/root/build-blfs-plasma14-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma14-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma14-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma14-$name.txt" >"$ARTIFACTS/blfs-plasma14-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA14_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma14-chroot.sh" \
  "$LFS/root/blfs-plasma14-report.txt" "$LFS/root/blfs-plasma14-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma14-report.txt"
for expected in \
  'BLFS_PLASMA14_RESULT=ok' 'PACKAGE_COUNT=1' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-power-management-and-kauth-helpers' \
  'NEW_EXECUTABLES=org_kde_powerdevil+3-kauth-helpers-not-executed' 'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=powerdevil' 'POWERDEVIL=6.4.4' \
  'POWERDEVIL_DAEMON=built-elf-not-executed' 'POWERDEVIL_CORE=built-elf-not-loaded' \
  'POWERDEVIL_KCMS=built-not-loaded' 'POWERDEVIL_QML=built-not-loaded' 'POWERDEVIL_RUNNER=built-not-loaded' \
  'POWERDEVIL_PLASMOIDS=installed-not-loaded' 'KAUTH_HELPERS=installed-not-executed' 'KAUTH_HELPER_MODES=observed-in-host-log' \
  'UPOWER=not-connected' 'POWER_MANAGEMENT=not-activated' 'BRIGHTNESS=not-changed' 'SUSPEND=not-triggered' 'DDCUTIL=not-tested' \
  'TEST_SUITES=not-run' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA13=preserved-pipeline-197' 'POLKIT_AGENT=preserved-not-executed' 'WALLPAPERS=preserved-not-applied' \
  'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' \
  'PLASMA_DESKTOP=preserved-not-rebuilt-not-running' 'ACTIVITY_SERVICE=preserved-not-started' \
  'KWIN=preserved-not-rebuilt-not-running' 'PLASMASHELL=not-started' \
  'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' \
  'NETWORK=not-used' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA14_BUILT=' "$ARTIFACTS/blfs-plasma14-progress.txt")" -eq 1 ]]
cat "$REPORT"
