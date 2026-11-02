#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-thunar-volman1-report.txt
PROGRESS=/root/blfs-xfce-thunar-volman1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/broadwayd ]]
[[ ! -x /usr/bin/thunar-volman ]]
[[ ! -x /usr/bin/thunar-volman-settings ]]
for spec in exo-2=4.20.0 gudev-1.0=238 libnotify=0.8.6 thunarx-3=4.20.4; do
  [[ "$(pkg-config --modversion "${spec%%=*}")" == "${spec#*=}" ]]
done
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
  printf 'BUILD_BLFS_XFCE_THUNAR_VOLMAN1=%s\n' "$package_dir"
}

cd /sources
build_package thunar-volman-4.20.0.tar.bz2 thunar-volman-4.20.0
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --disable-debug \
  --disable-static \
  --enable-notifications
make
make install
cd /sources
rm -rf thunar-volman-4.20.0
printf 'BLFS_XFCE_THUNAR_VOLMAN1_BUILT=thunar-volman-4.20.0\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_THUNAR_VOLMAN1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -x /usr/bin/thunar-volman ]]
[[ -x /usr/bin/thunar-volman-settings ]]
for program in thunar-volman thunar-volman-settings; do
  readelf -h "/usr/bin/$program" | grep -q 'Machine:.*AArch64'
  readelf -l "/usr/bin/$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done

RUNTIME_DIR=/tmp/blfs-xfce-thunar-volman1-runtime
rm -rf "$RUNTIME_DIR"
mkdir -m 0700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export GDK_BACKEND=broadway
export BROADWAY_DISPLAY=:5
broadwayd :5 >/tmp/blfs-xfce-thunar-volman1-broadway.log 2>&1 &
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
    cat /tmp/blfs-xfce-thunar-volman1-broadway.log
    exit 1
  }
  sleep 0.1
done
set +e
VERSION_OUTPUT="$(thunar-volman --version 2>&1)"
VERSION_STATUS=$?
set -e
printf '%s\n' "$VERSION_OUTPUT"
stop_broadway
trap - EXIT
[[ "$VERSION_STATUS" -eq 0 ]]
grep -q '^thunar-volman 4.20.0 (Xfce ' <<<"$VERSION_OUTPUT"
set +x
{
  printf 'BLFS_XFCE_THUNAR_VOLMAN1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=thunar-volman-version-via-broadway\n'
  printf 'THUNAR=4.20.4\n'
  printf 'THUNAR_VOLMAN=4.20.0\n'
  printf 'THUNAR_VOLMAN_TEST_SUITE=not-provided\n'
  printf 'GUI_SMOKE=headless-broadway-version-only\n'
  printf 'DEVICE_MANAGEMENT=not-tested\n'
  printf 'GVFS_RUNTIME=optional-not-installed\n'
  printf 'NATIVE_SMOKE=thunar-volman-4.20.0\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing+panel+thunar+thunar-volman\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
