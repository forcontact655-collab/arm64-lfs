#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-core-final1-report.txt
PROGRESS=/root/blfs-xfce-core-final1-progress.txt
VERSION_LOG=/root/blfs-xfce-core-final1-versions.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/broadwayd ]]
[[ -x /usr/bin/update-desktop-database ]]
[[ -x /usr/bin/update-mime-database ]]
[[ -x /usr/bin/xfsettingsd ]]
[[ -x /usr/bin/xfce4-color-settings ]]
[[ ! -x /usr/bin/iceauth ]]
[[ ! -x /usr/bin/xfdesktop ]]
[[ ! -x /usr/bin/xfwm4 ]]
[[ ! -x /usr/bin/xfce4-session ]]
[[ "$(pkg-config --modversion exo-2)" == 4.20.0 ]]
[[ "$(pkg-config --modversion libxfce4windowing-0)" == 4.20.4 ]]
[[ "$(pkg-config --modversion libwnck-3.0)" == 43.2 ]]
[[ "$(pkg-config --modversion libxfce4ui-2)" == 4.20.2 ]]
[[ "$(pkg-config --modversion libnotify)" == 0.8.6 ]]
[[ -d /sources ]]
: >"$PROGRESS"
: >"$VERSION_LOG"

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
  printf 'BUILD_BLFS_XFCE_CORE_FINAL1=%s\n' "$package_dir"
}

cd /sources
build_package iceauth-1.0.10.tar.xz iceauth-1.0.10
./configure --prefix=/usr
make
make install
cd /sources
rm -rf iceauth-1.0.10
printf 'BLFS_XFCE_CORE_FINAL1_BUILT=iceauth-1.0.10\n' >>"$PROGRESS"

build_package xfdesktop-4.20.1.tar.bz2 xfdesktop-4.20.1
./configure --prefix=/usr
make
make install
cd /sources
rm -rf xfdesktop-4.20.1
printf 'BLFS_XFCE_CORE_FINAL1_BUILT=xfdesktop-4.20.1\n' >>"$PROGRESS"

build_package xfwm4-4.20.0.tar.bz2 xfwm4-4.20.0
./configure --prefix=/usr
make
make install
cd /sources
rm -rf xfwm4-4.20.0
printf 'BLFS_XFCE_CORE_FINAL1_BUILT=xfwm4-4.20.0\n' >>"$PROGRESS"

build_package xfce4-session-4.20.3.tar.bz2 xfce4-session-4.20.3
./configure --prefix=/usr --sysconfdir=/etc --disable-legacy-sm
make
make install
cd /sources
rm -rf xfce4-session-4.20.3
printf 'BLFS_XFCE_CORE_FINAL1_BUILT=xfce4-session-4.20.3\n' >>"$PROGRESS"
/sbin/ldconfig
update-desktop-database
update-mime-database /usr/share/mime
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_CORE_FINAL1_BUILT=' "$PROGRESS")" -eq 4 ]]
[[ -x /usr/bin/iceauth ]]
readelf -h /usr/bin/iceauth | grep -q 'Machine:.*AArch64'
readelf -l /usr/bin/iceauth | grep -q '/lib/ld-linux-aarch64.so.1'
programs=(
  /usr/bin/xfdesktop
  /usr/bin/xfdesktop-settings
  /usr/bin/xfwm4
  /usr/bin/xfwm4-settings
  /usr/bin/xfwm4-tweaks-settings
  /usr/bin/xfwm4-workspace-settings
  /usr/bin/xfce4-session
  /usr/bin/xfce4-session-logout
  /usr/bin/xfce4-session-settings
)
[[ "${#programs[@]}" -eq 9 ]]
for program in "${programs[@]}"; do
  [[ -x "$program" ]]
  readelf -h "$program" | grep -q 'Machine:.*AArch64'
  readelf -l "$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done
