#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-gtk3-report.txt
PROGRESS=/root/blfs-xfce-gtk3-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-gtk3-smoke.c
BROADWAY_LOG=/root/blfs-xfce-gtk3-broadwayd.log
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ -x /usr/bin/dbus-run-session ]]
[[ -x /usr/bin/glib-compile-schemas ]]
[[ ! -e /usr/lib/libgtk-3.so ]]
[[ ! -e /usr/bin/gtk3-demo ]]
pkg-config --atleast-version=2.84.0 glib-2.0
pkg-config --exists gobject-introspection-1.0 gio-2.0 gobject-2.0 \
  fontconfig freetype2 harfbuzz x11 xcb wayland-client xkbcommon
[[ "$(pkg-config --modversion gdk-pixbuf-2.0)" == 2.42.12 ]]
[[ "$(pkg-config --modversion pangocairo)" == 1.56.4 ]]
[[ "$(pkg-config --modversion atspi-2)" == 2.56.4 ]]
[[ "$(pkg-config --modversion atk)" == 2.56.4 ]]
[[ "$(pkg-config --modversion epoxy)" == 1.5.10 ]]
[[ -f /usr/share/glib-2.0/schemas/gschemas.compiled ]]
[[ -d /sources ]]
: >"$PROGRESS"

ARCHIVE=gtk-3.24.50.tar.xz
[[ -f "$SOURCES/$ARCHIVE" ]]
first="$(tar -tf "$SOURCES/$ARCHIVE" | head -n1)" || true
PACKAGE_DIR="${first%%/*}"
PACKAGE_DIR="${PACKAGE_DIR#./}"
[[ "$PACKAGE_DIR" == gtk-3.24.50 ]]
rm -rf "$SOURCES/$PACKAGE_DIR"
tar -xf "$SOURCES/$ARCHIVE" -C "$SOURCES"
cd "$SOURCES/$PACKAGE_DIR"
printf 'BUILD_BLFS_XFCE_GTK3=gtk3\n'
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  --wrap-mode=nofallback \
  -D man=false \
  -D broadway_backend=true \
  -D x11_backend=true \
  -D wayland_backend=true \
  -D introspection=true \
  -D gtk_doc=false \
  -D tracker3=false \
  -D cloudproviders=false \
  -D print_backends=file,lpr \
  -D demos=true \
  -D examples=false \
  -D tests=false
ninja
ninja install
gtk-query-immodules-3.0 --update-cache
glib-compile-schemas /usr/share/glib-2.0/schemas
cd /sources
rm -rf "$PACKAGE_DIR"
printf 'BLFS_XFCE_GTK3_BUILT=gtk-3.24.50\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
export XDG_CONFIG_HOME=/tmp/blfs-xfce-gtk3-config
export XDG_CACHE_HOME=/tmp/blfs-xfce-gtk3-cache
export XDG_RUNTIME_DIR=/tmp/blfs-xfce-gtk3-runtime
rm -rf "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
set -x

