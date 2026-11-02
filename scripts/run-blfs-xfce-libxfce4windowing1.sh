#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-libxfce4windowing1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-libxfce4windowing1-sources/sources ]]
[[ -f "$LFS/usr/lib/pkgconfig/libwnck-3.0.pc" ]]
[[ -f "$LFS/usr/lib/girepository-1.0/Wnck-3.0.typelib" ]]
[[ -x "$LFS/usr/bin/xdt-csource" ]]
[[ ! -e "$LFS/usr/share/hwdata/pci.ids" ]]
[[ ! -e "$LFS/usr/lib/libdisplay-info.so" ]]
[[ ! -e "$LFS/usr/lib/libxfce4windowing-0.so" ]]
for archive in hwdata-0.398.tar.gz libdisplay-info-0.3.0.tar.xz libxfce4windowing-4.20.4.tar.bz2; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-libxfce4windowing1-chroot.sh" "$LFS/root/build-blfs-xfce-libxfce4windowing1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-libxfce4windowing1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-libxfce4windowing1-$name.txt" >"$ARTIFACTS/blfs-xfce-libxfce4windowing1-$name.txt"
done
for name in smoke.c smoke.edid libdisplay-info-testlog.txt; do
  sudo -n cat "$LFS/root/blfs-xfce-libxfce4windowing1-$name" >"$ARTIFACTS/blfs-xfce-libxfce4windowing1-$name"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-libxfce4windowing1-chroot.sh" \
  "$LFS/root/blfs-xfce-libxfce4windowing1-report.txt" \
  "$LFS/root/blfs-xfce-libxfce4windowing1-progress.txt" \
  "$LFS/root/blfs-xfce-libxfce4windowing1-smoke.c" \
  "$LFS/root/blfs-xfce-libxfce4windowing1-smoke.edid" \
  "$LFS/root/blfs-xfce-libxfce4windowing1-libdisplay-info-testlog.txt"
grep -q '^BLFS_XFCE_LIBXFCE4WINDOWING1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^PACKAGE_COUNT=3$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_LIBXFCE4WINDOWING1_EXEC_OK$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^HWDATA=0.398$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^LIBDISPLAY_INFO=0.3.0$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^LIBXFCE4WINDOWING=4.20.4$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^LIBDISPLAY_INFO_TEST_SUITE=exit-0$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^LIBXFCE4WINDOWING_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^EDID_SMOKE=Red Hat, Inc.+QEMU Monitor+EDID-1.4$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^X11_WINDOWING=present$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^NATIVE_SMOKE=BLFS_XFCE_LIBXFCE4WINDOWING1_EXEC_OK=4.20.4$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^GOBJECT_INTROSPECTION=present$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_LIBXFCE4WINDOWING1_BUILT=' "$ARTIFACTS/blfs-xfce-libxfce4windowing1-progress.txt")" -eq 3 ]]
cat "$ARTIFACTS/blfs-xfce-libxfce4windowing1-report.txt"
trap - EXIT
