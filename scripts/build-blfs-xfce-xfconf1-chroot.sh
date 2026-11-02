#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-xfconf1-report.txt
PROGRESS=/root/blfs-xfce-xfconf1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ -x /usr/bin/dbus-run-session ]]
[[ ! -e /usr/bin/xfconf-query ]]
pkg-config --atleast-version=2.84.0 glib-2.0
pkg-config --exists gobject-introspection-1.0 gio-2.0 gobject-2.0
[[ "$(pkg-config --modversion libxfce4util-1.0)" == 4.20.1 ]]
[[ -f /usr/lib/girepository-1.0/Libxfce4util-1.0.typelib ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=xfconf-4.20.0.tar.bz2
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == xfconf-4.20.0 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
printf 'BUILD_BLFS_XFCE_XFCONF1=xfconf\n'
./configure --prefix=/usr \
  --enable-introspection \
  --disable-vala \
  --disable-gtk-doc
make
make install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_XFCE_XFCONF1_BUILT=xfconf-4.20.0\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_XFCONF1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion libxfconf-0)" == 4.20.0 ]]
[[ -x /usr/bin/xfconf-query ]]
[[ -x /usr/lib/xfce4/xfconf/xfconfd ]]
[[ -f /usr/share/dbus-1/services/org.xfce.Xfconf.service ]]
[[ -f /usr/share/gir-1.0/Xfconf-0.gir ]]
[[ -f /usr/lib/girepository-1.0/Xfconf-0.typelib ]]

rm -rf /tmp/blfs-xfce-xfconf1-config
mkdir -p /tmp/blfs-xfce-xfconf1-config
OUTPUT="$(dbus-run-session -- sh -c '
  set -e
  export XDG_CONFIG_HOME=/tmp/blfs-xfce-xfconf1-config
  /usr/bin/xfconf-query -c blfs-test -p /answer -n -t int -s 42 >/dev/null
  value="$(/usr/bin/xfconf-query -c blfs-test -p /answer)"
  test "$value" = 42
  printf "BLFS_XFCE_XFCONF1_EXEC_OK=%s\n" "$value"
')"
[[ "$OUTPUT" == BLFS_XFCE_XFCONF1_EXEC_OK=42 ]]
readelf -h /usr/bin/xfconf-query | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /usr/bin/xfconf-query | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_XFCONF1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_XFCONF1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'LIBXFCE4UTIL=4.20.1\n'
  printf 'XFCONF=4.20.0\n'
  printf 'DBUS_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util+xfconf\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-xfce-xfconf1-config
