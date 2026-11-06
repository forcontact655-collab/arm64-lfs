#!/usr/bin/env bash
set -euo pipefail
export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-plasma20-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
preflight_fail() { printf 'BLFS_PLASMA20_PRECONDITION_FAILED=%s\n' "$1" >&2; exit 1; }
[[ "$(uname -m)" == aarch64 && "$LFS" == /home/circleci/lfs ]] || preflight_fail "arch-or-lfs-$(uname -m)-$LFS"
[[ "$HOST_SOURCES" == /home/circleci/blfs-plasma20-sources/sources ]] || preflight_fail "source-path-$HOST_SOURCES"
for path in \
  "$LFS/usr/bin/sassc" \
  "$LFS/usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml" \
  "$LFS/opt/kf6/lib/cmake/KDecoration3/KDecoration3Config.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6Auth/KF6AuthConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/KF6ColorScheme/KF6ColorSchemeConfig.cmake" \
  "$LFS/opt/kf6/lib/cmake/QQC2BreezeStyle/QQC2BreezeStyleConfig.cmake" \
  "$LFS/opt/kf6/bin/ksystemstats" \
  "$LFS/opt/kf6/bin/plasma-systemmonitor"; do
  [[ -e "$path" ]] || preflight_fail "missing-existing-$path"
done
for path in \
  "$LFS/opt/kf6/lib/plugins/plasma/kcms/kinfocenter/kcm_disks.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/smart.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/libsmart.so" \
  "$LFS/opt/kf6/libexec/kf6/kauth/kded-smart-helper" \
  "$LFS/opt/kf6/share/polkit-1/actions/org.kde.kded.smart.policy" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/gtkconfig.so" \
  "$LFS/opt/kf6/lib/plugins/kf6/kded/libgtkconfig.so" \
  "$LFS/opt/kf6/libexec/gtk3_preview" \
  "$LFS/opt/kf6/lib/gtk-3.0/modules/libcolorreload-gtk-module.so" \
  "$LFS/opt/kf6/lib/gtk-3.0/modules/libwindow-decorations-gtk-module.so" \
  "$LFS/opt/kf6/lib/kconf_update_bin/gtk_theme" \
  "$LFS/opt/kf6/lib/kconf_update_bin/remove_deprecated_gtk4_option"; do
  [[ ! -e "$path" && ! -L "$path" ]] || preflight_fail "existing-$path"
done
for name in plasma-disks-6.4.4.tar.xz kde-gtk-config-6.4.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]] || preflight_fail "missing-source-$name"
done
printf 'BLFS_PLASMA20_RUN_PRECONDITIONS=ok\n'
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-plasma20-chroot.sh" "$LFS/root/build-blfs-plasma20-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"
set +e
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/opt/kf6/bin:/opt/qt6/bin:/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" /bin/bash --login /root/build-blfs-plasma20-chroot.sh
CHROOT_STATUS=$?
set -e
cleanup
trap - EXIT
for name in report progress disks-config gtk-config; do
  if sudo -n test -f "$LFS/root/blfs-plasma20-$name.txt"; then
    sudo -n cat "$LFS/root/blfs-plasma20-$name.txt" >"$ARTIFACTS/blfs-plasma20-$name.txt"
  fi
done
if [[ "$CHROOT_STATUS" -ne 0 ]]; then
  printf 'BLFS_PLASMA20_CHROOT_STATUS=%s\n' "$CHROOT_STATUS" >&2
  exit "$CHROOT_STATUS"
fi
sudo -n rm -f "$LFS/root/build-blfs-plasma20-chroot.sh" \
  "$LFS/root/blfs-plasma20-report.txt" "$LFS/root/blfs-plasma20-progress.txt" \
  "$LFS/root/blfs-plasma20-disks-config.txt" "$LFS/root/blfs-plasma20-gtk-config.txt"
REPORT="$ARTIFACTS/blfs-plasma20-report.txt"
for expected in \
  'BLFS_PLASMA20_RESULT=ok' 'PACKAGE_COUNT=2' 'SOURCE_COUNT=2' 'ARCH=aarch64' \
  'NATIVE_BINARY_EXEC=not-run-smart-helper-gtk-preview-or-kconf-update' 'NEW_EXECUTABLES=installed-not-executed' \
  'ELF_ARCH=AArch64' 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1' 'PLASMA_VERSION=6.4.4' 'PACKAGES=plasma-disks+kde-gtk-config' \
  'PLASMA_DISKS=6.4.4' 'DISKS_KCM=installed-not-opened' 'KDED_SMART=installed-not-loaded' 'SMART_HELPER=installed-not-executed' \
  'SMART_POLICY=installed-not-used' 'SMARTCTL=not-run-runtime-unverified' 'SMART=not-queried' 'DISKS=not-accessed' 'DISKS_SIMULATION=disabled' 'KAUTH=not-run' 'POLKIT=not-used' \
  'KDE_GTK_CONFIG=6.4.4' 'GTK_KDED=installed-not-loaded' 'GTK_MODULES=installed-not-loaded' 'GTK_CSS=built-present-not-applied' 'GTK_PREVIEW=installed-not-executed' \
  'KCONF_UPDATE_TOOLS=installed-not-executed' 'GTK_SETTINGS=not-applied' 'XSETTINGSD=not-started-runtime-unverified' \
  'KSYSTEMSTATS=preserved-pipeline-207-not-executed' 'QQC2_BREEZE_STYLE=preserved-pipeline-207-not-loaded' 'SYSTEMMONITOR=preserved-pipeline-206-not-opened' \
  'TEST_SUITES=not-run' 'PLASMA19=preserved-pipeline-207' 'PLASMA18=preserved-pipeline-206' 'PLASMA17=preserved-pipeline-204' 'SDDM=preserved-not-started' \
  'PLASMA_DESKTOP=preserved-pipeline-183-not-running' 'ACTIVITY_SERVICE=preserved-not-started' 'KWIN=preserved-not-rebuilt-not-running' \
  'PLASMASHELL=not-started' 'STARTPLASMA=not-run' 'COMPOSITOR=not-started' 'DBUS_SESSION=not-started' 'DBUS_SYSTEM=not-started-by-this-stage' 'KDED=not-started' \
  'NETWORK=not-used-by-built-programs' 'REAL_DISPLAY=not-tested' 'HARDWARE_GRAPHICS=not-tested' 'AUDIO=not-started' 'CAMERA=not-accessed' 'BOOTABLE=no'; do
  grep -qxF "$expected" "$REPORT"
done
[[ "$(grep -c '^BLFS_PLASMA20_BUILT=' "$ARTIFACTS/blfs-plasma20-progress.txt")" -eq 2 ]]
grep -qx 'WITH_SIMULATION:BOOL=OFF' "$ARTIFACTS/blfs-plasma20-disks-config.txt"
grep -qx 'DISKS_RUNTIME=not-started' "$ARTIFACTS/blfs-plasma20-disks-config.txt"
grep -Eq '^Sass_EXECUTABLE(:[^=]+)?=/usr/bin/sassc$' "$ARTIFACTS/blfs-plasma20-gtk-config.txt"
grep -qx 'GTK_SETTINGS=not-applied' "$ARTIFACTS/blfs-plasma20-gtk-config.txt"
cat "$REPORT"
