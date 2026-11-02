#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-gtkdeps2-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-gtkdeps2-sources/sources ]]
[[ -x "$LFS/usr/bin/cmake" ]]
[[ -x "$LFS/usr/bin/meson" ]]
[[ -x "$LFS/usr/bin/ninja" ]]
[[ -x "$LFS/usr/bin/g-ir-scanner" ]]
[[ -f "$LFS/usr/lib/pkgconfig/cairo.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/fribidi.pc" ]]
[[ ! -e "$LFS/usr/lib/libgdk_pixbuf-2.0.so" ]]
[[ ! -e "$LFS/usr/lib/libpango-1.0.so" ]]
for name in \
  libjpeg-turbo-3.0.1.tar.gz \
  gdk-pixbuf-2.42.12.tar.xz \
  pango-1.56.4.tar.xz \
  gsettings-desktop-schemas-48.0.tar.xz \
  at-spi2-core-2.56.4.tar.xz; do
  [[ -f "$HOST_SOURCES/$name" ]]
done
mkdir -p "$ARTIFACTS"
sudo -n true

cleanup() {
  set +e
  local path
  for path in "$LFS/sources" "$LFS/dev/pts" "$LFS/sys" "$LFS/proc" "$LFS/run" "$LFS/dev"; do
    if mountpoint -q "$path"; then sudo -n umount "$path"; fi
  done
  if [[ -d "$HOST_SOURCES" ]]; then sudo -n chown -R "$(id -u):$(id -g)" "$HOST_SOURCES"; fi
  set -e
}
trap cleanup EXIT
sudo -n chown -R root:root "$LFS"
sudo -n mkdir -p "$LFS"/{dev,proc,sys,run,sources}
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-gtkdeps2-chroot.sh" "$LFS/root/build-blfs-xfce-gtkdeps2-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-gtkdeps2-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-gtkdeps2-$name.txt" >"$ARTIFACTS/blfs-xfce-gtkdeps2-$name.txt"
done
for name in smoke.c smoke.png smoke.jpg libjpeg-testlog.txt gdk-pixbuf-testlog.txt pango-testlog.txt; do
  sudo -n cat "$LFS/root/blfs-xfce-gtkdeps2-$name" >"$ARTIFACTS/blfs-xfce-gtkdeps2-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-gtkdeps2-chroot.sh" \
  "$LFS/root/blfs-xfce-gtkdeps2-report.txt" \
  "$LFS/root/blfs-xfce-gtkdeps2-progress.txt" \
  "$LFS/root/blfs-xfce-gtkdeps2-smoke.c" \
  "$LFS/root/blfs-xfce-gtkdeps2-smoke.png" \
  "$LFS/root/blfs-xfce-gtkdeps2-smoke.jpg" \
  "$LFS/root/blfs-xfce-gtkdeps2-libjpeg-testlog.txt" \
  "$LFS/root/blfs-xfce-gtkdeps2-gdk-pixbuf-testlog.txt" \
  "$LFS/root/blfs-xfce-gtkdeps2-pango-testlog.txt"
grep -q '^BLFS_XFCE_GTKDEPS2_RESULT=ok$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^PACKAGE_COUNT=5$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_GTKDEPS2_EXEC_OK$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^LIBJPEG_TURBO=3.0.1$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^GDK_PIXBUF=2.42.12$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^PANGO=1.56.4$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^GSETTINGS_DESKTOP_SCHEMAS=48.0$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^AT_SPI2_CORE=2.56.4$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^LIBJPEG_TEST_SUITE=exit-0$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^GDK_PIXBUF_TEST_SUITE=exit-0$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^PANGO_TEST_SUITE=exit-0-excluding-3-known-font-data-tests$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^ATSPI_TEST_SUITE=not-run-graphical-required$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_GTKDEPS2_EXEC_OK=1.56.4$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^GDK_PIXBUF_SMOKE=jpeg+png$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^PANGO_LAYOUT_SMOKE=6-chars$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^SCHEMA_SMOKE=org.gnome.desktop.interface$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^GTK3=absent$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^XFCE=libxfce4util+xfconf$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
[[ "$(grep -c '^BLFS_XFCE_GTKDEPS2_BUILT=' "$ARTIFACTS/blfs-xfce-gtkdeps2-progress.txt")" -eq 5 ]]
[[ "$(od -An -tx1 -N8 "$ARTIFACTS/blfs-xfce-gtkdeps2-smoke.png" | tr -d ' \n')" == 89504e470d0a1a0a ]]
[[ "$(od -An -tx1 -N2 "$ARTIFACTS/blfs-xfce-gtkdeps2-smoke.jpg" | tr -d ' \n')" == ffd8 ]]
for format in png jpg; do
  expected="$(sed -n "s/^SMOKE_${format^^}_SHA256=//p" "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt")"
  [[ -n "$expected" ]]
  printf '%s  %s\n' "$expected" "$ARTIFACTS/blfs-xfce-gtkdeps2-smoke.$format" | sha256sum -c -
done
cat "$ARTIFACTS/blfs-xfce-gtkdeps2-report.txt"
trap - EXIT
