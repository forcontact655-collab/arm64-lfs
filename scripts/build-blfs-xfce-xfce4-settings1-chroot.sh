#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-xfce4-settings1-report.txt
PROGRESS=/root/blfs-xfce-xfce4-settings1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/broadwayd ]]
[[ -x /usr/bin/xfce4-power-manager ]]
[[ ! -x /usr/bin/xfsettingsd ]]
[[ ! -d /usr/share/icons/nuoveXT2 ]]
[[ "$(pkg-config --modversion exo-2)" == 4.20.0 ]]
[[ "$(pkg-config --modversion garcon-1)" == 4.20.0 ]]
[[ "$(pkg-config --modversion libnotify)" == 0.8.6 ]]
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
  printf 'BUILD_BLFS_XFCE_XFCE4_SETTINGS1=%s\n' "$package_dir"
}

cd /sources
build_package lxde-icon-theme-0.5.1.tar.xz lxde-icon-theme-0.5.1
./configure --prefix=/usr
make install
gtk-update-icon-cache -qf /usr/share/icons/nuoveXT2
cd /sources
rm -rf lxde-icon-theme-0.5.1
printf 'BLFS_XFCE_XFCE4_SETTINGS1_BUILT=lxde-icon-theme-0.5.1\n' >>"$PROGRESS"

build_package xfce4-settings-4.20.2.tar.bz2 xfce4-settings-4.20.2
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd /sources
rm -rf xfce4-settings-4.20.2
printf 'BLFS_XFCE_XFCE4_SETTINGS1_BUILT=xfce4-settings-4.20.2\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_XFCE4_SETTINGS1_BUILT=' "$PROGRESS")" -eq 2 ]]
[[ -f /usr/share/icons/nuoveXT2/index.theme ]]
[[ -f /usr/share/icons/nuoveXT2/icon-theme.cache ]]
[[ -f /usr/share/icons/nuoveXT2/48x48/places/folder.png ]]
programs=(
  xfce4-accessibility-settings
  xfce4-appearance-settings
  xfce4-color-settings
  xfce4-display-settings
  xfce4-find-cursor
  xfce4-keyboard-settings
  xfce4-mime-helper
  xfce4-mime-settings
  xfce4-mouse-settings
  xfce4-settings-editor
  xfce4-settings-manager
  xfsettingsd
)
[[ "${#programs[@]}" -eq 12 ]]
for name in "${programs[@]}"; do
  [[ -x "/usr/bin/$name" ]]
  readelf -h "/usr/bin/$name" | grep -q 'Machine:.*AArch64'
  readelf -l "/usr/bin/$name" | grep -q '/lib/ld-linux-aarch64.so.1'
done

RUNTIME_DIR=/tmp/blfs-xfce-xfce4-settings1-runtime
rm -rf "$RUNTIME_DIR"
mkdir -m 0700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export GDK_BACKEND=broadway
export BROADWAY_DISPLAY=:5
broadwayd :5 >/tmp/blfs-xfce-xfce4-settings1-broadway.log 2>&1 &
BROADWAY_PID=$!
stop_broadway() {
  set +e
  kill "$BROADWAY_PID" 2>/dev/null
  wait "$BROADWAY_PID" 2>/dev/null
  rm -rf "$RUNTIME_DIR"
  set -e
}
trap stop_broadway EXIT
for _ in {1..50}; do
  kill -0 "$BROADWAY_PID" 2>/dev/null || {
    cat /tmp/blfs-xfce-xfce4-settings1-broadway.log
    exit 1
  }
  sleep 0.1
done
set +e
VERSION_OUTPUT="$(xfce4-settings-manager --version 2>&1)"
VERSION_STATUS=$?
set -e
printf '%s\n' "$VERSION_OUTPUT"
stop_broadway
trap - EXIT
[[ "$VERSION_STATUS" -eq 0 ]]
grep -q '^xfce4-settings-manager 4.20.2 (Xfce ' <<<"$VERSION_OUTPUT"
set +x
{
  printf 'BLFS_XFCE_XFCE4_SETTINGS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=2\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=xfce4-settings-manager-version-via-broadway\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'LXDE_ICON_THEME=0.5.1\n'
  printf 'LXDE_ICON_THEME_TEST_SUITE=not-provided\n'
  printf 'ICON_THEME=nuoveXT2-cache-present\n'
  printf 'XFCE4_SETTINGS=4.20.2\n'
  printf 'XFCE4_SETTINGS_TEST_SUITE=not-provided\n'
  printf 'SETTINGS_PROGRAMS=12-present\n'
  printf 'GUI_SMOKE=headless-broadway-version-only\n'
  printf 'SETTINGS_MANAGER=not-started\n'
  printf 'XFSETTINGSD=not-started\n'
  printf 'SETTINGS_CHANGES=not-tested\n'
  printf 'DBUS_SESSION=not-started\n'
  printf 'COLOR_MANAGEMENT=not-tested\n'
  printf 'DISPLAY_SETTINGS=not-tested\n'
  printf 'NATIVE_SMOKE=xfce4-settings-4.20.2\n'
  printf 'XFCE=through-power-manager+settings\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
