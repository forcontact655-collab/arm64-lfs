#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-libxfce4util1-report.txt
PROGRESS=/root/blfs-xfce-libxfce4util1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
pkg-config --atleast-version=2.84.0 glib-2.0
pkg-config --exists gobject-introspection-1.0 gio-2.0 gobject-2.0
[[ -f /opt/kf6/lib/cmake/KF6Attica/KF6AtticaConfig.cmake ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=libxfce4util-4.20.1.tar.bz2
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == libxfce4util-4.20.1 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
printf 'BUILD_BLFS_XFCE_LIBXFCE4UTIL1=libxfce4util\n'
./configure --prefix=/usr \
  --enable-introspection \
  --disable-vala \
  --disable-gtk-doc
make
make install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_XFCE_LIBXFCE4UTIL1_BUILT=libxfce4util-4.20.1\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_LIBXFCE4UTIL1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion libxfce4util-1.0)" == 4.20.1 ]]
[[ -x /usr/bin/xfce4-kiosk-query ]]
[[ -f /usr/share/gir-1.0/Libxfce4util-1.0.gir ]]
[[ -f /usr/lib/girepository-1.0/Libxfce4util-1.0.typelib ]]

rm -rf /tmp/blfs-xfce-libxfce4util1-smoke
mkdir -p /tmp/blfs-xfce-libxfce4util1-smoke
cat >/tmp/blfs-xfce-libxfce4util1-smoke/main.c <<'EOF'
#include <libxfce4util/libxfce4util.h>
#include <stdio.h>
int main(void) {
  const gchar *version = xfce_version_string();
  gchar *result = NULL;
  if (g_strcmp0(version, "4.20") != 0) return 1;
  result = xfce_str_replace("xfce-xfce", "xfce", "blfs");
  if (g_strcmp0(result, "blfs-blfs") != 0) {
    g_free(result);
    return 2;
  }
  printf("BLFS_XFCE_LIBXFCE4UTIL1_EXEC_OK=%s=%s\n", version, result);
  g_free(result);
  return 0;
}
EOF
gcc -O2 /tmp/blfs-xfce-libxfce4util1-smoke/main.c \
  -o /tmp/blfs-xfce-libxfce4util1-smoke/smoke \
  $(pkg-config --cflags --libs libxfce4util-1.0)
OUTPUT="$(/tmp/blfs-xfce-libxfce4util1-smoke/smoke)"
[[ "$OUTPUT" == BLFS_XFCE_LIBXFCE4UTIL1_EXEC_OK=4.20=blfs-blfs ]]
readelf -h /tmp/blfs-xfce-libxfce4util1-smoke/smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-libxfce4util1-smoke/smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_LIBXFCE4UTIL1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_LIBXFCE4UTIL1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'GLIB=%s\n' "$(pkg-config --modversion glib-2.0)"
  printf 'LIBXFCE4UTIL=4.20.1\n'
  printf 'XFCE_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util-only\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -rf /tmp/blfs-xfce-libxfce4util1-smoke
