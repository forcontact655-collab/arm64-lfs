#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-display2-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-display2-sources/sources ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/fontconfig.pc" ]]
[[ -f "$LFS/usr/lib/pkgconfig/wayland-client.pc" ]]
[[ -f "$HOST_SOURCES/libX11-1.8.12.tar.xz" ]]
[[ -f "$HOST_SOURCES/libxkbcommon-1.11.0.tar.gz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-display2-chroot.sh" "$LFS/root/build-blfs-display2-chroot.sh"
sudo -n install -m 0644 "$REPO/manifests/blfs-display2.md5" "$LFS/root/blfs-display2.md5"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-display2-chroot.sh

cleanup
sudo -n cat "$LFS/root/blfs-display2-report.txt" >"$ARTIFACTS/blfs-display2-report.txt"
sudo -n cat "$LFS/root/blfs-display2-progress.txt" >"$ARTIFACTS/blfs-display2-progress.txt"
sudo -n rm -f "$LFS/root/build-blfs-display2-chroot.sh" "$LFS/root/blfs-display2.md5" "$LFS/root/blfs-display2-report.txt" "$LFS/root/blfs-display2-progress.txt"
grep -q '^BLFS_DISPLAY2_RESULT=ok$' "$ARTIFACTS/blfs-display2-report.txt"
grep -q '^PACKAGE_COUNT=34$' "$ARTIFACTS/blfs-display2-report.txt"
grep -q '^NATIVE_BINARY_EXEC=BLFS_DISPLAY2_EXEC_OK$' "$ARTIFACTS/blfs-display2-report.txt"
grep -q '^KDE=absent$' "$ARTIFACTS/blfs-display2-report.txt"
[[ "$(grep -c '^BLFS_DISPLAY2_BUILT=' "$ARTIFACTS/blfs-display2-progress.txt")" -eq 34 ]]
cat "$ARTIFACTS/blfs-display2-report.txt"
trap - EXIT
