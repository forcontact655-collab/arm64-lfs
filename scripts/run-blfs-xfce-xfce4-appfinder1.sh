#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-xfce4-appfinder1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-xfce4-appfinder1-sources/sources ]]
[[ -e "$LFS/usr/lib/libtumbler-1.so" ]]
[[ -x "$LFS/usr/lib/tumbler-1/tumblerd" ]]
[[ -x "$LFS/usr/bin/broadwayd" ]]
[[ ! -x "$LFS/usr/bin/xfce4-appfinder" ]]
[[ ! -e "$LFS/usr/bin/xfrun4" ]]
for archive in xfce4-appfinder-4.20.0.tar.bz2; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-xfce4-appfinder1-chroot.sh" "$LFS/root/build-blfs-xfce-xfce4-appfinder1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-xfce4-appfinder1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-xfce4-appfinder1-$name.txt" >"$ARTIFACTS/blfs-xfce-xfce4-appfinder1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-xfce4-appfinder1-chroot.sh" \
  "$LFS/root/blfs-xfce-xfce4-appfinder1-report.txt" \
  "$LFS/root/blfs-xfce-xfce4-appfinder1-progress.txt"
grep -q '^BLFS_XFCE_XFCE4_APPFINDER1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^PACKAGE_COUNT=1$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=xfce4-appfinder-version-via-broadway$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^XFCE4_APPFINDER=4.20.0$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^XFCE4_APPFINDER_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^GUI_SMOKE=headless-broadway-version-only$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^APPLICATION_SEARCH=not-tested$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^NATIVE_SMOKE=xfce4-appfinder-4.20.0$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^XFCE=libxfce4util+xfconf+libxfce4ui+exo+garcon+libwnck+devtools+libxfce4windowing+panel+thunar+thunar-volman+tumbler+appfinder$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_XFCE4_APPFINDER1_BUILT=' "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-progress.txt")" -eq 1 ]]
cat "$ARTIFACTS/blfs-xfce-xfce4-appfinder1-report.txt"
trap - EXIT
