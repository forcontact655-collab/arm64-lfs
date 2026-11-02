#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-xfce4-appfinder1-report.txt
PROGRESS=/root/blfs-xfce-xfce4-appfinder1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/broadwayd ]]
[[ ! -x /usr/bin/xfce4-appfinder ]]
[[ ! -e /usr/bin/xfrun4 ]]
[[ "$(pkg-config --modversion garcon-1)" == 4.20.0 ]]
[[ -e /usr/lib/libtumbler-1.so ]]
[[ -x /usr/lib/tumbler-1/tumblerd ]]
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
  printf 'BUILD_BLFS_XFCE_XFCE4_APPFINDER1=%s\n' "$package_dir"
}

cd /sources
build_package xfce4-appfinder-4.20.0.tar.bz2 xfce4-appfinder-4.20.0
./configure --prefix=/usr \
  --disable-debug \
  --disable-static
make
make install
cd /sources
rm -rf xfce4-appfinder-4.20.0
printf 'BLFS_XFCE_XFCE4_APPFINDER1_BUILT=xfce4-appfinder-4.20.0\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_XFCE4_APPFINDER1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -x /usr/bin/xfce4-appfinder ]]
[[ -L /usr/bin/xfrun4 ]]
for program in xfce4-appfinder xfrun4; do
  readelf -h "/usr/bin/$program" | grep -q 'Machine:.*AArch64'
  readelf -l "/usr/bin/$program" | grep -q '/lib/ld-linux-aarch64.so.1'
done

RUNTIME_DIR=/tmp/blfs-xfce-xfce4-appfinder1-runtime
rm -rf "$RUNTIME_DIR"
mkdir -m 0700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export GDK_BACKEND=broadway
export BROADWAY_DISPLAY=:5
broadwayd :5 >/tmp/blfs-xfce-xfce4-appfinder1-broadway.log 2>&1 &
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
    cat /tmp/blfs-xfce-xfce4-appfinder1-broadway.log
    exit 1
  }
  sleep 0.1
done
set +e
VERSION_OUTPUT="$(xfce4-appfinder --version 2>&1)"
VERSION_STATUS=$?
set -e
printf '%s\n' "$VERSION_OUTPUT"
stop_broadway
trap - EXIT
[[ "$VERSION_STATUS" -eq 0 ]]
grep -q '^xfce4-appfinder 4.20.0 (Xfce ' <<<"$VERSION_OUTPUT"
set +x
{
  printf 'BLFS_XFCE_XFCE4_APPFINDER1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=xfce4-appfinder-version-via-broadway\n'
  printf 'TUMBLER=4.20.0\n'
  printf 'XFCE4_APPFINDER=4.20.0\n'
  printf 'XFCE4_APPFINDER_TEST_SUITE=not-provided\n'
  printf 'GUI_SMOKE=headless-broadway-version-only\n'
  printf 'APPLICATION_SEARCH=not-tested\n'
  printf 'NATIVE_SMOKE=xfce4-appfinder-4.20.0\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing+panel+thunar+thunar-volman+tumbler+appfinder\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
