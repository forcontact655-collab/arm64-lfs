#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-devtools1-report.txt
PROGRESS=/root/blfs-xfce-devtools1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ ! -e /usr/bin/xdt-csource ]]
[[ ! -e /usr/bin/xdt-autogen ]]
[[ "$(pkg-config --modversion glib-2.0)" == 2.84.4 ]]
[[ "$(pkg-config --modversion libwnck-3.0)" == 43.2 ]]
[[ -f /usr/lib/girepository-1.0/Wnck-3.0.typelib ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=xfce4-dev-tools-4.20.0.tar.bz2
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == xfce4-dev-tools-4.20.0 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
printf 'BUILD_BLFS_XFCE_DEVTOOLS1=xfce4-dev-tools\n'
./configure --prefix=/usr
make
make check
cp tests/test-suite.log /root/blfs-xfce-devtools1-testlog.txt
make install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_XFCE_DEVTOOLS1_BUILT=xfce4-dev-tools-4.20.0\n' >>"$PROGRESS"
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_DEVTOOLS1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ -x /usr/bin/xdt-csource ]]
[[ -x /usr/bin/xdt-autogen ]]
[[ -f /usr/share/aclocal/xdt-version.m4 ]]
VERSION_OUTPUT="$(/usr/bin/xdt-csource --version)"
VERSION_FIRST_LINE="${VERSION_OUTPUT%%$'\n'*}"
[[ "$VERSION_FIRST_LINE" == 'xdt-csource 4.20.0' ]]
readelf -h /usr/bin/xdt-csource | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /usr/bin/xdt-csource | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
OUTPUT=BLFS_XFCE_DEVTOOLS1_EXEC_OK=4.20.0
set +x
{
  printf 'BLFS_XFCE_DEVTOOLS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_DEVTOOLS1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'LIBWNCK=43.2\n'
  printf 'XFCE4_DEV_TOOLS=4.20.0\n'
  printf 'DEVTOOLS_TEST_SUITE=exit-0\n'
  printf 'NATIVE_SMOKE=xdt-csource-4.20.0\n'
  printf 'XDT_AUTOGEN=present\n'
  printf 'RESULT_MARKER=%s\n' "$OUTPUT"
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