[[ "$(grep -c '^BLFS_XFCE_GTK3_BUILT=' "$PROGRESS")" -eq 1 ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion gdk-3.0)" == 3.24.50 ]]
TARGETS="$(pkg-config --variable=targets gdk-3.0)"
for backend in x11 wayland broadway; do
  [[ " $TARGETS " == *" $backend "* ]]
done
for name in gtk+-3.0 gdk-3.0; do
  [[ -f "/usr/lib/pkgconfig/$name.pc" ]]
done
[[ -e /usr/lib/libgtk-3.so ]]
[[ -e /usr/lib/libgdk-3.so ]]
[[ -x /usr/bin/broadwayd ]]
[[ -x /usr/bin/gtk3-demo ]]
[[ -x /usr/bin/gtk-builder-tool ]]
[[ -x /usr/bin/gtk-query-immodules-3.0 ]]
[[ -f /usr/lib/gtk-3.0/3.0.0/immodules.cache ]]
for name in Gtk-3.0 Gdk-3.0; do
  [[ -f "/usr/share/gir-1.0/$name.gir" ]]
  [[ -f "/usr/lib/girepository-1.0/$name.typelib" ]]
done

cat >"$SMOKE_SOURCE" <<'EOF'
#include <gtk/gtk.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
  GdkDisplay *display;
  GtkWidget *window;
  GtkWidget *label;
  int iteration;

  gtk_init(&argc, &argv);
  if (gtk_get_major_version() != 3 || gtk_get_minor_version() != 24 ||
      gtk_get_micro_version() != 50)
    return 10;
  display = gdk_display_get_default();
  if (!display)
    return 11;
  if (strcmp(G_OBJECT_TYPE_NAME(display), "GdkBroadwayDisplay") != 0)
    return 12;

  window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  label = gtk_label_new("BLFS_XFCE_GTK3_EXEC_OK");
  gtk_container_add(GTK_CONTAINER(window), label);
  gtk_widget_show_all(window);
  for (iteration = 0; iteration < 5; iteration++)
    gtk_main_iteration_do(FALSE);
  if (!gtk_widget_get_visible(window) || !gtk_widget_get_visible(label))
    return 13;
  if (strcmp(gtk_label_get_text(GTK_LABEL(label)), "BLFS_XFCE_GTK3_EXEC_OK") != 0)
    return 14;

  printf("BLFS_XFCE_GTK3_EXEC_OK=%u.%u.%u\n",
         gtk_get_major_version(), gtk_get_minor_version(), gtk_get_micro_version());
  printf("GDK_SMOKE=%s\n", G_OBJECT_TYPE_NAME(display));
  gtk_widget_destroy(window);
  for (iteration = 0; iteration < 5; iteration++)
    gtk_main_iteration_do(FALSE);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-gtk3-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs gtk+-3.0)
readelf -h /tmp/blfs-xfce-gtk3-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-gtk3-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]

broadwayd :5 >"$BROADWAY_LOG" 2>&1 &
BROADWAY_PID=$!
cleanup_broadway() {
  set +e
  kill "$BROADWAY_PID" 2>/dev/null
  wait "$BROADWAY_PID" 2>/dev/null
  set -e
}
trap cleanup_broadway EXIT
sleep 1
kill -0 "$BROADWAY_PID"
OUTPUT="$(dbus-run-session -- env \
  GDK_BACKEND=broadway BROADWAY_DISPLAY=:5 LIBGL_ALWAYS_SOFTWARE=1 \
  /tmp/blfs-xfce-gtk3-smoke)"
[[ "$OUTPUT" == $'BLFS_XFCE_GTK3_EXEC_OK=3.24.50\nGDK_SMOKE=GdkBroadwayDisplay' ]]
cleanup_broadway
trap - EXIT
printf 'BROADWAYD_SMOKE=started-and-stopped-after-native-gtk\n' >>"$BROADWAY_LOG"
cat "$BROADWAY_LOG"
set +x
{
  printf 'BLFS_XFCE_GTK3_RESULT=ok\n'
  printf 'PACKAGE_COUNT=1\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_GTK3_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'GTK3=3.24.50\n'
  printf 'GDK_PIXBUF=2.42.12\n'
  printf 'PANGO=1.56.4\n'
  printf 'AT_SPI2_CORE=2.56.4\n'
  printf 'GDK_BACKENDS=x11+wayland+broadway\n'
  printf 'GTK_INTROSPECTION=present\n'
  printf 'GTK_MAN_PAGES=disabled\n'
  printf 'GTK_TEST_SUITE=not-run-headless-broadway-smoke-instead\n'
  printf 'NATIVE_SMOKE=BLFS_XFCE_GTK3_EXEC_OK=3.24.50\n'
  printf 'GDK_SMOKE=GdkBroadwayDisplay\n'
  printf 'SMOKE_DISPLAY=:5\n'
  printf 'XFCE=libxfce4util+xfconf\n'
  printf 'LIBXFCE4UI=absent\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-gtk3-smoke
rm -rf "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
