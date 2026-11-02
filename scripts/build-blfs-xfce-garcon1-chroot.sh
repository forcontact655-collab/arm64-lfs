#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-garcon1-report.txt
PROGRESS=/root/blfs-xfce-garcon1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-garcon1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ ! -e /usr/lib/libgarcon-1.so ]]
[[ ! -e /usr/lib/libgarcon-gtk3-1.so ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion libxfce4ui-2)" == 4.20.2 ]]
[[ "$(pkg-config --modversion exo-2)" == 4.20.0 ]]
pkg-config --exists gobject-introspection-1.0
[[ -f /usr/lib/girepository-1.0/Libxfce4ui-2.0.typelib ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=garcon-4.20.0.tar.bz2
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == garcon-4.20.0 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
printf 'BUILD_BLFS_XFCE_GARCON1=garcon\n'
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --disable-static \
  --enable-introspection \
  --disable-gtk-doc
make
make install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_XFCE_GARCON1_BUILT=garcon-4.20.0\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_GARCON1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion garcon-1)" == 4.20.0 ]]
[[ "$(pkg-config --modversion garcon-gtk3-1)" == 4.20.0 ]]
[[ -e /usr/lib/libgarcon-1.so ]]
[[ -e /usr/lib/libgarcon-gtk3-1.so ]]
for name in Garcon-1.0 GarconGtk-1.0; do
  [[ -f "/usr/share/gir-1.0/$name.gir" ]]
  [[ -f "/usr/lib/girepository-1.0/$name.typelib" ]]
done

cat >"$SMOKE_SOURCE" <<'EOF'
#include <garcon/garcon.h>
#include <garcon-gtk/garcon-gtk.h>

int
main (void)
{
  GarconMenuItemAction *action;

  if (!GARCON_CHECK_VERSION (4, 20, 0) ||
      GARCON_CHECK_VERSION (4, 20, 1) ||
      garcon_gtk_menu_get_type () == 0)
    return 1;

  action = garcon_menu_item_action_new ();
  if (action == NULL)
    return 2;
  garcon_menu_item_action_set_command (action, "/bin/true");
  if (g_strcmp0 (garcon_menu_item_action_get_command (action), "/bin/true") != 0)
    {
      garcon_menu_item_action_unref (action);
      return 3;
    }
  garcon_menu_item_action_unref (action);

  g_print ("BLFS_XFCE_GARCON1_EXEC_OK=%d.%d.%d\n",
           GARCON_MAJOR_VERSION, GARCON_MINOR_VERSION, GARCON_MICRO_VERSION);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-garcon1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs garcon-1 garcon-gtk3-1)
OUTPUT="$(/tmp/blfs-xfce-garcon1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_GARCON1_EXEC_OK=4.20.0 ]]
readelf -h /tmp/blfs-xfce-garcon1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-garcon1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_GARCON1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_GARCON1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'EXO=4.20.0\n'
  printf 'GARCON=4.20.0\n'
  printf 'GARCON_TEST_SUITE=not-provided\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-garcon1-smoke
