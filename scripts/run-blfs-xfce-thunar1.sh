#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-thunar1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-thunar1-sources/sources ]]
[[ -f "$LFS/usr/lib/pkgconfig/libxfce4panel-2.0.pc" ]]
[[ -f "$LFS/usr/lib/girepository-1.0/Libxfce4panel-2.0.typelib" ]]
[[ ! -e "$LFS/usr/share/icons/hicolor/index.theme" ]]
[[ ! -e "$LFS/usr/lib/libgudev-1.0.so" ]]
[[ ! -e "$LFS/usr/lib/libnotify.so" ]]
[[ ! -e "$LFS/usr/lib/libthunarx-3.so" ]]
for archive in hicolor-icon-theme-0.18.tar.xz libgudev-238.tar.xz libnotify-0.8.6.tar.xz thunar-4.20.4.tar.bz2; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-thunar1-chroot.sh" "$LFS/root/build-blfs-xfce-thunar1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-thunar1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-thunar1-$name.txt" >"$ARTIFACTS/blfs-xfce-thunar1-$name.txt"
done
sudo -n cat "$LFS/root/blfs-xfce-thunar1-smoke.c" >"$ARTIFACTS/blfs-xfce-thunar1-smoke.c"
sudo -n rm -f "$LFS/root/build-blfs-xfce-thunar1-chroot.sh" \
  "$LFS/root/blfs-xfce-thunar1-report.txt" \
  "$LFS/root/blfs-xfce-thunar1-progress.txt" \
  "$LFS/root/blfs-xfce-thunar1-smoke.c"
grep -q '^BLFS_XFCE_THUNAR1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^PACKAGE_COUNT=4$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_THUNAR1_EXEC_OK$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^HICOLOR_ICON_THEME=0.18$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^LIBGUDEV=238$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^LIBNOTIFY=0.8.6$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^THUNAR=4.20.4$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^LIBGUDEV_TEST_SUITE=unavailable-without-umockdev$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^LIBNOTIFY_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^THUNAR_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^NOTIFICATION_SMOKE=init-only-no-daemon$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_THUNAR1_EXEC_OK=4.20.4$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^GOBJECT_INTROSPECTION=present$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing+panel+thunar$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_THUNAR1_BUILT=' "$ARTIFACTS/blfs-xfce-thunar1-progress.txt")" -eq 4 ]]
cat "$ARTIFACTS/blfs-xfce-thunar1-report.txt"
trap - EXIT
