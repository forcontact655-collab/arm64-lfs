#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma22-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA22_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma22-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/qt6/lib/cmake/Qt6Core5Compat/Qt6Core5CompatConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Runner/KF6RunnerConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Holidays/KF6HolidaysConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6UnitConversion/KF6UnitConversionConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KirigamiAddons/KF6KirigamiAddonsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma5Support/Plasma5SupportConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/PlasmaQuick/PlasmaQuickConfig.cmake" \
  "$LFS/opt/kf6/lib/plugins/plasma/kcms/systemsettings/kcm_bluetooth.so"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/qml/org/kde/plasma/private/colorpicker" \
  "$LFS/opt/kf6/lib/qml/org/kde/plasma/private/profiles" \
  "$LFS/opt/kf6/lib/plugins/kf6/krunner/krunner_dictionary.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/krunner/unitconverter.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/kameleon.so" \
  "$LFS/opt/kf6/libexec/kf6/kauth/kameleonhelper" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.colorpicker" \
  "$LFS/opt/kf6/share/plasma/plasmoids/org.kde.plasma.binaryclock" \
  "$LFS/opt/kf6/bin/plasma-welcome" \
  "$LFS/opt/kf6/share/applications/org.kde.plasma-welcome.desktop"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -z "$(find "$LFS/opt/kf6/lib/plugins/kf6/kded" -maxdepth 1 -name '*plasma-welcome*.so' -print -quit)" ]] || preflight_fail existing-welcome-kded
for name in kdeplasma-addons-6.4.4.tar.xz plasma-welcome-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA22_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma22-chroot.sh" "$LFS/root/build-blfs-plasma22-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma22-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress addons-config welcome-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma22-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma22-$name.txt" >"$ARTIFACTS/blfs-plasma22-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA22_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma22-chroot.sh" \
  "$LFS/root/blfs-plasma22-report.txt" "$LFS/root/blfs-plasma22-progress.txt" \
  "$LFS/root/blfs-plasma22-addons-config.txt" "$LFS/root/blfs-plasma22-welcome-config.txt"
REPORT="$ARTIFACTS/blfs-plasma22-report.txt"
for expected in \
  'BLFS_PLASMA22_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-welcome-kameleon-helper-or-plugins' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' 'PACKAGES=kdeplasma-addons+plasma-welcome' 'ELF_FILE_COUNT=8' \
  'KDEPLASMA_ADDONS=6.4.4' 'COLORPICKER_QML=installed-not-imported' 'PROFILES_QML=installed-not-imported' 'APPLETS=installed-not-added' \
  'KRUNNER_DICTIONARY=installed-not-queried' 'KRUNNER_CONVERTER=installed-not-queried' 'KRUNNER=not-started' \
  'KAMELEON=installed-not-loaded' 'KAMELEON_HELPER=installed-not-executed' 'DEVICE_LEDS=not-accessed' 'KAUTH=not-run' 'POLKIT=not-used' \
  'PLASMA_WELCOME=6.4.4' 'WELCOME_EXECUTABLE=installed-not-executed' 'WELCOME_KDED=installed-not-loaded' 'WELCOME_QML=build-graph-verified-not-run' 'USER_FEEDBACK=not-started' \
  'KWIN_ADDONS=not-executed' 'APPIUM_TESTS=not-run' 'TEST_SUITES=not-run' 'NETWORK=not-used-by-built-programs' \
  'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' 'PLASMA21=preserved-pipeline-210' 'BLUEDEVIL=preserved-pipeline-210-not-started' \
  'PLASMA20=preserved-pipeline-209' 'PLASMA_DISKS=preserved-pipeline-209-not-opened' 'KDE_GTK_CONFIG=preserved-pipeline-209-not-applied' \
  'KSYSTEMSTATS=preserved-pipeline-207-not-executed' 'QQC2_BREEZE_STYLE=preserved-pipeline-207-not-loaded' 'SYSTEMMONITOR=preserved-pipeline-206-not-opened' \
  'PLASMA19=preserved-pipeline-207' 'PLASMA18=preserved-pipeline-206' 'PLASMA17=preserved-pipeline-204' 'SDDM=preserved-not-started' \
  'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA22_BUILT=' "$ARTIFACTS/blfs-plasma22-progress.txt")" -eq 2 ]]
grep -qx 'BLFS_PLASMA22_BUILT=kdeplasma-addons-6.4.4' "$ARTIFACTS/blfs-plasma22-progress.txt"
grep -qx 'BLFS_PLASMA22_BUILT=plasma-welcome-6.4.4' "$ARTIFACTS/blfs-plasma22-progress.txt"
grep -Eq '^Plasma5Support_DIR:PATH=/opt/kf6/lib/cmake/Plasma5Support$' "$ARTIFACTS/blfs-plasma22-addons-config.txt"
grep -Eq '^PlasmaQuick_DIR:PATH=/opt/kf6/lib/cmake/PlasmaQuick$' "$ARTIFACTS/blfs-plasma22-addons-config.txt"
grep -qx 'KAMELEON_HELPER=not-executed' "$ARTIFACTS/blfs-plasma22-addons-config.txt"
grep -qx 'DEVICE_LEDS=not-accessed' "$ARTIFACTS/blfs-plasma22-addons-config.txt"
grep -Eq '^KF6KirigamiAddons_DIR:PATH=/opt/kf6/lib/cmake/KF6KirigamiAddons$' "$ARTIFACTS/blfs-plasma22-welcome-config.txt"
grep -qx 'WELCOME_RUNTIME=not-started' "$ARTIFACTS/blfs-plasma22-welcome-config.txt"
grep -qx 'WELCOME_QML=build-graph-verified-not-run' "$ARTIFACTS/blfs-plasma22-welcome-config.txt"
cat "$REPORT"
