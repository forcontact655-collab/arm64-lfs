#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-libxfce4windowing1-report.txt
PROGRESS=/root/blfs-xfce-libxfce4windowing1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-libxfce4windowing1-smoke.c
SMOKE_EDID=/root/blfs-xfce-libxfce4windowing1-smoke.edid
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ ! -e /usr/share/hwdata/pci.ids ]]
[[ ! -e /usr/lib/libdisplay-info.so ]]
[[ ! -e /usr/lib/libxfce4windowing-0.so ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion libwnck-3.0)" == 43.2 ]]
[[ -x /usr/bin/xdt-csource ]]
pkg-config --exists gobject-introspection-1.0 wayland-client x11
[[ -f /usr/lib/girepository-1.0/Wnck-3.0.typelib ]]
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
  printf 'BUILD_BLFS_XFCE_LIBXFCE4WINDOWING1=%s\n' "$package_dir"
}

cd /sources
build_package hwdata-0.398.tar.gz hwdata-0.398
./configure --prefix=/usr --disable-blacklist
make install
cd /sources
rm -rf hwdata-0.398
printf 'BLFS_XFCE_LIBXFCE4WINDOWING1_BUILT=hwdata-0.398\n' >>"$PROGRESS"

build_package libdisplay-info-0.3.0.tar.xz libdisplay-info-0.3.0
cp test/data/qemu.edid "$SMOKE_EDID"
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  --wrap-mode=nofallback
ninja
ninja test
cp meson-logs/testlog.txt /root/blfs-xfce-libxfce4windowing1-libdisplay-info-testlog.txt
ninja install
cd /sources
rm -rf libdisplay-info-0.3.0
printf 'BLFS_XFCE_LIBXFCE4WINDOWING1_BUILT=libdisplay-info-0.3.0\n' >>"$PROGRESS"
/sbin/ldconfig

build_package libxfce4windowing-4.20.4.tar.bz2 libxfce4windowing-4.20.4
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --enable-x11 \
  --disable-debug \
  --disable-static \
  --enable-introspection \
  --disable-gtk-doc
make
make install
cd /sources
rm -rf libxfce4windowing-4.20.4
printf 'BLFS_XFCE_LIBXFCE4WINDOWING1_BUILT=libxfce4windowing-4.20.4\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_LIBXFCE4WINDOWING1_BUILT=' "$PROGRESS")" -eq 3 ]]
[[ -f /usr/share/hwdata/pci.ids ]]
[[ -f /usr/share/hwdata/pnp.ids ]]
[[ "$(pkg-config --modversion hwdata)" == 0.398 ]]
[[ "$(pkg-config --modversion libdisplay-info)" == 0.3.0 ]]
[[ "$(pkg-config --modversion libxfce4windowing-0)" == 4.20.4 ]]
[[ "$(pkg-config --modversion libxfce4windowingui-0)" == 4.20.4 ]]
[[ "$(pkg-config --modversion libxfce4windowing-x11-0)" == 4.20.4 ]]
[[ -x /usr/bin/di-edid-decode ]]
[[ -e /usr/lib/libdisplay-info.so ]]
[[ -e /usr/lib/libxfce4windowing-0.so ]]
[[ -e /usr/lib/libxfce4windowingui-0.so ]]
for name in Libxfce4windowing-0.0 Libxfce4windowingui-0.0; do
  [[ -f "/usr/share/gir-1.0/$name.gir" ]]
  [[ -f "/usr/lib/girepository-1.0/$name.typelib" ]]
done

cat >"$SMOKE_SOURCE" <<'EOF'
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libdisplay-info/info.h>
#include <libdisplay-info/edid.h>
#include <libxfce4windowing/libxfce4windowing.h>
#include <libxfce4windowingui/libxfce4windowingui.h>

int
main (void)
{
  uint8_t data[256];
  size_t size;
  FILE *file;
  struct di_info *info;
  const struct di_edid *edid;
  char *make;
  char *model;
  int result = 0;

  file = fopen ("/root/blfs-xfce-libxfce4windowing1-smoke.edid", "rb");
  if (file == NULL)
    return 10;
  size = fread (data, 1, sizeof (data), file);
  if (fclose (file) != 0 || size != sizeof (data))
    return 11;

  info = di_info_parse_edid (data, size);
  if (info == NULL)
    return 12;
  edid = di_info_get_edid (info);
  if (edid == NULL || di_edid_get_version (edid) != 1 ||
      di_edid_get_revision (edid) != 4)
    result = 13;

  make = di_info_get_make (info);
  model = di_info_get_model (info);
  if (make == NULL || model == NULL ||
      strcmp (make, "Red Hat, Inc.") != 0 ||
      strcmp (model, "QEMU Monitor") != 0)
    result = 14;
  free (make);
  free (model);
  di_info_destroy (info);
  if (result != 0)
    return result;

  if (!LIBXFCE4WINDOWING_CHECK_VERSION (4, 20, 4) ||
      LIBXFCE4WINDOWING_CHECK_VERSION (4, 20, 5) ||
      xfw_window_get_type () == 0 ||
      xfw_window_action_menu_get_type () == 0)
    return 15;

  g_print ("BLFS_XFCE_LIBXFCE4WINDOWING1_EXEC_OK=%d.%d.%d\n",
           LIBXFCE4WINDOWING_MAJOR_VERSION,
           LIBXFCE4WINDOWING_MINOR_VERSION,
           LIBXFCE4WINDOWING_MICRO_VERSION);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-libxfce4windowing1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs libdisplay-info libxfce4windowing-0 libxfce4windowingui-0)
OUTPUT="$(/tmp/blfs-xfce-libxfce4windowing1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_LIBXFCE4WINDOWING1_EXEC_OK=4.20.4 ]]
readelf -h /tmp/blfs-xfce-libxfce4windowing1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-libxfce4windowing1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_LIBXFCE4WINDOWING1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=3\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_LIBXFCE4WINDOWING1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'HWDATA=0.398\n'
  printf 'LIBDISPLAY_INFO=0.3.0\n'
  printf 'LIBXFCE4WINDOWING=4.20.4\n'
  printf 'LIBDISPLAY_INFO_TEST_SUITE=exit-0\n'
  printf 'LIBXFCE4WINDOWING_TEST_SUITE=not-provided\n'
  printf 'EDID_SMOKE=Red Hat, Inc.+QEMU Monitor+EDID-1.4\n'
  printf 'X11_WINDOWING=present\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-libxfce4windowing1-smoke
