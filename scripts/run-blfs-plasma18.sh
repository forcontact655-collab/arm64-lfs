#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma18-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA18_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma18-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/usr/include/cups/cups.h" \
  "$LFS/usr/lib/libcups.so.2" \
  "$LFS/opt/qt6/include/QtPrintSupport/6.9.2/QtPrintSupport/private/qcups_p.h" \
  "$LFS/opt/qt6/plugins/printsupport/libcupsprintersupport.so" \
  "$LFS/opt/kf6/libexec/xdg-desktop-portal-kde" \
  "$LFS/opt/kf6/share/xdg-desktop-portal/portals/kde.portal" \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KSysGuard/KSysGuardConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KirigamiAddons/KF6KirigamiAddonsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/plasmavault.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/bin/kde-print-queue" \
  "$LFS/opt/kf6/bin/configure-printer" \
  "$LFS/opt/kf6/bin/plasma-systemmonitor" \
  "$LFS/opt/kf6/lib/libkcupslib.so.6.4.4" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/printmanager.so" \
  "$LFS/opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_printer_manager.so" \
  "$LFS/opt/kf6/lib/qml/org/kde/plasma/printmanager" \
  "$LFS/opt/kf6/lib/qml/org/kde/systemmonitor" \
  "$LFS/opt/kf6/lib/qml/org/kde/ksysguard/page" \
  "$LFS/opt/kf6/lib/qml/org/kde/ksysguard/table" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.printmanager" \
  "$LFS/opt/kf6/share/ksysguard/sensorfaces/org.kde.ksysguard.applicationstable" \
  "$LFS/opt/kf6/share/ksysguard/sensorfaces/org.kde.ksysguard.processtable"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in print-manager-6.4.4.tar.xz plasma-systemmonitor-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA18_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma18-chroot.sh" "$LFS/root/build-blfs-plasma18-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma18-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress print-manager-config systemmonitor-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma18-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma18-$name.txt" >"$ARTIFACTS/blfs-plasma18-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA18_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma18-chroot.sh" \
  "$LFS/root/blfs-plasma18-report.txt" "$LFS/root/blfs-plasma18-progress.txt" \
  "$LFS/root/blfs-plasma18-print-manager-config.txt" "$LFS/root/blfs-plasma18-systemmonitor-config.txt"
REPORT="$ARTIFACTS/blfs-plasma18-report.txt"
for expected in \
  'BLFS_PLASMA18_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-print-manager-or-systemmonitor' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' \
  'PLASMA_VERSION=6.4.4' 'PACKAGES=print-manager+plasma-systemmonitor' \
  'PRINT_MANAGER=6.4.4' 'KCUPSLIB=installed-linked-libcups' 'CUPS=2.4.12-preserved-pipeline-204' 'CUPSD=preserved-not-executed' \
  'PRINT_MANAGER_KCM=installed-not-opened' 'PRINT_MANAGER_KDED=installed-not-loaded' 'PRINT_MANAGER_PLASMOID=installed-not-loaded' 'PRINT_MANAGER_TOOLS=installed-not-executed' \
  'SCP_INSTALL=disabled-verified-cache-and-source-exclusion' 'PACKAGEKIT_INSTALLER=disabled' 'SMB_PRINTING=not-tested' \
  'PRINT_TOOLS=not-run' 'PRINT_JOBS=not-created' 'PRINTERS=not-configured' 'PRINTING=not-tested' \
  'SYSTEMMONITOR=6.4.4' 'SYSTEMMONITOR_EXECUTABLE=installed-not-executed' 'SYSTEMMONITOR_QML=installed-not-loaded' 'QML_PLUGIN_COUNT=4' 'SENSOR_FACES=installed-not-loaded' \
  'KSYSGUARD=required-build-dependency-verified' 'KSYSTEMSTATS=not-started-runtime-unverified' 'SENSORS=not-queried' 'PROCESSES=not-listed-or-signalled' 'SYSTEMMONITOR_UI=not-opened' \
  'TEST_SUITES=not-run' 'PLASMA17=preserved-pipeline-204' 'XDG_PORTAL_KDE=preserved-not-activated' 'PLASMA16=preserved-pipeline-201' 'PLASMA15=preserved-pipeline-199' \
  'SDDM=preserved-not-started' 'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'KDED=not-started' \
  'NETWORK=not-used-by-built-programs' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA18_BUILT=' "$ARTIFACTS/blfs-plasma18-progress.txt")" -eq 2 ]]
grep -qx 'SCP_INSTALL:BOOL=OFF' "$ARTIFACTS/blfs-plasma18-print-manager-config.txt"
grep -qx 'CUPS_HEADER_VERSION=2.4.12' "$ARTIFACTS/blfs-plasma18-print-manager-config.txt"
grep -qx 'SCP_INSTALL_SOURCE=excluded' "$ARTIFACTS/blfs-plasma18-print-manager-config.txt"
grep -Eq '^KSysGuard_DIR(:[^=]+)?=/opt/kf6/' "$ARTIFACTS/blfs-plasma18-systemmonitor-config.txt"
grep -qx 'SYSTEMMONITOR_RUNTIME=not-started' "$ARTIFACTS/blfs-plasma18-systemmonitor-config.txt"
cat "$REPORT"
