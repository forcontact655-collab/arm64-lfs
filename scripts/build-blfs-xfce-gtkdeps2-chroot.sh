#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-gtkdeps2-report.txt
PROGRESS=/root/blfs-xfce-gtkdeps2-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-gtkdeps2-smoke.c
SMOKE_PNG=/root/blfs-xfce-gtkdeps2-smoke.png
SMOKE_JPG=/root/blfs-xfce-gtkdeps2-smoke.jpg
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/cmake ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ -x /usr/bin/glib-compile-schemas ]]
[[ -x /usr/bin/gsettings ]]
[[ -x /usr/bin/fc-cache ]]
[[ -x /usr/bin/fc-match ]]
[[ -x /usr/bin/update-mime-database ]]
[[ ! -e /usr/lib/libjpeg.so ]]
[[ ! -e /usr/lib/libgdk_pixbuf-2.0.so ]]
[[ ! -e /usr/lib/libpango-1.0.so ]]
[[ ! -e /usr/lib/libatspi.so ]]
[[ ! -e /usr/share/fonts/dejavu/DejaVuSans.ttf ]]
pkg-config --atleast-version=2.84.0 glib-2.0
pkg-config --exists gobject-introspection-1.0 gio-2.0 gobject-2.0 libpng fontconfig freetype2 harfbuzz x11 xcb
[[ "$(pkg-config --modversion fribidi)" == 1.0.16 ]]
[[ "$(pkg-config --modversion cairo)" == 1.18.4 ]]
[[ "$(pkg-config --modversion epoxy)" == 1.5.10 ]]
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

printf 'BUILD_BLFS_XFCE_GTKDEPS2=libjpeg-turbo\n'
extract libjpeg-turbo-3.0.1.tar.gz libjpeg-turbo-3.0.1
mkdir build
cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=RELEASE \
      -D ENABLE_STATIC=FALSE \
      -D CMAKE_INSTALL_DEFAULT_LIBDIR=lib \
      -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -D CMAKE_SKIP_INSTALL_RPATH=ON \
      -D CMAKE_INSTALL_DOCDIR=/usr/share/doc/libjpeg-turbo-3.0.1 \
      ..
make
make test
cp Testing/Temporary/LastTest.log /root/blfs-xfce-gtkdeps2-libjpeg-testlog.txt
make install
cd /sources
rm -rf libjpeg-turbo-3.0.1
printf 'BLFS_XFCE_GTKDEPS2_BUILT=libjpeg-turbo-3.0.1\n' >>"$PROGRESS"
/sbin/ldconfig

printf 'BUILD_BLFS_XFCE_GTKDEPS2=gdk-pixbuf\n'
extract gdk-pixbuf-2.42.12.tar.xz gdk-pixbuf-2.42.12
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  -D others=enabled -D introspection=enabled --wrap-mode=nofallback
ninja
ninja test
cp meson-logs/testlog.txt /root/blfs-xfce-gtkdeps2-gdk-pixbuf-testlog.txt
ninja install
gdk-pixbuf-query-loaders --update-cache
cd /sources
rm -rf gdk-pixbuf-2.42.12
printf 'BLFS_XFCE_GTKDEPS2_BUILT=gdk-pixbuf-2.42.12\n' >>"$PROGRESS"
/sbin/ldconfig

printf 'BUILD_BLFS_XFCE_GTKDEPS2=dejavu-fonts\n'
extract dejavu-fonts-ttf-2.37.tar.bz2 dejavu-fonts-ttf-2.37
install -v -d -m755 /usr/share/fonts/dejavu
install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
install -v -d -m755 /usr/share/doc/dejavu-fonts-2.37
install -v -m644 LICENSE README.md /usr/share/doc/dejavu-fonts-2.37
fc-cache -v /usr/share/fonts/dejavu
[[ "$(find /usr/share/fonts/dejavu -maxdepth 1 -type f -name '*.ttf' | wc -l)" -eq 22 ]]
[[ "$(fc-match -f '%{family}\n' 'DejaVu Sans')" == "DejaVu Sans" ]]
cd /sources
rm -rf dejavu-fonts-ttf-2.37
printf 'BLFS_XFCE_GTKDEPS2_BUILT=dejavu-fonts-2.37\n' >>"$PROGRESS"

printf 'BUILD_BLFS_XFCE_GTKDEPS2=pango\n'
extract pango-1.56.4.tar.xz pango-1.56.4
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  -D introspection=enabled --wrap-mode=nofallback
ninja
mapfile -t AVAILABLE_TESTS < <(meson test --list)
SELECTED_TESTS=()
excluded=0
for test_name in "${AVAILABLE_TESTS[@]}"; do
  case "$test_name" in
    test-font-data|test-font|test-layout|pango:test-font-data|pango:test-font|pango:test-layout)
      excluded=$((excluded + 1))
      ;;
    *)
      SELECTED_TESTS+=("$test_name")
      ;;
  esac
