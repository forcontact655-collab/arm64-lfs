#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=POSIX
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
umask 022
set +h
SOURCES=/sources
REPORT=/root/blfs-xfce-thunar1-report.txt
PROGRESS=/root/blfs-xfce-thunar1-progress.txt
SMOKE_SOURCE=/root/blfs-xfce-thunar1-smoke.c
[[ "$(id -u)" -eq 0 ]]
[[ "$(uname -m)" == aarch64 ]]
[[ ! -e /tools ]]
[[ -x /usr/bin/gcc ]]
[[ -x /usr/bin/make ]]
[[ -x /usr/bin/meson ]]
[[ -x /usr/bin/ninja ]]
[[ -x /usr/bin/pkg-config ]]
[[ -x /usr/bin/g-ir-scanner ]]
[[ ! -e /usr/share/icons/hicolor/index.theme ]]
[[ ! -e /usr/lib/libgudev-1.0.so ]]
[[ ! -e /usr/lib/libnotify.so ]]
[[ ! -e /usr/lib/libthunarx-3.so ]]
[[ "$(pkg-config --modversion exo-2)" == 4.20.0 ]]
[[ "$(pkg-config --modversion gtk+-3.0)" == 3.24.50 ]]
[[ "$(pkg-config --modversion libpcre2-8)" == 10.45 ]]
pkg-config --exists 'libudev >= 251' gobject-introspection-1.0
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
  printf 'BUILD_BLFS_XFCE_THUNAR1=%s\n' "$package_dir"
}

cd /sources
build_package hicolor-icon-theme-0.18.tar.xz hicolor-icon-theme-0.18
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  --wrap-mode=nofallback
ninja
ninja install
cd /sources
rm -rf hicolor-icon-theme-0.18
printf 'BLFS_XFCE_THUNAR1_BUILT=hicolor-icon-theme-0.18\n' >>"$PROGRESS"

build_package libgudev-238.tar.xz libgudev-238
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  --wrap-mode=nofallback \
  -Dtests=disabled -Dintrospection=enabled -Dvapi=disabled -Dgtk_doc=false
ninja
ninja install
cd /sources
rm -rf libgudev-238
printf 'BLFS_XFCE_THUNAR1_BUILT=libgudev-238\n' >>"$PROGRESS"
/sbin/ldconfig

build_package libnotify-0.8.6.tar.xz libnotify-0.8.6
mkdir build
cd build
meson setup .. --prefix=/usr --libdir=lib --buildtype=release \
  --wrap-mode=nofallback \
  -Dtests=false -Dintrospection=enabled -Dman=false \
  -Dgtk_doc=false -Ddocbook_docs=disabled
ninja
ninja install
cd /sources
rm -rf libnotify-0.8.6
printf 'BLFS_XFCE_THUNAR1_BUILT=libnotify-0.8.6\n' >>"$PROGRESS"
/sbin/ldconfig

build_package thunar-4.20.4.tar.bz2 thunar-4.20.4
sed -i 's/\tinstall-systemd_userDATA/\t/' Makefile.in
./configure --prefix=/usr \
  --sysconfdir=/etc \
  --docdir=/usr/share/doc/thunar-4.20.4 \
  --disable-debug \
  --disable-static \
  --enable-introspection \
  --disable-gtk-doc
make
make install
cd /sources
rm -rf thunar-4.20.4
printf 'BLFS_XFCE_THUNAR1_BUILT=thunar-4.20.4\n' >>"$PROGRESS"
/sbin/ldconfig
export LC_ALL=C.UTF-8
set -x

