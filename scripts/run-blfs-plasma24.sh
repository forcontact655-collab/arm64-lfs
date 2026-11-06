#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma24-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA24_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma24-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/Plasma/PlasmaConfig.cmake" \
  "$LFS/opt/kf6/share/sounds/oxygen/index.theme" \
  "$LFS/opt/kf6/share/sounds/ocean/index.theme"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/liboxygenstyle6.so.6.4.4" \
  "$LFS/opt/kf6/lib/liboxygenstyleconfig6.so.6.4.4" \
  "$LFS/opt/kf6/bin/oxygen-demo6" \
  "$LFS/opt/kf6/bin/oxygen-settings6" \
  "$LFS/opt/kf6/share/kstyle/themes/oxygen.themerc" \
  "$LFS/opt/kf6/share/plasma/look-and-feel/org.kde.oxygen" \
  "$LFS/opt/kf6/share/plasma/desktoptheme/oxygen" \
  "$LFS/opt/kf6/share/icons/Oxygen_Black"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
[[ -z "$(find "$LFS/opt/kf6/lib/plugins" -type f \( -path '*/styles/oxygen6.so' -o -path '*/kstyle_config/kstyle_oxygen_config.so' -o -path '*/org.kde.kdecoration3/org.kde.oxygen.so' -o -name 'kcm_oxygendecoration.so' \) -print -quit)" ]] || preflight_fail existing-oxygen-plugin
[[ -f "$HOST_SOURCES/oxygen-6.4.4.tar.xz" ]] || preflight_fail missing-source-oxygen
printf 'BLFS_PLASMA24_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma24-chroot.sh" "$LFS/root/build-blfs-plasma24-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma24-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress oxygen-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma24-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma24-$name.txt" >"$ARTIFACTS/blfs-plasma24-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA24_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma24-chroot.sh" \
  "$LFS/root/blfs-plasma24-report.txt" "$LFS/root/blfs-plasma24-progress.txt" \
  "$LFS/root/blfs-plasma24-oxygen-config.txt"
REPORT="$ARTIFACTS/blfs-plasma24-report.txt"
for expected in \
  'BLFS_PLASMA24_RESULT=ok' 'PACKAGE_COUNT=1' 'SOURCE_COUNT=1' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-oxygen-demo-settings-or-plugins' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' 'PACKAGES=oxygen' 'OXYGEN=6.4.4' 'ELF_FILE_COUNT=8' 'QT5_BUILD=disabled' \
  'OXYGEN_STYLE=installed-not-applied' 'OXYGEN_STYLE_CONFIG=installed-not-opened' 'OXYGEN_DECORATION=installed-not-loaded' 'OXYGEN_KCM=installed-not-opened' \
  'OXYGEN_DEMO=installed-not-executed' 'OXYGEN_SETTINGS=installed-not-executed' 'OXYGEN_LOOKANDFEEL=installed-not-applied' \
  'OXYGEN_CURSOR_THEMES=installed-not-applied' 'OXYGEN_DESKTOPTHEME=installed-not-applied' 'THEME_APPLICATION=not-run' \
  'WACOMTABLET=deferred-requires-xorg-wacom' 'TEST_SUITES=not-run' 'NETWORK=not-used-by-built-programs' \
  'PLASMA23=preserved-pipeline-213' 'SOUND_THEMES=preserved-pipeline-213-not-played' 'PLASMA22=preserved-pipeline-211' 'KDEPLASMA_ADDONS=preserved-pipeline-211-not-loaded' 'PLASMA_WELCOME=preserved-pipeline-211-not-opened' \
  'PLASMA21=preserved-pipeline-210' 'BLUEDEVIL=preserved-pipeline-210-not-started' 'PLASMA20=preserved-pipeline-209' \
  'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' 'SDDM=preserved-not-started' 'PLASMA_DESKTOP=preserved-pipeline-183-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA24_BUILT=' "$ARTIFACTS/blfs-plasma24-progress.txt")" -eq 1 ]]
grep -qx 'BLFS_PLASMA24_BUILT=oxygen-6.4.4' "$ARTIFACTS/blfs-plasma24-progress.txt"
grep -qx 'BUILD_QT5:BOOL=OFF' "$ARTIFACTS/blfs-plasma24-oxygen-config.txt"
grep -qx 'BUILD_QT6:BOOL=ON' "$ARTIFACTS/blfs-plasma24-oxygen-config.txt"
grep -qx 'OXYGEN_RUNTIME=not-started' "$ARTIFACTS/blfs-plasma24-oxygen-config.txt"
grep -qx 'THEME_APPLICATION=not-run' "$ARTIFACTS/blfs-plasma24-oxygen-config.txt"
cat "$REPORT"
