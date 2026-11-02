#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --disable-static"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-display2-report.txt
PROGRESS=/root/blfs-display2-progress.txt
XORG_MANIFEST=/root/blfs-display2.md5
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -d /sources ]]
[[ -s "$XORG_MANIFEST" ]]
[[ -s /etc/pki/tls/certs/ca-bundle.crt ]]
pkg-config --exists libpsl fontconfig freetype2 harfbuzz wayland-client xcb
: >"$PROGRESS"
extract() {
  local archive="$1" first
  set +o pipefail
  first="$(tar -tf "$SOURCES/$archive" | head -n1)"
  set -o pipefail
  PACKAGE_DIR="${first%%/*}"
  PACKAGE_DIR="${PACKAGE_DIR#./}"
  [[ "$PACKAGE_DIR" =~ ^[A-Za-z0-9._+-]+$ ]]
  rm -rf "$SOURCES/$PACKAGE_DIR"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$PACKAGE_DIR"
}
finish_package() {
  cd /sources
  rm -rf "$PACKAGE_DIR"
  printf 'BLFS_DISPLAY2_BUILT=%s\n' "$PACKAGE_DIR" >>"$PROGRESS"
  unset PACKAGE_DIR
  /sbin/ldconfig
}

while read -r _ package; do
  case "$package" in
    xkeyboard-config-*|libxkbcommon-*) continue ;;
  esac
  packagedir="${package%.tar.?z*}"
  printf 'BUILD_BLFS_DISPLAY2=%s\n' "$packagedir"
  extract "$package"
  docdir="--docdir=/usr/share/doc/$packagedir"
  case "$packagedir" in
    libpciaccess* )
      mkdir build
      cd build
      meson setup --prefix=/usr       \
                  --libdir=lib        \
                  --buildtype=release \
                  ..
      ninja
      ninja install
      ;;
    libXfont2-[0-9]* )
      ./configure $XORG_CONFIG "$docdir" --disable-devel-docs
      make
      make install
      ;;
    libXt-[0-9]* )
      ./configure $XORG_CONFIG "$docdir" \
                  --with-appdefaultdir=/etc/X11/app-defaults
      make
      make install
      ;;
    libXpm-[0-9]* )
      ./configure $XORG_CONFIG "$docdir" --disable-open-zfile
      make
      make install
      ;;
    * )
      ./configure $XORG_CONFIG "$docdir"
      make
      make install
      ;;
  esac
  finish_package
done <"$XORG_MANIFEST"

[[ "$(grep -c '^BLFS_DISPLAY2_BUILT=' "$PROGRESS")" -eq 32 ]]

printf 'BUILD_BLFS_DISPLAY2=xkeyboard-config\n'
extract xkeyboard-config-2.45.tar.xz
mkdir build
cd build
meson setup --prefix=/usr       \
            --libdir=lib        \
            --buildtype=release \
            ..
ninja
if [ -d /usr/share/X11/xkb ]; then
  rm -rf /usr/share/X11/xkb
  rm -f /usr/share/man/man7/xkeyboard-config.7
  rm -f /usr/share/pkgconfig/xkeyboard-config.pc
fi
ninja install
finish_package
[[ -s /usr/share/X11/xkb/rules/base.lst ]]

printf 'BUILD_BLFS_DISPLAY2=libxkbcommon\n'
extract libxkbcommon-1.11.0.tar.gz
mkdir build
cd build
meson setup ..             \
      --prefix=/usr        \
      --libdir=lib         \
      --buildtype=release  \
      -D enable-docs=false
ninja
ninja install
finish_package

[[ "$(grep -c '^BLFS_DISPLAY2_BUILT=' "$PROGRESS")" -eq 34 ]]
pkg-config --exists x11 xext xfixes xi xrender xrandr xtst xcb \
  xkeyboard-config xkbcommon xkbcommon-x11 wayland-client
cat >/tmp/blfs-display2-smoke.c <<'EOF'
#include <X11/Xlib.h>
#include <stdio.h>
#include <xkbcommon/xkbcommon.h>
#include <xkbcommon/xkbcommon-x11.h>
int main(void) {
  struct xkb_context *context;
  struct xkb_keymap *keymap;
  if (!XInitThreads()) return 1;
  context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
  if (!context) return 2;
  keymap = xkb_keymap_new_from_names(context, 0, XKB_KEYMAP_COMPILE_NO_FLAGS);
  if (!keymap) return 3;
  printf("BLFS_DISPLAY2_EXEC_OK\n");
  xkb_keymap_unref(keymap);
  xkb_context_unref(context);
  return 0;
}
EOF
gcc /tmp/blfs-display2-smoke.c -o /tmp/blfs-display2-smoke \
  $(pkg-config --cflags --libs x11 xkbcommon xkbcommon-x11)
OUTPUT="$(/tmp/blfs-display2-smoke)"
[[ "$OUTPUT" == BLFS_DISPLAY2_EXEC_OK ]]
readelf -h /tmp/blfs-display2-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-display2-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_DISPLAY2_RESULT=ok\n'
  printf 'PACKAGE_COUNT=34\n'
  printf 'XORG_LIBRARIES=32\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=%s\n' "$OUTPUT"
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'X11=%s\n' "$(pkg-config --modversion x11)"
  printf 'XKEYBOARD_CONFIG=%s\n' "$(pkg-config --modversion xkeyboard-config)"
  printf 'XKBCOMMON=%s\n' "$(pkg-config --modversion xkbcommon)"
  printf 'BOOTABLE=no\n'
  printf 'QT=absent\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-display2-smoke /tmp/blfs-display2-smoke.c
