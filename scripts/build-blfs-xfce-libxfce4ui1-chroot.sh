#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-libxfce4ui1-report.txt
PROGRESS=/root/blfs-xfce-libxfce4ui1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ ! -e /usr/lib/libxfce4ui-2.so ]]
[[ ! -e /usr/lib/libstartup-notification-1.so ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion libxfce4util-1.0)" == 4.20.1 ]]
[[ "$(pkg-config --modversion libxfconf-0)" == 4.20.0 ]]
pkg-config --exists gobject-introspection-1.0 x11 xcb xcb-aux xcb-event x11-xcb
[[ -f /usr/lib/girepository-1.0/Gtk-3.0.typelib ]]
[[ -f /usr/lib/girepository-1.0/Xfconf-0.typelib ]]
[[ -d /sources ]]
: >"$PROGRESS"

build_package() {
  local archive="$1" expected="$2" marker="$3"
  local first package_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"
  package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
  printf 'BUILD_BLFS_XFCE_LIBXFCE4UI1=%s\n' "$package_dir"
}

cd /sources
build_package startup-notification-0.12.tar.gz startup-notification-0.12 startup-notification
./configure --prefix=/usr \
  --build=aarch64-unknown-linux-gnu \
  --disable-static
make
make install
cd /sources
rm -rf startup-notification-0.12
printf 'BLFS_XFCE_LIBXFCE4UI1_BUILT=startup-notification-0.12\n' >>"$PROGRESS"
/sbin/ldconfig

build_package libxfce4ui-4.20.2.tar.bz2 libxfce4ui-4.20.2 libxfce4ui
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --disable-static \
  --enable-introspection \
  --disable-vala \
  --disable-gtk-doc
make
make install
cd /sources
rm -rf libxfce4ui-4.20.2
printf 'BLFS_XFCE_LIBXFCE4UI1_BUILT=libxfce4ui-4.20.2\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_LIBXFCE4UI1_BUILT=' "$PROGRESS")" -eq 2 ]]
[[ "$(pkg-config --modversion libstartup-notification-1.0)" == 0.12 ]]
[[ "$(pkg-config --modversion libxfce4ui-2)" == 4.20.2 ]]
[[ "$(pkg-config --modversion libxfce4kbd-private-3)" == 4.20.2 ]]
[[ -f /usr/lib/libstartup-notification-1.so ]]
[[ -f /usr/lib/libxfce4ui-2.so ]]
[[ -f /usr/lib/libxfce4kbd-private-3.so ]]
[[ -f /usr/share/gir-1.0/Libxfce4ui-2.0.gir ]]
[[ -f /usr/lib/girepository-1.0/Libxfce4ui-2.0.typelib ]]
readelf -d /usr/lib/libxfce4ui-2.so | grep -q 'Shared library: \[libstartup-notification-1.so.0\]'

SMOKE_SOURCE=/tmp/blfs-xfce-libxfce4ui1-smoke.c
SMOKE_BINARY=/tmp/blfs-xfce-libxfce4ui1-smoke
cat >"$SMOKE_SOURCE" <<'EOF'
#include <libxfce4ui/libxfce4ui.h>

int
main (void)
{
  gchar *argv[] = { (gchar *) "blfs-libxfce4ui-smoke", NULL };
  GOptionGroup *group;
  GQuark quark;

  if (!LIBXFCE4UI_CHECK_VERSION (4, 20, 2) ||
      LIBXFCE4UI_CHECK_VERSION (4, 20, 3) ||
      xfce_sm_client_get_type () == 0)
    return 1;

  quark = xfce_sm_client_error_quark ();
  group = xfce_sm_client_get_option_group (1, argv);
  if (quark == 0 || group == NULL)
    return 2;
  g_option_group_unref (group);

  g_print ("BLFS_XFCE_LIBXFCE4UI1_EXEC_OK=%d.%d.%d\n",
           LIBXFCE4UI_MAJOR_VERSION,
           LIBXFCE4UI_MINOR_VERSION,
           LIBXFCE4UI_MICRO_VERSION);
  return 0;
}
EOF
cc "$SMOKE_SOURCE" -o "$SMOKE_BINARY" $(pkg-config --cflags --libs libxfce4ui-2)
OUTPUT="$("$SMOKE_BINARY")"
[[ "$OUTPUT" == BLFS_XFCE_LIBXFCE4UI1_EXEC_OK=4.20.2 ]]
readelf -h "$SMOKE_BINARY" | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l "$SMOKE_BINARY" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_LIBXFCE4UI1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=2\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_LIBXFCE4UI1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'STARTUP_NOTIFICATION=0.12\n'
  printf 'STARTUP_NOTIFICATION_LINK=present\n'
  printf 'GTK3=3.24.50\n'
  printf 'XFCONF=4.20.0\n'
  printf 'LIBXFCE4UI=4.20.2\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f "$SMOKE_SOURCE" "$SMOKE_BINARY"