scripts=(
  /usr/bin/startxfce4
  /usr/bin/xflock4
)
[[ "${#scripts[@]}" -eq 2 ]]
for script in "${scripts[@]}"; do
  [[ -x "$script" ]]
  head -n1 "$script" | grep -q '^#!'
  ! readelf -h "$script" >/dev/null 2>&1
  bash -n "$script"
done
grep -q 'xfce4-session' /usr/bin/startxfce4
[[ -d /usr/share/backgrounds/xfce ]]
[[ -d /usr/share/themes/Daloa ]]
[[ -d /usr/lib/xfce4/session ]]

RUNTIME_DIR=/tmp/blfs-xfce-core-final1-runtime
rm -rf "$RUNTIME_DIR"
mkdir -m 0700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export GDK_BACKEND=broadway
export BROADWAY_DISPLAY=:5
broadwayd :5 >/tmp/blfs-xfce-core-final1-broadway.log 2>&1 &
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
    cat /tmp/blfs-xfce-core-final1-broadway.log
    exit 1
  }
  sleep 0.1
done

run_version() {
  local program="$1" expected="$2" flag="$3" output status
  set +e
  output="$("$program" "$flag" 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"
  {
    printf 'PROGRAM=%s\n' "$program"
    printf 'STATUS=%s\n' "$status"
    printf '%s\n' "$output"
  } >>"$VERSION_LOG"
  [[ "$status" -eq 0 ]]
  grep -q "$expected" <<<"$output"
  printf 'RESULT=ok\n' >>"$VERSION_LOG"
}
run_version iceauth '^iceauth 1.0.10$' -V
run_version xfdesktop-settings '^xfdesktop-settings 4.20.1 (Xfce ' --version
run_version xfwm4-workspace-settings '^xfwm4 4.20.0$' --version
run_version xfce4-session-settings '^xfce4-session-settings 4.20.3 (Xfce ' --version
[[ "$(grep -c '^RESULT=ok$' "$VERSION_LOG")" -eq 4 ]]
stop_broadway
trap - EXIT
set +x
{
  printf 'BLFS_XFCE_CORE_FINAL1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=4\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=iceauth-version+three-settings-via-broadway\n'
  printf 'DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1\n'
  printf 'ICEAUTH=1.0.10\n'
  printf 'ICEAUTH_TEST_SUITE=not-provided\n'
  printf 'ICEAUTH_PROGRAM=1-present\n'
  printf 'XFDESKTOP=4.20.1\n'
  printf 'XFDESKTOP_TEST_SUITE=not-provided\n'
  printf 'XFDESKTOP_PROGRAMS=2-present\n'
  printf 'XFWM4=4.20.0\n'
  printf 'XFWM4_TEST_SUITE=not-provided\n'
  printf 'XFWM4_PROGRAMS=4-present\n'
  printf 'XFCE4_SESSION=4.20.3\n'
  printf 'XFCE4_SESSION_TEST_SUITE=not-provided\n'
  printf 'XFCE4_SESSION_LEGACY_SM=disabled\n'
  printf 'SESSION_PROGRAMS=3-elf+2-scripts\n'
  printf 'CORE_PROGRAMS=9-elf+2-scripts\n'
  printf 'DESKTOP_DATABASE=updated\n'
  printf 'MIME_DATABASE=updated\n'
  printf 'NATIVE_VERSION_SMOKES=4-passed\n'
  printf 'GUI_SMOKE=headless-broadway-version-only\n'
  printf 'XFDESKTOP_PROCESS=not-started\n'
  printf 'XFWM4_PROCESS=not-started\n'
  printf 'XFCE4_SESSION_PROCESS=not-started\n'
  printf 'XFSETTINGSD=not-started\n'
  printf 'DBUS_SESSION=not-started\n'
  printf 'SESSION_CHANGES=not-tested\n'
  printf 'NATIVE_SMOKE=iceauth+xfdesktop-settings+xfwm4-workspace-settings+xfce4-session-settings\n'
  printf 'XFCE_CORE=18-of-18-built-and-version-smoke-verified\n'
  printf 'XFCE=through-settings+core-final\n'
  printf 'DESKTOP_LAUNCH=not-tested\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
