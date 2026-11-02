#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-libxfce4ui1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-libxfce4ui1-sources/sources ]]
[[ -f "$LFS/usr/lib/pkgconfig/gtk+-3.0.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/libxfconf-0.pc" ]]
[[ -f "$LFS/usr/lib/girepository-1.0/Gtk-3.0.typelib" ]]
[[ -f "$LFS/usr/lib/girepository-1.0/Xfconf-0.typelib" ]]
[[ ! -e "$LFS/usr/lib/libxfce4ui-2.so" ]]
[[ ! -e "$LFS/usr/lib/libstartup-notification-1.so" ]]
for archive in startup-notification-0.12.tar.gz libxfce4ui-4.20.2.tar.bz2; do
  [[ -f "$HOST_SOURCES/$archive" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-libxfce4ui1-chroot.sh" "$LFS/root/build-blfs-xfce-libxfce4ui1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-libxfce4ui1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-libxfce4ui1-$name.txt" >"$ARTIFACTS/blfs-xfce-libxfce4ui1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-libxfce4ui1-chroot.sh" \
  "$LFS/root/blfs-xfce-libxfce4ui1-report.txt" \
  "$LFS/root/blfs-xfce-libxfce4ui1-progress.txt"
grep -q '^BLFS_XFCE_LIBXFCE4UI1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^PACKAGE_COUNT=2$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_LIBXFCE4UI1_EXEC_OK$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^STARTUP_NOTIFICATION=0.12$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^STARTUP_NOTIFICATION_LINK=present$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^GTK3=3.24.50$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^XFCONF=4.20.0$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^LIBXFCE4UI=4.20.2$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_LIBXFCE4UI1_EXEC_OK=4.20.2$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^GOBJECT_INTROSPECTION=present$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^XFCE=libxfce4util+xfconf+libxfce4ui$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_LIBXFCE4UI1_BUILT=' "$ARTIFACTS/blfs-xfce-libxfce4ui1-progress.txt")" -eq 2 ]]
cat "$ARTIFACTS/blfs-xfce-libxfce4ui1-report.txt"
trap - EXIT
