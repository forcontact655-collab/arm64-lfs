#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-devtools1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-devtools1-sources/sources ]]
[[ -f "$LFS/usr/lib/pkgconfig/libwnck-3.0.pc" ]]
[[ -f "$LFS/usr/lib/girepository-1.0/Wnck-3.0.typelib" ]]
[[ ! -e "$LFS/usr/bin/xdt-csource" ]]
[[ ! -e "$LFS/usr/bin/xdt-autogen" ]]
[[ -f "$HOST_SOURCES/xfce4-dev-tools-4.20.0.tar.bz2" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-devtools1-chroot.sh" "$LFS/root/build-blfs-xfce-devtools1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-devtools1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-devtools1-$name.txt" >"$ARTIFACTS/blfs-xfce-devtools1-$name.txt"
done
sudo -n cat "$LFS/root/blfs-xfce-devtools1-testlog.txt" >"$ARTIFACTS/blfs-xfce-devtools1-testlog.txt"
sudo -n rm -f "$LFS/root/build-blfs-xfce-devtools1-chroot.sh" \
  "$LFS/root/blfs-xfce-devtools1-report.txt" \
  "$LFS/root/blfs-xfce-devtools1-progress.txt" \
  "$LFS/root/blfs-xfce-devtools1-testlog.txt"
grep -q '^BLFS_XFCE_DEVTOOLS1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_XFCE_DEVTOOLS1_EXEC_OK$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^LIBWNCK=43.2$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^XFCE4_DEV_TOOLS=4.20.0$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^DEVTOOLS_TEST_SUITE=exit-0$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^NATIVE_SMOKE=xdt-csource-4.20.0$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^XDT_AUTOGEN=present$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^RESULT_MARKER=BLFS_XFCE_DEVTOOLS1_EXEC_OK=4.20.0$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_DEVTOOLS1_BUILT=' "$ARTIFACTS/blfs-xfce-devtools1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-xfce-devtools1-report.txt"
trap - EXIT
