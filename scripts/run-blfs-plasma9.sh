#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma9-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA9_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma9-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/bin/systemsettings" \
  "$LFS/opt/kf6/bin/knetattach" \
  "$LFS/opt/kf6/lib/plugins/platformthemes/KDEPlasmaPlatformTheme6.so" \
  "$LFS/opt/kf6/lib/cmake/KF6Screen/KF6ScreenConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaQuick/PlasmaQuickConfig.cmake"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/bin/kmenuedit" \
  "$LFS/opt/kf6/bin/kscreen-console" \
  "$LFS/opt/kf6/libexec/kscreen_osd_service"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in kmenuedit-6.4.4.tar.xz kscreen-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA9_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma9-chroot.sh" "$LFS/root/build-blfs-plasma9-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma9-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress; do
  if sudo -n test -f "$LFS/root/blfs-plasma9-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma9-$name.txt" >"$ARTIFACTS/blfs-plasma9-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA9_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma9-chroot.sh" \
  "$LFS/root/blfs-plasma9-report.txt" "$LFS/root/blfs-plasma9-progress.txt"
REPORT="$ARTIFACTS/blfs-plasma9-report.txt"
for expected in \
  'BLFS_PLASMA9_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-no-safe-version-only-entrypoint' \
  'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'QT=6.9.2' 'PLASMA_VERSION=6.4.4' 'PACKAGES=kmenuedit+kscreen' \
  'KMENUEDIT=6.4.4' 'KSCREEN=6.4.4' \
  'KMENUEDIT_EXEC=not-run-dbus-service-before-cli-parse' 'KMENUEDIT_WINDOW=not-created' \
  'KSCREEN_CONSOLE=not-run-would-request-display-backend' 'KSCREEN_CONFIG=not-queried' \
  'KSCREEN_OSD=installed-not-started' 'KSCREEN_KCM=built-not-loaded' 'KSCREEN_KDED=built-not-loaded' \
  'TEST_SUITES=not-run' 'SYSTEMD_USER_UNITS=removed-sysv-inapplicable' \
  'PLASMA8=preserved-pipeline-188' 'SYSTEMSETTINGS=preserved-version-only-not-opened' \
  'PLASMA_DESKTOP=preserved-not-rebuilt-not-running' 'ACTIVITY_SERVICE=preserved-not-started' \
  'KWIN=preserved-not-rebuilt-not-running' 'PLASMASHELL=not-started' \
  'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' \
  'NETWORK=not-used' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' \
  'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA9_BUILT=' "$ARTIFACTS/blfs-plasma9-progress.txt")" -eq 2 ]]
cat "$REPORT"
