#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-gtkdeps1-report.txt
PROGRESS=/root/blfs-xfce-gtkdeps1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-gtkdeps1-smoke.c
SMOKE_PNG=/root/blfs-xfce-gtkdeps1-smoke.png
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ ! -e /usr/lib/libfribidi.so ]]
[[ ! -e /usr/lib/libpixman-1.so ]]
[[ ! -e /usr/lib/libcairo.so ]]
[[ ! -e /usr/lib/libepoxy.so ]]
pkg-config --atleast-version=2.84.0 glib-2.0
pkg-config --exists libpng fontconfig freetype2 harfbuzz x11 xcb egl gl
[[ "$(pkg-config --modversion harfbuzz)" == 11.4.1 ]]
[[ "$(pkg-config --modversion libxfconf-0)" == 4.20.0 ]]
[[ -d /sources ]]
: >"$PROGRESS"

extract() {
  local archive="$1" expected="$2" first package_dir
  [[ -f "$SOURCES/$archive" ]]
  first="$(tar -tf "$SOURCES/$archive" | head -n1)" || true
  package_dir="${first%%/*}"
  package_dir="${package_dir#./}"
  [[ "$package_dir" == "$expected" ]]
  rm -rf "$SOURCES/$package_dir"
  tar -xf "$SOURCES/$archive" -C "$SOURCES"
  cd "$SOURCES/$package_dir"
}

printf 'BUILD_BLFS_XFCE_GTKDEPS1=fribidi\n'
extract fribidi-1.0.16.tar.xz fribidi-1.0.16
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback
ninja
ninja test
cp meson-logs/testlog.txt /root/blfs-xfce-gtkdeps1-fribidi-testlog.txt
ninja install
cd /sources
rm -rf fribidi-1.0.16
printf 'BLFS_XFCE_GTKDEPS1_BUILT=fribidi-1.0.16\n' >>"$PROGRESS"
/sbin/ldconfig

printf 'BUILD_BLFS_XFCE_GTKDEPS1=pixman\n'
extract pixman-0.46.4.tar.gz pixman-0.46.4
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback
ninja
ninja test
cp meson-logs/testlog.txt /root/blfs-xfce-gtkdeps1-pixman-testlog.txt
ninja install
cd /sources
rm -rf pixman-0.46.4
printf 'BLFS_XFCE_GTKDEPS1_BUILT=pixman-0.46.4\n' >>"$PROGRESS"
/sbin/ldconfig

printf 'BUILD_BLFS_XFCE_GTKDEPS1=cairo\n'
extract cairo-1.18.4.tar.xz cairo-1.18.4
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback
ninja
ninja install
cd /sources
rm -rf cairo-1.18.4
printf 'BLFS_XFCE_GTKDEPS1_BUILT=cairo-1.18.4\n' >>"$PROGRESS"
/sbin/ldconfig

printf 'BUILD_BLFS_XFCE_GTKDEPS1=libepoxy\n'
extract libepoxy-1.5.10.tar.xz libepoxy-1.5.10
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback
ninja
ninja test
cp meson-logs/testlog.txt /root/blfs-xfce-gtkdeps1-libepoxy-testlog.txt
ninja install
cd /sources
rm -rf libepoxy-1.5.10
printf 'BLFS_XFCE_GTKDEPS1_BUILT=libepoxy-1.5.10\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_GTKDEPS1_BUILT=' "$PROGRESS")" -eq 4 ]]
[[ "$(pkg-config --modversion fribidi)" == 1.0.16 ]]
[[ "$(pkg-config --modversion pixman-1)" == 0.46.4 ]]
[[ "$(pkg-config --modversion cairo)" == 1.18.4 ]]
[[ "$(pkg-config --modversion epoxy)" == 1.5.10 ]]
pkg-config --exists cairo-ft cairo-gobject cairo-png cairo-xlib cairo-xcb
for name in fribidi pixman-1 cairo epoxy; do
  [[ -f "/usr/lib/pkgconfig/$name.pc" ]]
done
for name in libfribidi.so libpixman-1.so libcairo.so libepoxy.so; do
  [[ -e "/usr/lib/$name" ]]
