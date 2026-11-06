#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma31-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA31_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma31-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/opt/kf6/lib/cmake/KF6KCMUtils/KF6KCMUtilsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Notifications/KF6NotificationsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6DBusAddons/KF6DBusAddonsConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Auth/KF6AuthConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6I18n/KF6I18nConfig.cmake" \
  "$LFS/opt/qt6/lib/cmake/Qt6Test/Qt6TestConfig.cmake" \
  "$LFS/opt/kf6/bin/spectacle" \
  "$LFS/opt/kf6/lib/libKF6PrisonScanner.so.6.17.0" \
  "$LFS/opt/kf6/lib/liboxygenstyle6.so.6.4.4"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for name in libkbolt.so kcm_bolt.so kded_bolt.so libkcm_firewall_core.so kcm_firewall.so firewalldbackend.so ufwbackend.so kde_ufw_plugin_helper; do
  [[ -z "$(find "$LFS/opt/kf6" -type f -name "$name" -print -quit)" ]] || preflight_fail "existing-$name"
done
for name in plasma-thunderbolt-6.4.4.tar.xz plasma-firewall-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA31_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma31-chroot.sh" "$LFS/root/build-blfs-plasma31-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma31-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress thunderbolt-config firewall-config thunderbolt-install-manifest firewall-install-manifest; do
  if sudo -n test -f "$LFS/root/blfs-plasma31-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma31-$name.txt" >"$ARTIFACTS/blfs-plasma31-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA31_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma31-chroot.sh" \
  "$LFS/root/blfs-plasma31-report.txt" "$LFS/root/blfs-plasma31-progress.txt" \
  "$LFS/root/blfs-plasma31-thunderbolt-config.txt" "$LFS/root/blfs-plasma31-firewall-config.txt" \
  "$LFS/root/blfs-plasma31-thunderbolt-install-manifest.txt" "$LFS/root/blfs-plasma31-firewall-install-manifest.txt"
REPORT="$ARTIFACTS/blfs-plasma31-report.txt"
for expected in \
  'BLFS_PLASMA31_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-new-kcm-kded-library-or-helper-programs' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' \
  'PACKAGES=plasma-thunderbolt,plasma-firewall' 'PLASMA_THUNDERBOLT=6.4.4' 'PLASMA_FIREWALL=6.4.4' 'ELF_FILE_COUNT=8' 'BUILD_TESTING=OFF' \
  'QML_RESOURCES=15-embedded-not-run' 'QML_UI=not-started' 'BOLT_RUNTIME=not-started' 'THUNDERBOLT_DEVICES=not-accessed' 'KDED_MODULES=installed-not-loaded' \
  'FIREWALLD_BACKEND=compiled-not-contacted' 'UFW_BACKEND=compiled-not-used' 'FIREWALL_BACKENDS=installed-not-loaded' 'FIREWALL_RULES=not-read-or-changed' \
  'POLKIT_HELPERS=installed-not-executed' 'PYTHON_HELPERS=installed-not-executed' 'DBUS_ACTIVATION=not-performed' \
  'PLASMA31_PREVIOUS=failed-pipeline-221-six-elf-postcheck-eight-actual' 'DRKONQI=deferred-requires-systemd-journal-and-coredumpd' 'PLASMA_NM=deferred-requires-networkmanager-modemmanager-backends' 'WACOMTABLET=deferred-requires-xorg-wacom' \
  'OFFICIAL_PLASMA_ACTIVE=56' 'OFFICIAL_PLASMA_BUILDABLE_COVERED=53' 'OFFICIAL_PLASMA_DEFERRED=3' 'OFFICIAL_PLASMA_COMMENTED_OUT=13-not-in-blfs-install-order' \
  'TEST_SUITES=not-run' 'NETWORK=not-used-by-built-programs' 'PLASMA30=preserved-pipeline-220' 'SPECTACLE=preserved-pipeline-220-not-started' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA31_BUILT=' "$ARTIFACTS/blfs-plasma31-progress.txt")" -eq 2 ]]
grep -qx 'BLFS_PLASMA31_BUILT=plasma-thunderbolt-6.4.4' "$ARTIFACTS/blfs-plasma31-progress.txt"
grep -qx 'BLFS_PLASMA31_BUILT=plasma-firewall-6.4.4' "$ARTIFACTS/blfs-plasma31-progress.txt"
grep -qx 'BOLT_QML_RESOURCES=3-embedded-not-run' "$ARTIFACTS/blfs-plasma31-thunderbolt-config.txt"
grep -qx 'FIREWALL_QML_RESOURCES=12-embedded-not-run' "$ARTIFACTS/blfs-plasma31-firewall-config.txt"
grep -qx 'BUILD_FIREWALLD_BACKEND:BOOL=ON' "$ARTIFACTS/blfs-plasma31-firewall-config.txt"
grep -qx 'BUILD_UFW_BACKEND:BOOL=ON' "$ARTIFACTS/blfs-plasma31-firewall-config.txt"
BOLT_MANIFEST="$ARTIFACTS/blfs-plasma31-thunderbolt-install-manifest.txt"
FIREWALL_MANIFEST="$ARTIFACTS/blfs-plasma31-firewall-install-manifest.txt"
[[ -s "$BOLT_MANIFEST" && -s "$FIREWALL_MANIFEST" ]]
for name in libkbolt.so kcm_bolt.so kded_bolt.so; do grep -q "/$name$" "$BOLT_MANIFEST"; done
for name in libkcm_firewall_core.so kcm_firewall.so firewalldbackend.so ufwbackend.so kde_ufw_plugin_helper kde_ufw_plugin_helper.py; do grep -q "/$name$" "$FIREWALL_MANIFEST"; done
cat "$REPORT"
