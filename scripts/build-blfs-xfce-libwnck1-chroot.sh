#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-libwnck1-report.txt
PROGRESS=/root/blfs-xfce-libwnck1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-libwnck1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ ! -e /usr/lib/libwnck-3.so ]]
[[ ! -e /usr/bin/wnckprop ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion garcon-1)" == 4.20.0 ]]
[[ "$(pkg-config --modversion libstartup-notification-1.0)" == 0.12 ]]
pkg-config --exists gobject-introspection-1.0 x11 xi
[[ -f /usr/lib/girepository-1.0/Garcon-1.0.typelib ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=libwnck-43.2.tar.xz
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == libwnck-43.2 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
printf 'BUILD_BLFS_XFCE_LIBWNCK1=libwnck\n'
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  --wrap-mode=nofallback \
  -D install_tools=true \
  -D startup_notification=enabled \
  -D introspection=enabled \
  -D gtk_doc=false
ninja
ninja install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_XFCE_LIBWNCK1_BUILT=libwnck-43.2\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_LIBWNCK1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion libwnck-3.0)" == 43.2 ]]
[[ -e /usr/lib/libwnck-3.so ]]
[[ -x /usr/bin/wnckprop ]]
[[ -x /usr/bin/wnck-urgency-monitor ]]
[[ -f /usr/share/gir-1.0/Wnck-3.0.gir ]]
[[ -f /usr/lib/girepository-1.0/Wnck-3.0.typelib ]]
readelf -d /usr/lib/libwnck-3.so | grep -q 'Shared library: \[libstartup-notification-1.so.0\]'

cat >"$SMOKE_SOURCE" <<'EOF'
#include <libwnck/libwnck.h>

int
main (void)
{
  if (!WNCK_CHECK_VERSION (43, 2, 0) ||
      WNCK_CHECK_VERSION (43, 2, 1) ||
      wnck_screen_get_type () == 0 ||
      wnck_window_get_type () == 0)
    return 1;

  g_print ("BLFS_XFCE_LIBWNCK1_EXEC_OK=%d.%d.%d\n",
           WNCK_MAJOR_VERSION, WNCK_MINOR_VERSION, WNCK_MICRO_VERSION);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-libwnck1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs libwnck-3.0)
OUTPUT="$(/tmp/blfs-xfce-libwnck1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_LIBWNCK1_EXEC_OK=43.2.0 ]]
readelf -h /tmp/blfs-xfce-libwnck1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-libwnck1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_LIBWNCK1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_LIBWNCK1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'GARCON=4.20.0\n'
  printf 'LIBWNCK=43.2\n'
  printf 'STARTUP_NOTIFICATION_LINK=present\n'
  printf 'LIBWNCK_TEST_SUITE=not-provided\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-libwnck1-smoke
