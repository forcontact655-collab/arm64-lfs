#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-exo1-report.txt
PROGRESS=/root/blfs-xfce-exo1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-exo1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/pkg-config ]]
[[ ! -e /usr/lib/libexo-2.so ]]
[[ ! -e /usr/bin/exo-open ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion libxfce4ui-2)" == 4.20.2 ]]
[[ "$(pkg-config --modversion libxfce4util-1.0)" == 4.20.1 ]]
[[ -f /usr/lib/girepository-1.0/Libxfce4ui-2.0.typelib ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=exo-4.20.0.tar.bz2
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == exo-4.20.0 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
printf 'BUILD_BLFS_XFCE_EXO1=exo\n'
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --disable-static \
  --disable-gtk-doc
make
make check
cp tests/test-suite.log /root/blfs-xfce-exo1-testlog.txt
make install
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_XFCE_EXO1_BUILT=exo-4.20.0\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_EXO1_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion exo-2)" == 4.20.0 ]]
[[ -e /usr/lib/libexo-2.so ]]
[[ -x /usr/bin/exo-open ]]
[[ -x /usr/bin/exo-desktop-item-edit ]]

cat >"$SMOKE_SOURCE" <<'EOF'
#include <exo/exo.h>

int
main (void)
{
  gchar *replaced;

  if (!EXO_CHECK_VERSION (4, 20, 0) || EXO_CHECK_VERSION (4, 20, 1))
    return 1;

  replaced = exo_str_replace ("blfs-exo-native", "-", "_");
  if (g_strcmp0 (replaced, "blfs_exo_native") != 0)
    {
      g_free (replaced);
      return 2;
    }
  g_free (replaced);

  g_print ("BLFS_XFCE_EXO1_EXEC_OK=%d.%d.%d\n",
           EXO_MAJOR_VERSION, EXO_MINOR_VERSION, EXO_MICRO_VERSION);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-exo1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs exo-2)
OUTPUT="$(/tmp/blfs-xfce-exo1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_EXO1_EXEC_OK=4.20.0 ]]
readelf -h /tmp/blfs-xfce-exo1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-exo1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_EXO1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_EXO1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'LIBXFCE4UI=4.20.2\n'
  printf 'EXO=4.20.0\n'
  printf 'EXO_TEST_SUITE=exit-0\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-exo1-smoke