done
[[ -f /usr/include/fribidi/fribidi.h ]]
[[ -f /usr/include/pixman-1/pixman.h ]]
[[ -f /usr/include/cairo/cairo.h ]]
[[ -f /usr/include/epoxy/gl.h ]]

cat >"$SMOKE_SOURCE" <<'EOF'
#include <cairo/cairo.h>
#include <epoxy/gl.h>
#include <fribidi/fribidi.h>
#include <pixman.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static const GLubyte *EPOXY_CALLSPEC mock_gl_get_string(GLenum name) {
  if (name == GL_VERSION)
    return (const GLubyte *)"4.5.0 BLFS";
  return (const GLubyte *)"";
}

int main(void) {
  FriBidiChar logical[3] = {'a', 'b', 'c'};
  FriBidiChar visual[3] = {0, 0, 0};
  FriBidiParType base = FRIBIDI_PAR_LTR;
  uint32_t pixel[1] = {0};
  pixman_color_t color = {0xffff, 0xffff, 0xffff, 0xffff};
  pixman_rectangle16_t rectangle = {0, 0, 1, 1};
  pixman_image_t *image;
  cairo_surface_t *surface;
  cairo_t *cr;
  cairo_status_t status;

  if (!fribidi_log2vis(logical, 3, &base, visual, NULL, NULL, NULL) ||
      memcmp(logical, visual, sizeof(logical)) != 0)
    return 10;

  image = pixman_image_create_bits(PIXMAN_a8r8g8b8, 1, 1, pixel, 4);
  if (!image)
    return 11;
  if (!pixman_image_fill_rectangles(PIXMAN_OP_SRC, image, &color, 1, &rectangle))
    return 12;
  pixman_image_unref(image);
  if (pixel[0] != 0xffffffffU)
    return 13;

  epoxy_glGetString = mock_gl_get_string;
  if (epoxy_gl_version() != 45)
    return 14;

  surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 32, 32);
  cr = cairo_create(surface);
  cairo_set_source_rgb(cr, 0.12, 0.18, 0.28);
  cairo_paint(cr);
  cairo_set_source_rgb(cr, 1.0, 0.45, 0.70);
  cairo_rectangle(cr, 4, 4, 24, 24);
  cairo_fill(cr);
  cairo_select_font_face(cr, "sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
  cairo_set_font_size(cr, 12);
  cairo_move_to(cr, 7, 20);
  cairo_show_text(cr, "A");
  status = cairo_surface_write_to_png(surface, "/root/blfs-xfce-gtkdeps1-smoke.png");
  cairo_destroy(cr);
  cairo_surface_destroy(surface);
  if (status != CAIRO_STATUS_SUCCESS)
    return 15;

  printf("BLFS_XFCE_GTKDEPS1_EXEC_OK=%s\n", cairo_version_string());
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-gtkdeps1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs cairo fribidi pixman-1 epoxy)
OUTPUT="$(/tmp/blfs-xfce-gtkdeps1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_GTKDEPS1_EXEC_OK=1.18.4 ]]
[[ -s "$SMOKE_PNG" ]]
[[ "$(od -An -tx1 -N8 "$SMOKE_PNG" | tr -d ' \n')" == 89504e470d0a1a0a ]]
readelf -h /tmp/blfs-xfce-gtkdeps1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-gtkdeps1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
SMOKE_PNG_SHA256="$(sha256sum "$SMOKE_PNG" | awk '{print $1}')"
set +x
{
  printf 'BLFS_XFCE_GTKDEPS1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=4\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_GTKDEPS1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'FRIBIDI=1.0.16\n'
  printf 'PIXMAN=0.46.4\n'
  printf 'CAIRO=1.18.4\n'
  printf 'LIBEPOXY=1.5.10\n'
  printf 'HARFBUZZ=11.4.1\n'
  printf 'FRIBIDI_TEST_SUITE=exit-0\n'
  printf 'PIXMAN_TEST_SUITE=exit-0\n'
  printf 'LIBEPOXY_TEST_SUITE=exit-0\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'SMOKE_PNG_SHA256=%s\n' "$SMOKE_PNG_SHA256"
  printf 'GTK3=absent\n'
  printf 'XFCE=libxfce4util+xfconf\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-gtkdeps1-smoke