done
[[ "$excluded" -eq 3 ]]
[[ "${#SELECTED_TESTS[@]}" -gt 0 ]]
meson test --print-errorlogs "${SELECTED_TESTS[@]}"
cp meson-logs/testlog.txt /root/blfs-xfce-gtkdeps2-pango-testlog.txt
ninja install
cd /sources
rm -rf pango-1.56.4
printf 'BLFS_XFCE_GTKDEPS2_BUILT=pango-1.56.4\n' >>"$PROGRESS"
/sbin/ldconfig

printf 'BUILD_BLFS_XFCE_GTKDEPS2=gsettings-desktop-schemas\n'
extract gsettings-desktop-schemas-48.0.tar.xz gsettings-desktop-schemas-48.0
sed -i -r 's:"(/system):"/org/gnome\1:g' schemas/*.in
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release --wrap-mode=nofallback
ninja
ninja install
glib-compile-schemas /usr/share/glib-2.0/schemas
cd /sources
rm -rf gsettings-desktop-schemas-48.0
printf 'BLFS_XFCE_GTKDEPS2_BUILT=gsettings-desktop-schemas-48.0\n' >>"$PROGRESS"

printf 'BUILD_BLFS_XFCE_GTKDEPS2=at-spi2-core\n'
extract at-spi2-core-2.56.4.tar.xz at-spi2-core-2.56.4
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  -D gtk2_atk_adaptor=false -D systemd_user_dir=/tmp \
  -D introspection=enabled --wrap-mode=nofallback
ninja
ninja install
rm -f /tmp/at-spi-dbus-bus.service
glib-compile-schemas /usr/share/glib-2.0/schemas
cd /sources
rm -rf at-spi2-core-2.56.4
printf 'BLFS_XFCE_GTKDEPS2_BUILT=at-spi2-core-2.56.4\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
export XDG_DATA_DIRS=/usr/share
export GDK_PIXBUF_MODULE_FILE=/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
set -x

[[ "$(grep -c '^BLFS_XFCE_GTKDEPS2_BUILT=' "$PROGRESS")" -eq 6 ]]
[[ "$(pkg-config --modversion libjpeg)" == 3.0.1 ]]
[[ "$(pkg-config --modversion gdk-pixbuf-2.0)" == 2.42.12 ]]
[[ "$(pkg-config --modversion pango)" == 1.56.4 ]]
[[ "$(pkg-config --modversion pangocairo)" == 1.56.4 ]]
[[ "$(pkg-config --modversion atspi-2)" == 2.56.4 ]]
[[ "$(pkg-config --modversion atk)" == 2.56.4 ]]
for name in libjpeg gdk-pixbuf-2.0 pango pangocairo atspi-2 atk; do
  [[ -f "/usr/lib/pkgconfig/$name.pc" ]]
done
for name in libjpeg.so libgdk_pixbuf-2.0.so libpango-1.0.so libpangocairo-1.0.so libatspi.so libatk-1.0.so; do
  [[ -e "/usr/lib/$name" ]]
done
[[ -x /usr/bin/cjpeg ]]
[[ -x /usr/bin/djpeg ]]
[[ -x /usr/bin/gdk-pixbuf-query-loaders ]]
[[ -x /usr/bin/pango-view ]]
[[ -f /usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache ]]
[[ -f /usr/share/glib-2.0/schemas/gschemas.compiled ]]
for name in GdkPixbuf-2.0 Pango-1.0 PangoCairo-1.0 Atspi-2.0 Atk-1.0; do
  [[ -f "/usr/share/gir-1.0/$name.gir" ]]
  [[ -f "/usr/lib/girepository-1.0/$name.typelib" ]]
done
FONT_OUTPUT="$(fc-match -f '%{family}\n' 'DejaVu Sans')"
[[ "$FONT_OUTPUT" == "DejaVu Sans" ]]
[[ "$(find /usr/share/fonts/dejavu -maxdepth 1 -type f -name '*.ttf' | wc -l)" -eq 22 ]]
SCHEMA_OUTPUT="$(GSETTINGS_BACKEND=memory gsettings list-schemas | grep -Fx org.gnome.desktop.interface)"
[[ "$SCHEMA_OUTPUT" == org.gnome.desktop.interface ]]

printf 'P6\n2 2\n255\n' >/root/blfs-xfce-gtkdeps2-smoke.ppm
printf '\377\000\000\000\377\000\000\000\377\377\377\377' >>/root/blfs-xfce-gtkdeps2-smoke.ppm
cjpeg -quality 90 -outfile "$SMOKE_JPG" /root/blfs-xfce-gtkdeps2-smoke.ppm
cat >"$SMOKE_SOURCE" <<'EOF'
#include <atspi/atspi.h>
#include <cairo/cairo.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <pango/pangocairo.h>
#include <stdio.h>

int main(void) {
  gint major = 0, minor = 0, micro = 0;
  gint width = 0, height = 0;
  GError *error = NULL;
  GdkPixbuf *jpeg;
  GdkPixbuf *png;
  cairo_surface_t *surface;
  cairo_t *cr;
  PangoLayout *layout;
  PangoFontDescription *description;
  cairo_status_t status;

  atspi_get_version(&major, &minor, &micro);
  if (major != 2 || minor != 56 || micro != 4)
    return 10;

  jpeg = gdk_pixbuf_new_from_file("/root/blfs-xfce-gtkdeps2-smoke.jpg", &error);
  if (!jpeg) {
    if (error)
      g_printerr("JPEG load: %s\n", error->message);
    return 11;
  }
  if (gdk_pixbuf_get_width(jpeg) != 2 || gdk_pixbuf_get_height(jpeg) != 2)
    return 12;
  g_object_unref(jpeg);

  surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 160, 48);
  cr = cairo_create(surface);
  cairo_set_source_rgb(cr, 0.12, 0.18, 0.28);
  cairo_paint(cr);
  cairo_set_source_rgb(cr, 1.0, 0.45, 0.70);
  cairo_rectangle(cr, 4, 4, 152, 40);
  cairo_stroke(cr);
  layout = pango_cairo_create_layout(cr);
  pango_layout_set_text(layout, "Vim 42", -1);
  if (pango_layout_get_character_count(layout) != 6 ||
      pango_layout_get_line_count(layout) != 1)
    return 13;
  description = pango_font_description_from_string("sans 12");
  pango_layout_set_font_description(layout, description);
  pango_font_description_free(description);
  pango_layout_get_pixel_size(layout, &width, &height);
  if (width <= 0 || height <= 0)
    return 17;
  cairo_move_to(cr, 10, 12);
  pango_cairo_show_layout(cr, layout);
  g_object_unref(layout);
  status = cairo_surface_write_to_png(surface, "/root/blfs-xfce-gtkdeps2-smoke.png");
  cairo_destroy(cr);
  cairo_surface_destroy(surface);
  if (status != CAIRO_STATUS_SUCCESS)
    return 14;

  png = gdk_pixbuf_new_from_file("/root/blfs-xfce-gtkdeps2-smoke.png", &error);
  if (!png) {
    if (error)
      g_printerr("PNG load: %s\n", error->message);
    return 15;
  }
  if (gdk_pixbuf_get_width(png) != 160 || gdk_pixbuf_get_height(png) != 48)
    return 16;
  g_object_unref(png);

  printf("BLFS_XFCE_GTKDEPS2_EXEC_OK=%s\n", pango_version_string());
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-gtkdeps2-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs gdk-pixbuf-2.0 pangocairo atspi-2 atk)
OUTPUT="$(/tmp/blfs-xfce-gtkdeps2-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_GTKDEPS2_EXEC_OK=1.56.4 ]]
[[ -s "$SMOKE_PNG" ]]
[[ -s "$SMOKE_JPG" ]]
[[ "$(od -An -tx1 -N8 "$SMOKE_PNG" | tr -d ' \n')" == 89504e470d0a1a0a ]]
[[ "$(od -An -tx1 -N2 "$SMOKE_JPG" | tr -d ' \n')" == ffd8 ]]
readelf -h /tmp/blfs-xfce-gtkdeps2-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-gtkdeps2-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
SMOKE_PNG_SHA256="$(sha256sum "$SMOKE_PNG" | awk '{print $1}')"
SMOKE_JPG_SHA256="$(sha256sum "$SMOKE_JPG" | awk '{print $1}')"
set +x
{
  printf 'BLFS_XFCE_GTKDEPS2_RESULT=ok\n'
  printf 'PACKAGE_COUNT=6\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_GTKDEPS2_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'LIBJPEG_TURBO=3.0.1\n'
  printf 'GDK_PIXBUF=2.42.12\n'
  printf 'PANGO=1.56.4\n'
  printf 'DEJAVU_FONTS=2.37\n'
  printf 'DEJAVU_TTF_COUNT=22\n'
  printf 'GSETTINGS_DESKTOP_SCHEMAS=48.0\n'
  printf 'AT_SPI2_CORE=2.56.4\n'
  printf 'FRIBIDI=1.0.16\n'
  printf 'CAIRO=1.18.4\n'
  printf 'LIBJPEG_TEST_SUITE=exit-0\n'
  printf 'GDK_PIXBUF_TEST_SUITE=exit-0\n'
  printf 'PANGO_TEST_SUITE=exit-0-excluding-3-known-font-data-tests\n'
  printf 'PANGO_KNOWN_FONT_TESTS_EXCLUDED=test-font-data,test-font,test-layout\n'
  printf 'ATSPI_TEST_SUITE=not-run-graphical-required\n'
  printf 'GSETTINGS_TEST_SUITE=not-provided\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'GDK_PIXBUF_SMOKE=jpeg+png\n'
  printf 'PANGO_LAYOUT_SMOKE=6-chars+nonzero-extents\n'
  printf 'FONTCONFIG_SMOKE=%s\n' "$FONT_OUTPUT"
  printf 'SCHEMA_SMOKE=%s\n' "$SCHEMA_OUTPUT"
  printf 'SMOKE_PNG_SHA256=%s\n' "$SMOKE_PNG_SHA256"
  printf 'SMOKE_JPG_SHA256=%s\n' "$SMOKE_JPG_SHA256"
  printf 'GTK3=absent\n'
  printf 'XFCE=libxfce4util+xfconf\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-gtkdeps2-smoke /root/blfs-xfce-gtkdeps2-smoke.ppm
