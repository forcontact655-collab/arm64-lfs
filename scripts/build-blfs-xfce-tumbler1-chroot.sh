#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-tumbler1-report.txt
PROGRESS=/root/blfs-xfce-tumbler1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-tumbler1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ ! -e /usr/lib/libtumbler-1.so ]]
[[ ! -x /usr/lib/tumbler-1/tumblerd ]]
[[ "$(pkg-config --modversion glib-2.0)" == 2.84.4 ]]
pkg-config --exists gdk-pixbuf-2.0 libpng freetype2 libcurl
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
  printf 'BUILD_BLFS_XFCE_TUMBLER1=%s\n' "$package_dir"
}

cd /sources
build_package tumbler-4.20.0.tar.bz2 tumbler-4.20.0
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --disable-debug \
  --disable-static \
  --disable-gtk-doc
make
make install
rm -fv /usr/lib/systemd/user/tumblerd.service
cd /sources
rm -rf tumbler-4.20.0
printf 'BLFS_XFCE_TUMBLER1_BUILT=tumbler-4.20.0\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_TUMBLER1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion tumbler-1)" == 4.20.0 ]]
[[ -e /usr/lib/libtumbler-1.so ]]
[[ -x /usr/lib/tumbler-1/tumblerd ]]
[[ ! -e /usr/lib/systemd/user/tumblerd.service ]]
[[ -d /etc/xdg/tumbler ]]
find /usr/lib/tumbler-1/plugins -type f -name '*.so' -print -quit | grep -q .
find /usr/share/dbus-1/services -maxdepth 1 -type f -name 'org.xfce.Tumbler.*.service' -print -quit | grep -q .
readelf -h /usr/lib/tumbler-1/tumblerd | grep -q 'Machine:.*AArch64'
readelf -l /usr/lib/tumbler-1/tumblerd | grep -q '/lib/ld-linux-aarch64.so.1'

cat >"$SMOKE_SOURCE" <<'EOF'
#include <tumbler/tumbler.h>

int
main (void)
{
  if (!TUMBLER_CHECK_VERSION (4, 20, 0) ||
      TUMBLER_CHECK_VERSION (4, 20, 1) ||
      tumbler_major_version != 4 || tumbler_minor_version != 20 ||
      tumbler_micro_version != 0 ||
      tumbler_thumbnail_format_get_type () == 0 ||
      tumbler_colorspace_get_type () == 0)
    return 1;

  g_print ("BLFS_XFCE_TUMBLER1_EXEC_OK=%d.%d.%d\n",
           tumbler_major_version, tumbler_minor_version,
           tumbler_micro_version);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-tumbler1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs tumbler-1 gdk-pixbuf-2.0)
OUTPUT="$(/tmp/blfs-xfce-tumbler1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_TUMBLER1_EXEC_OK=4.20.0 ]]
readelf -h /tmp/blfs-xfce-tumbler1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-tumbler1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_TUMBLER1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_TUMBLER1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'THUNAR_VOLMAN=4.20.0\n'
  printf 'TUMBLER=4.20.0\n'
  printf 'TUMBLER_TEST_SUITE=not-provided\n'
  printf 'TUMBLERD=present\n'
  printf 'TUMBLER_PLUGINS=present\n'
  printf 'DBUS_SERVICE_FILES=present\n'
  printf 'THUMBNAIL_GENERATION=not-tested\n'
  printf 'DBUS_SESSION=not-started\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing+panel+thunar+thunar-volman+tumbler\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-tumbler1-smoke
