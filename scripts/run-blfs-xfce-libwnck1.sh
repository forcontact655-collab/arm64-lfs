#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-libwnck1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-libwnck1-sources/sources ]]
[[ -f "$LFS/usr/lib/pkgconfig/gtk+-3.0.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/garcon-1.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/libstartup-notification-1.0.pc" ]]
[[ -f "$LFS/usr/lib/girepository-1.0/Garcon-1.0.typelib" ]]
[[ ! -e "$LFS/usr/lib/libwnck-3.so" ]]
[[ ! -e "$LFS/usr/bin/wnckprop" ]]
[[ -f "$HOST_SOURCES/libwnck-43.2.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-libwnck1-chroot.sh" "$LFS/root/build-blfs-xfce-libwnck1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-libwnck1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-libwnck1-$name.txt" >"$ARTIFACTS/blfs-xfce-libwnck1-$name.txt"
done
sudo -n cat "$LFS/root/blfs-xfce-libwnck1-smoke.c" >"$ARTIFACTS/blfs-xfce-libwnck1-smoke.c"
sudo -n rm -f "$LFS/root/build-blfs-xfce-libwnck1-chroot.sh" \
  "$LFS/root/blfs-xfce-libwnck1-report.txt" \
  "$LFS/root/blfs-xfce-libwnck1-progress.txt" \
  "$LFS/root/blfs-xfce-libwnck1-smoke.c"
grep -q '^BLFS_XFCE_LIBWNCK1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_LIBWNCK1_EXEC_OK$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^GARCON=4.20.0$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^LIBWNCK=43.2$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^STARTUP_NOTIFICATION_LINK=present$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^LIBWNCK_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_LIBWNCK1_EXEC_OK=43.2.0$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^GOBJECT_INTROSPECTION=present$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_LIBWNCK1_BUILT=' "$ARTIFACTS/blfs-xfce-libwnck1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-xfce-libwnck1-report.txt"
trap - EXIT
