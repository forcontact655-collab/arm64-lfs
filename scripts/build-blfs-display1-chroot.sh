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
REPORT=/root/blfs-display1-report.txt
PROGRESS=/root/blfs-display1-progress.txt
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -d /sources ]]
[[ -s /etc/pki/tls/certs/ca-bundle.crt ]]
pkg-config --exists libpsl glib-2.0 gobject-introspection-1.0
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
  printf 'BLFS_DISPLAY1_BUILT=%s\n' "$PACKAGE_DIR" >>"$PROGRESS"
  unset PACKAGE_DIR
  /sbin/ldconfig
}
build_freetype() {
  sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
  sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
    -i include/freetype/config/ftoption.h
  ./configure --prefix=/usr --enable-freetype-config --disable-static
  make
  make install
}

printf 'BUILD_BLFS_DISPLAY1=libpng\n'
extract libpng-1.6.50.tar.xz
./configure --prefix=/usr --disable-static
make
make install
mkdir -v /usr/share/doc/libpng-1.6.50
cp -v README libpng-manual.txt /usr/share/doc/libpng-1.6.50
finish_package

printf 'BUILD_BLFS_DISPLAY1=brotli\n'
extract brotli-1.1.0.tar.gz
mkdir build
cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_INSTALL_LIBDIR=lib \
      -D CMAKE_BUILD_TYPE=Release \
      ..
make
make install
finish_package

printf 'BUILD_BLFS_DISPLAY1=graphite2\n'
extract graphite2-1.3.14.tgz
sed -i '/cmptest/d' tests/CMakeLists.txt
sed -i '/cmake_policy(SET CMP0012 NEW)/d' CMakeLists.txt
sed -i 's/PythonInterp/Python3/' CMakeLists.txt
find . -name CMakeLists.txt | xargs sed -i 's/VERSION 2.8.0 FATAL_ERROR/VERSION 4.0.0/'
sed -i '/Font.h/i #include <cstdint>' tests/featuremap/featuremaptest.cpp
mkdir build
cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_INSTALL_LIBDIR=lib \
      -D CMAKE_BUILD_TYPE=Release \
      ..
make
make install
finish_package

printf 'BUILD_BLFS_DISPLAY1=icu\n'
extract icu4c-77_1-src.tgz
cd source
./configure --prefix=/usr
make
make install
finish_package

printf 'BUILD_BLFS_DISPLAY1=freetype\n'
extract freetype-2.13.3.tar.xz
build_freetype
finish_package

printf 'BUILD_BLFS_DISPLAY1=harfbuzz\n'
extract harfbuzz-11.4.1.tar.xz
mkdir build
cd build
meson setup ..             \
      --prefix=/usr        \
      --libdir=lib         \
      --buildtype=release  \
      -D graphite2=enabled \
      -D docs=disabled
ninja
ninja install
finish_package
pkg-config --exists harfbuzz-gobject harfbuzz-icu

printf 'BUILD_BLFS_DISPLAY1=freetype-harfbuzz\n'
extract freetype-2.13.3.tar.xz
build_freetype
pkg-config --print-requires-private freetype2 | grep -q harfbuzz
finish_package

printf 'BUILD_BLFS_DISPLAY1=fontconfig\n'
extract fontconfig-2.17.1.tar.xz
./configure --prefix=/usr        \
            --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-docs       \
            --docdir=/usr/share/doc/fontconfig-2.17.1
