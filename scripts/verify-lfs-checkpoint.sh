#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$REPO/artifacts/circleci-lfs-checkpoint-report.txt"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs || "$LFS" == /home/runner/lfs ]]
[[ -x "$LFS/usr/bin/bash" ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ ! -e "$LFS/etc/arch-release" ]]
mkdir -p "$REPO/artifacts"
sudo -n true

unmount_lfs() {
  set +e
  local path
  for path in "$LFS/dev/pts" "$LFS/sys" "$LFS/proc" "$LFS/run" "$LFS/dev"; do
    if mountpoint -q "$path"; then sudo -n umount "$path"; fi
  done
  set -e
}
trap unmount_lfs EXIT
sudo -n chown -R root:root "$LFS"
sudo -n mkdir -p "$LFS"/{dev,proc,sys,run}
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login -c '
    set -euo pipefail
    [[ "$(uname -m)" == aarch64 ]]
    [[ ! -e /etc/arch-release ]]
    cat > /tmp/circleci-lfs-smoke.c <<"EOF"
#include <stdio.h>
int main(void) { puts("CIRCLECI_LFS_EXEC_OK"); return 0; }
EOF
    gcc /tmp/circleci-lfs-smoke.c -o /tmp/circleci-lfs-smoke
    OUTPUT="$(/tmp/circleci-lfs-smoke)"
    [[ "$OUTPUT" == CIRCLECI_LFS_EXEC_OK ]]
    readelf -h /tmp/circleci-lfs-smoke | grep -q "Machine:.*AArch64"
    INTERPRETER="$(readelf -l /tmp/circleci-lfs-smoke | sed -n "s/.*Requesting program interpreter: \\(.*\\)]/\\1/p")"
    [[ "$INTERPRETER" == /lib/ld-linux-aarch64.so.1 ]]
    [[ -e "$INTERPRETER" ]]
    {
      printf "CIRCLECI_LFS_CHECKPOINT=ok\n"
      printf "ARCH=%s\n" "$(uname -m)"
      printf "NATIVE_BINARY_EXEC=%s\n" "$OUTPUT"
      printf "DYNAMIC_LINKER=%s\n" "$INTERPRETER"
      printf "BASH=%s\n" "$BASH_VERSION"
      printf "GCC=%s\n" "$(gcc --version | head -n1)"
      printf "KDE=absent\n"
    } > /root/circleci-lfs-checkpoint-report.txt
    rm -f /tmp/circleci-lfs-smoke /tmp/circleci-lfs-smoke.c
  '
sudo -n cat "$LFS/root/circleci-lfs-checkpoint-report.txt" > "$REPORT"
sudo -n rm -f "$LFS/root/circleci-lfs-checkpoint-report.txt"
grep -q '^CIRCLECI_LFS_CHECKPOINT=ok$' "$REPORT"
grep -q '^NATIVE_BINARY_EXEC=CIRCLECI_LFS_EXEC_OK$' "$REPORT"
grep -q '^DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1$' "$REPORT"
cat "$REPORT"
unmount_lfs
trap - EXIT
