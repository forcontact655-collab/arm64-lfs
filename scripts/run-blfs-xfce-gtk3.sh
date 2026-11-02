#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-gtk3-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-gtk3-sources/sources ]]
[[ -x "$LFS/usr/bin/meson" ]]
[[ -x "$LFS/usr/bin/ninja" ]]
[[ -x "$LFS/usr/bin/dbus-run-session" ]]
[[ -f "$LFS/usr/lib/pkgconfig/gdk-pixbuf-2.0.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/pangocairo.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/atspi-2.pc" ]]
[[ ! -e "$LFS/usr/lib/libgtk-3.so" ]]
[[ -f "$HOST_SOURCES/gtk-3.24.50.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-gtk3-chroot.sh" "$LFS/root/build-blfs-xfce-gtk3-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-gtk3-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-gtk3-$name.txt" >"$ARTIFACTS/blfs-xfce-gtk3-$name.txt"
done
for name in smoke.c broadwayd.log; do
  sudo -n cat "$LFS/root/blfs-xfce-gtk3-$name" >"$ARTIFACTS/blfs-xfce-gtk3-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-gtk3-chroot.sh" \
  "$LFS/root/blfs-xfce-gtk3-report.txt" \
  "$LFS/root/blfs-xfce-gtk3-progress.txt" \
  "$LFS/root/blfs-xfce-gtk3-smoke.c" \
  "$LFS/root/blfs-xfce-gtk3-broadwayd.log"
grep -q '^BLFS_XFCE_GTK3_RESULT=ok$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_GTK3_EXEC_OK$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^GTK3=3.24.50$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^GDK_BACKENDS=x11+wayland+broadway$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^GTK_INTROSPECTION=present$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^GTK_TEST_SUITE=not-run-headless-broadway-smoke-instead$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_GTK3_EXEC_OK=3.24.50$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^GDK_SMOKE=GdkBroadwayDisplay$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^LIBXFCE4UI=absent$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^XFCE=libxfce4util+xfconf$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
grep -q '^BROADWAYD_SMOKE=started-and-stopped-after-native-gtk$' "$ARTIFACTS/blfs-xfce-gtk3-broadwayd.log"
[[ "$(grep -c '^BLFS_XFCE_GTK3_BUILT=' "$ARTIFACTS/blfs-xfce-gtk3-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-xfce-gtk3-report.txt"
trap - EXIT
