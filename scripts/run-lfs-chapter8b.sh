#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/lfs-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/lfs-sources/sources ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ -f "$HOST_SOURCES/glibc-2.42.tar.xz" ]]
[[ -f "$HOST_SOURCES/gcc-15.2.0.tar.xz" ]]
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
sudo -n install -m 0755 "$REPO/scripts/build-lfs-chapter8b-chroot.sh" "$LFS/root/build-lfs-chapter8b-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" TESTSUITEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-lfs-chapter8b-chroot.sh

cleanup
sudo -n cat "$LFS/root/ch8b-report.txt" > "$ARTIFACTS/ch8b-report.txt"
sudo -n cat "$LFS/root/ch8b-progress.txt" > "$ARTIFACTS/ch8b-progress.txt"
sudo -n rm -f "$LFS/root/build-lfs-chapter8b-chroot.sh" "$LFS/root/ch8b-report.txt" "$LFS/root/ch8b-progress.txt"
grep -q '^CH8B_RESULT=ok$' "$ARTIFACTS/ch8b-report.txt"
grep -q '^PACKAGE_COUNT=52$' "$ARTIFACTS/ch8b-report.txt"
grep -q '^NATIVE_BINARY_EXEC=LFS_CH8B_EXEC_OK$' "$ARTIFACTS/ch8b-report.txt"
[[ "$(grep -c '^CH8B_BUILT=' "$ARTIFACTS/ch8b-progress.txt")" -eq 52 ]]
cat "$ARTIFACTS/ch8b-report.txt"
trap - EXIT
