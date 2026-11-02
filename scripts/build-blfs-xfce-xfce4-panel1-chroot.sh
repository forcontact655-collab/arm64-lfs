#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-xfce4-panel1-report.txt
PROGRESS=/root/blfs-xfce-xfce4-panel1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-xfce4-panel1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ ! -e /usr/lib/libxfce4panel-2.0.so ]]
[[ ! -x /usr/bin/xfce4-panel ]]
for spec in cairo=1.18.4 exo-2=4.20.0 garcon-1=4.20.0 libwnck-3.0=43.2 libxfce4windowing-0=4.20.4; do
  [[ "$(pkg-config --modversion "${spec%%=*}")" == "${spec#*=}" ]]
done
pkg-config --exists gobject-introspection-1.0
[[ -f /usr/lib/girepository-1.0/Libxfce4windowing-0.0.typelib ]]
[[ -f /usr/lib/girepository-1.0/Libxfce4windowingui-0.0.typelib ]]
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
  printf 'BUILD_BLFS_XFCE_XFCE4_PANEL1=%s\n' "$package_dir"
}

cd /sources
build_package xfce4-panel-4.20.5.tar.bz2 xfce4-panel-4.20.5
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
rm -rf xfce4-panel-4.20.5
printf 'BLFS_XFCE_XFCE4_PANEL1_BUILT=xfce4-panel-4.20.5\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_XFCE4_PANEL1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion libxfce4panel-2.0)" == 4.20.5 ]]
[[ -e /usr/lib/libxfce4panel-2.0.so ]]
for program in xfce4-panel xfce4-popup-applicationsmenu xfce4-popup-directorymenu xfce4-popup-windowmenu; do
  [[ -x "/usr/bin/$program" ]]
done
[[ -d /etc/xdg/xfce4/panel ]]
find /usr/lib/xfce4/panel -type f -name '*.so' -print -quit | grep -q .
[[ -f /usr/share/gir-1.0/Libxfce4panel-2.0.gir ]]
[[ -f /usr/lib/girepository-1.0/Libxfce4panel-2.0.typelib ]]

cat >"$SMOKE_SOURCE" <<'EOF'
#include <libxfce4panel/libxfce4panel.h>

int
main (void)
{
  if (!LIBXFCE4PANEL_CHECK_VERSION (4, 20, 5) ||
      LIBXFCE4PANEL_CHECK_VERSION (4, 20, 6) ||
      libxfce4panel_major_version != 4 ||
      libxfce4panel_minor_version != 20 ||
      libxfce4panel_micro_version != 5 ||
      xfce_panel_plugin_get_type () == 0 ||
      xfce_panel_plugin_mode_get_type () == 0)
    return 1;

  g_print ("BLFS_XFCE_XFCE4_PANEL1_EXEC_OK=%d.%d.%d\n",
           libxfce4panel_major_version,
           libxfce4panel_minor_version,
           libxfce4panel_micro_version);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-xfce4-panel1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs libxfce4panel-2.0)
OUTPUT="$(/tmp/blfs-xfce-xfce4-panel1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_XFCE4_PANEL1_EXEC_OK=4.20.5 ]]
readelf -h /tmp/blfs-xfce-xfce4-panel1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-xfce4-panel1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_XFCE4_PANEL1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_XFCE4_PANEL1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'LIBXFCE4WINDOWING=4.20.4\n'
  printf 'XFCE4_PANEL=4.20.5\n'
  printf 'XFCE4_PANEL_TEST_SUITE=not-provided\n'
  printf 'PANEL_PROGRAMS=present\n'
  printf 'PANEL_PLUGINS=present\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing+panel\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-xfce4-panel1-smoke
