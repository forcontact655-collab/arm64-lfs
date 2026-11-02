#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-xfce4-power-manager1-report.txt
PROGRESS=/root/blfs-xfce-xfce4-power-manager1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ ! -x /usr/bin/xfce4-power-manager ]]
[[ ! -x /usr/bin/xfce4-power-manager-settings ]]
[[ ! -x /usr/sbin/xfce4-pm-helper ]]
[[ ! -x /usr/sbin/xfpm-power-backlight-helper ]]
[[ "$(pkg-config --modversion upower-glib)" == 1.90.9 ]]
[[ "$(pkg-config --modversion libxfce4panel-2.0)" == 4.20.5 ]]
[[ "$(pkg-config --modversion polkit-gobject-1)" == 126 ]]
[[ -d /sources ]]
: >"$PROGRESS"

build_package() {
  local archive="$1" expected="$2"
  local first package_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"
  package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  printf 'BUILD_BLFS_XFCE_XFCE4_POWER_MANAGER1=%s\n' "$package_dir"
}

cd /sources
build_package xfce4-power-manager-4.20.0.tar.bz2 xfce4-power-manager-4.20.0
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd /sources
rm -rf xfce4-power-manager-4.20.0
printf 'BLFS_XFCE_XFCE4_POWER_MANAGER1_BUILT=xfce4-power-manager-4.20.0\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_XFCE4_POWER_MANAGER1_BUILT=' "$PROGRESS")" -eq 1 ]]
for program in /usr/bin/xfce4-power-manager /usr/bin/xfce4-power-manager-settings \
  /usr/sbin/xfce4-pm-helper /usr/sbin/xfpm-power-backlight-helper; do
  [[ -x "$program" ]]
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done
[[ -e /usr/lib/xfce4/panel/plugins/libxfce4powermanager.so ]]
readelf -h /usr/lib/xfce4/panel/plugins/libxfce4powermanager.so | grep -q 'Machine:.*AArch64'
[[ -f /usr/share/polkit-1/actions/org.xfce.power.policy ]]
VERSION_OUTPUT="$(xfce4-power-manager --version)"
printf '%s\n' "$VERSION_OUTPUT"
[[ "$VERSION_OUTPUT" == 'Xfce Power Manager 4.20.0' ]]
set +x
{
  printf 'BLFS_XFCE_XFCE4_POWER_MANAGER1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=xfce4-power-manager-version-only\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'UPOWER=1.90.9\n'
  printf 'POLKIT=126\n'
  printf 'XFCE4_POWER_MANAGER=4.20.0\n'
  printf 'XFCE4_POWER_MANAGER_TEST_SUITE=not-provided\n'
  printf 'POWER_MANAGER_PROGRAMS=4-present\n'
  printf 'POWER_MANAGER_PANEL_PLUGIN=present\n'
  printf 'POWER_MANAGER_POLKIT_POLICY=present\n'
  printf 'POWER_MANAGER_DAEMON=not-started\n'
  printf 'GUI_SETTINGS=not-started\n'
  printf 'DBUS_SESSION=not-started\n'
  printf 'POWER_DEVICE_ACCESS=not-tested\n'
  printf 'SUSPEND_HIBERNATE=not-tested\n'
  printf 'BACKLIGHT_CONTROL=not-tested\n'
  printf 'NATIVE_SMOKE=xfce4-power-manager-4.20.0\n'
  printf 'XFCE=through-polkit+power-manager\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