[[ "$(grep -c '^BLFS_XFCE_THUNAR1_BUILT=' "$PROGRESS")" -eq 4 ]]
[[ -f /usr/share/icons/hicolor/index.theme ]]
[[ "$(pkg-config --modversion gudev-1.0)" == 238 ]]
[[ "$(pkg-config --modversion libnotify)" == 0.8.6 ]]
[[ "$(pkg-config --modversion thunarx-3)" == 4.20.4 ]]
[[ -e /usr/lib/libgudev-1.0.so ]]
[[ -e /usr/lib/libnotify.so ]]
[[ -e /usr/lib/libthunarx-3.so ]]
[[ -x /usr/bin/notify-send ]]
[[ -x /usr/bin/thunar ]]
[[ -L /usr/bin/Thunar ]]
[[ -x /usr/bin/thunar-settings ]]
for name in GUdev-1.0 Notify-0.7 Thunarx-3.0; do
  [[ -f "/usr/share/gir-1.0/$name.gir" ]]
  [[ -f "/usr/lib/girepository-1.0/$name.typelib" ]]
done

cat >"$SMOKE_SOURCE" <<'EOF'
#include <string.h>
#include <gudev/gudev.h>
#include <libnotify/notify.h>
#include <thunarx/thunarx.h>

int
main (void)
{
  if (g_udev_client_get_type () == 0)
    return 1;

  if (notify_is_initted () || !notify_init ("blfs-thunar1-smoke") ||
      !notify_is_initted () ||
      strcmp (notify_get_app_name (), "blfs-thunar1-smoke") != 0)
    return 2;
  notify_uninit ();
  if (notify_is_initted ())
    return 3;

  if (!THUNARX_CHECK_VERSION (4, 20, 4) ||
      THUNARX_CHECK_VERSION (4, 20, 5) ||
      thunarx_major_version != 4 || thunarx_minor_version != 20 ||
      thunarx_micro_version != 4 || thunarx_file_info_get_type () == 0)
    return 4;

  g_print ("BLFS_XFCE_THUNAR1_EXEC_OK=%d.%d.%d\n",
           thunarx_major_version, thunarx_minor_version,
           thunarx_micro_version);
  return 0;
}
EOF
cc -O2 -Wall -Wextra -o /tmp/blfs-xfce-thunar1-smoke "$SMOKE_SOURCE" \
  $(pkg-config --cflags --libs gudev-1.0 libnotify thunarx-3)
OUTPUT="$(/tmp/blfs-xfce-thunar1-smoke)"
[[ "$OUTPUT" == BLFS_XFCE_THUNAR1_EXEC_OK=4.20.4 ]]
readelf -h /tmp/blfs-xfce-thunar1-smoke | grep -q 'Machine:.*AArch64'
INTERPRETER="$(readelf -l /tmp/blfs-xfce-thunar1-smoke | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')"
[[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
set +x
{
  printf 'BLFS_XFCE_THUNAR1_RESULT=ok\n'
  printf 'PACKAGE_COUNT=4\n'
  printf 'ARCH=%s\n' "$(uname -m)"
  printf 'NATIVE_BINARY_EXEC=BLFS_XFCE_THUNAR1_EXEC_OK\n'
  printf 'DYNAMIC_LINKER=%s\n' "$INTERPRETER"
  printf 'HICOLOR_ICON_THEME=0.18\n'
  printf 'LIBGUDEV=238\n'
  printf 'LIBNOTIFY=0.8.6\n'
  printf 'THUNAR=4.20.4\n'
  printf 'LIBGUDEV_TEST_SUITE=unavailable-without-umockdev\n'
  printf 'LIBNOTIFY_TEST_SUITE=not-provided\n'
  printf 'THUNAR_TEST_SUITE=not-provided\n'
  printf 'NOTIFICATION_SMOKE=init-only-no-daemon\n'
  printf 'NOTIFICATION_DAEMON=deferred-to-xfce4-notifyd\n'
  printf 'NATIVE_SMOKE=%s\n' "$OUTPUT"
  printf 'GOBJECT_INTROSPECTION=present\n'
  printf 'XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing+panel+thunar\n'
  printf 'KDE=attica-only\n'
  printf 'PLASMA=absent\n'
  printf 'BOOTABLE=no\n'
} >"$REPORT"
cat "$REPORT"
rm -f /tmp/blfs-xfce-thunar1-smoke
