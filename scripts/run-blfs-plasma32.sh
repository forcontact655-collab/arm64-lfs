#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma32-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA32_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma32-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/usr/bin/Xorg" \
  "$LFS/usr/lib/pkgconfig/xorg-server.pc" \
  "$LFS/usr/lib/libwacom.so" \
  "$LFS/usr/lib/pkgconfig/libwacom.pc" \
  "$LFS/usr/lib/libxcb-xinput.so" \
  "$LFS/opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake" \
  "$LFS/opt/kf6/lib/libkbolt.so" \
  "$LFS/opt/kf6/lib/libkcm_firewall_core.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/usr/lib/xorg/modules/input/wacom_drv.so" \
  "$LFS/usr/lib/pkgconfig/xorg-wacom.pc" \
  "$LFS/usr/bin/xsetwacom" \
  "$LFS/opt/kf6/bin/kde_wacom_tabletfinder" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/wacomtablet.so" \
  "$LFS/opt/kf6/lib/plugins/plasma5support/dataengine/plasma_engine_wacomtablet.so" \
  "$LFS/opt/kf6/lib/plugins/plasma/kcms/systemsettings_qwidgets/kcm_wacomtablet.so"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in xf86-input-wacom-1.2.3.tar.bz2 wacomtablet-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA32_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma32-chroot.sh" "$LFS/root/build-blfs-plasma32-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma32-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress driver-config wacomtablet-config driver-install-manifest wacomtablet-install-manifest; do
  if sudo -n test -f "$LFS/root/blfs-plasma32-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma32-$name.txt" >"$ARTIFACTS/blfs-plasma32-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA32_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma32-chroot.sh" \
  "$LFS/root/blfs-plasma32-report.txt" "$LFS/root/blfs-plasma32-progress.txt" \
  "$LFS/root/blfs-plasma32-driver-config.txt" "$LFS/root/blfs-plasma32-wacomtablet-config.txt" \
  "$LFS/root/blfs-plasma32-driver-install-manifest.txt" "$LFS/root/blfs-plasma32-wacomtablet-install-manifest.txt"
REPORT="$ARTIFACTS/blfs-plasma32-report.txt"
for expected in \
  'BLFS_PLASMA32_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-new-driver-tools-kcm-kded-dataengine-or-tabletfinder' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' \
  'PACKAGES=xf86-input-wacom,wacomtablet' 'XORG_WACOM=1.2.3' 'WACOMTABLET=6.4.4' 'ELF_FILE_COUNT=8' 'BUILD_TESTING=OFF' \
  'DRIVER_TESTS=not-run-disabled' 'DRIVER_SYSTEMD_UNIT=not-installed' 'XORG_DRIVER=installed-not-loaded' 'XSETWACOM=installed-not-executed' 'UDEV_RULES=installed-not-reloaded' \
  'WACOMTABLET_RUNTIME=not-started' 'QML_APPLET=installed-not-loaded' 'QML_UI=not-started' 'KDED_MODULES=installed-not-loaded' 'DATAENGINE=installed-not-loaded' 'DBUS_SERVICES=installed-not-activated' 'TABLET_DEVICES=not-accessed' 'INPUT_RUNTIME=not-tested' \
  'OFFICIAL_PLASMA_ACTIVE=56' 'OFFICIAL_PLASMA_BUILDABLE_COVERED=54' 'OFFICIAL_PLASMA_DEFERRED=2' 'OFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order' \
  'DRKONQI=deferred-requires-systemd-journal-and-coredumpd' 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' 'PLASMA31=preserved-pipeline-222' \
  'TEST_SUITES=not-run' 'NETWORK=not-used-by-built-programs' 'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA32_BUILT=' "$ARTIFACTS/blfs-plasma32-progress.txt")" -eq 2 ]]
grep -qx 'BLFS_PLASMA32_BUILT=xf86-input-wacom-1.2.3' "$ARTIFACTS/blfs-plasma32-progress.txt"
grep -qx 'BLFS_PLASMA32_BUILT=wacomtablet-6.4.4' "$ARTIFACTS/blfs-plasma32-progress.txt"
DRIVER_CONFIG="$ARTIFACTS/blfs-plasma32-driver-config.txt"
TABLET_CONFIG="$ARTIFACTS/blfs-plasma32-wacomtablet-config.txt"
for expected in 'XORG_WACOM_VERSION=1.2.3' 'XORG_SERVER_VERSION=21.1.18' 'DRIVER_TESTS=not-run-disabled' 'DRIVER_SYSTEMD_UNIT=not-installed' 'XORG_DRIVER=installed-not-loaded' 'XSETWACOM=installed-not-executed' 'UDEV_RULES=installed-not-reloaded' 'TABLET_DEVICES=not-accessed'; do
  grep -qxF "$expected" "$DRIVER_CONFIG"
done
for expected in 'BUILD_TESTING:BOOL=OFF' 'LIBWACOM_VERSION=2.16.1' 'XORGWACOM_VERSION=1.2.3' 'WACOMTABLET_RUNTIME=not-started' 'QML_UI=not-started' 'KDED_MODULES=installed-not-loaded' 'DATAENGINE=installed-not-loaded' 'TABLET_DEVICES=not-accessed'; do
  grep -qxF "$expected" "$TABLET_CONFIG"
done
DRIVER_MANIFEST="$ARTIFACTS/blfs-plasma32-driver-install-manifest.txt"
TABLET_MANIFEST="$ARTIFACTS/blfs-plasma32-wacomtablet-install-manifest.txt"
[[ -s "$DRIVER_MANIFEST" && -s "$TABLET_MANIFEST" ]]
for path in \
  /usr/lib/xorg/modules/input/wacom_drv.so \
  /usr/lib/pkgconfig/xorg-wacom.pc \
  /usr/bin/xsetwacom \
  /usr/bin/isdv4-serial-debugger \
  /usr/bin/isdv4-serial-inputattach \
  /usr/lib/udev/rules.d/wacom.rules; do
  grep -qxF "$path" "$DRIVER_MANIFEST"
done
grep -q '/70-wacom.conf$' "$DRIVER_MANIFEST"
for path in \
  /opt/kf6/lib/plugins/plasma/kcms/systemsettings_qwidgets/kcm_wacomtablet.so \
  /opt/kf6/lib/plugins/kf6/kded/wacomtablet.so \
  /opt/kf6/lib/plugins/plasma5support/dataengine/plasma_engine_wacomtablet.so \
  /opt/kf6/bin/kde_wacom_tabletfinder; do
  grep -qxF "$path" "$TABLET_MANIFEST"
done
cat "$REPORT"