make
make install
install -v -dm755 /usr/share/{man/man{1,3,5},doc/fontconfig-2.17.1}
install -v -m644 fc-*/*.1         /usr/share/man/man1
install -v -m644 doc/*.3          /usr/share/man/man3
install -v -m644 doc/fonts-conf.5 /usr/share/man/man5
install -v -m644 doc/*.{pdf,sgml,txt,html} /usr/share/doc/fontconfig-2.17.1
finish_package

printf 'BUILD_BLFS_DISPLAY1=util-macros\n'
extract util-macros-1.20.2.tar.xz
./configure $XORG_CONFIG
make install
finish_package

printf 'BUILD_BLFS_DISPLAY1=xorgproto\n'
extract xorgproto-2024.1.tar.xz
mkdir build
cd build
meson setup --prefix=/usr       \
            --libdir=lib        \
            --buildtype=release \
            ..
ninja
ninja install
if [ -d /usr/share/doc/xorgproto ]; then
  mv -v /usr/share/doc/xorgproto{,-2024.1}
fi
finish_package

printf 'BUILD_BLFS_DISPLAY1=libXau\n'
extract libXau-1.0.12.tar.xz
./configure $XORG_CONFIG
make
make install
finish_package

printf 'BUILD_BLFS_DISPLAY1=libXdmcp\n'
extract libXdmcp-1.1.5.tar.xz
./configure $XORG_CONFIG --docdir=/usr/share/doc/libXdmcp-1.1.5
make
make install
finish_package

printf 'BUILD_BLFS_DISPLAY1=xcb-proto\n'
extract xcb-proto-1.17.0.tar.xz
PYTHON=python3 ./configure $XORG_CONFIG
make install
rm -f /usr/lib/pkgconfig/xcb-proto.pc
finish_package

printf 'BUILD_BLFS_DISPLAY1=libxcb\n'
extract libxcb-1.17.0.tar.xz
./configure $XORG_CONFIG      \
            --without-doxygen \
            --docdir='${datadir}'/doc/libxcb-1.17.0
LC_ALL=en_US.UTF-8 make
make install
chown -R root:root /usr/share/doc/libxcb-1.17.0
finish_package

printf 'BUILD_BLFS_DISPLAY1=wayland\n'
extract wayland-1.24.0.tar.xz
mkdir build
cd build
meson setup ..            \
      --prefix=/usr       \
      --libdir=lib        \
      --buildtype=release \
      -D documentation=false
ninja
ninja install
finish_package

printf 'BUILD_BLFS_DISPLAY1=wayland-protocols\n'
extract wayland-protocols-1.45.tar.xz
mkdir build
cd build
meson setup --prefix=/usr       \
            --libdir=lib        \
            --buildtype=release \
            ..
ninja
ninja install
finish_package

[[ "$(grep -c '^BLFS_DISPLAY1_BUILT=' "$PROGRESS")" -eq 16 ]]
pkg-config --exists libpng16 libbrotlidec graphite2 icu-uc freetype2 \
  harfbuzz harfbuzz-gobject harfbuzz-icu fontconfig xproto xau xdmcp \
  xcb wayland-client wayland-protocols
curl --version | grep -q ' PSL'
cat >/tmp/blfs-display1-smoke.c <<'EOF'
#include <ft2build.h>
#include FT_FREETYPE_H
#include <fontconfig/fontconfig.h>
#include <hb.h>
#include <png.h>
#include <stdio.h>
#include <unicode/uversion.h>
#include <xcb/xcb.h>
#include <wayland-client.h>
int main(void) {
  FT_Library library;
  UVersionInfo icu_version;
  if (FT_Init_FreeType(&library) != 0) return 1;
  if (FcInit() != FcTrue) return 2;
  if (png_access_version_number() == 0) return 3;
  if (hb_version_string() == 0) return 4;
  u_getVersion(icu_version);
  if (icu_version[0] == 0) return 5;
  printf("BLFS_DISPLAY1_EXEC_OK\n");
  FT_Done_FreeType(library);
  FcFini();
  return 0;
}
EOF
gcc /tmp/blfs-display1-smoke.c -o /tmp/blfs-display1-smoke \
  $(pkg-config --cflags --libs freetype2 fontconfig harfbuzz libpng16 icu-uc xcb wayland-client)
OUTPUT="$(/tmp/blfs-display1-smoke)"
[[ "$OUTPUT" == BLFS_DISPLAY1_EXEC_OK ]]
readelf -h /tmp/blfs-display1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-display1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
{
  printf 'BLFS_DISPLAY1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=16\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=%s\n' "$OUTPUT"
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'FREETYPE=%s\n' "$(pkg-config --modversion freetype2)"
  printf 'HARFBUZZ=%s\n' "$(pkg-config --modversion harfbuzz)"
  printf 'ICU=%s\n' "$(pkg-config --modversion icu-uc)"
  printf 'FONTCONFIG=%s\n' "$(pkg-config --modversion fontconfig)"
  printf 'WAYLAND=%s\n' "$(pkg-config --modversion wayland-client)"
  printf 'WAYLAND_PROTOCOLS=%s\n' "$(pkg-config --modversion wayland-protocols)"
  printf 'LIBXCB=%s\n' "$(pkg-config --modversion xcb)"
  printf 'BOOTABLE=no\n'
  printf 'QT=absent\n'
  printf 'KDE=absent\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-display1-smoke /tmp/blfs-display1-smoke.c
