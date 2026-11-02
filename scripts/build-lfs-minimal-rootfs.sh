#!/usr/bin/env bash
set -euo pipefail

# Host-side LFS 12.4 Chapter 7 wrapper. Only /home/runner/lfs is modified.
export LFS="${LFS:-/home/runner/lfs}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
ARCHIVE_NAME="lfs-12.4-ch7-aarch64-rootfs.tar.xz"
ARCHIVE="$ARTIFACTS/$ARCHIVE_NAME"
START_TS="$(date +%s)"

[[ "$(id -u)" -ne 0 ]]
[[ "$LFS" == /home/runner/lfs ]]
[[ "$(uname -m)" == aarch64 ]]
[[ -x "$LFS/usr/bin/gcc" ]]
[[ -x "$LFS/usr/bin/bash" ]]
[[ -d "$LFS/tools" ]]
mkdir -p "$ARTIFACTS"
sudo -n true

unmount_lfs() {
  set +e
  if [[ ! -L "$LFS/dev/shm" ]] && mountpoint -q "$LFS/dev/shm"; then
    sudo -n umount "$LFS/dev/shm"
  fi
  local path
  for path in "$LFS/dev/pts" "$LFS/sys" "$LFS/proc" "$LFS/run" "$LFS/dev"; do
    if mountpoint -q "$path"; then
      sudo -n umount "$path"
    fi
  done
  set -e
}
trap unmount_lfs EXIT

printf 'PREPARE chapter7 ownership and virtual filesystems\n'
sudo -n chown -R root:root "$LFS"/{usr,var,etc,tools}
sudo -n mkdir -pv "$LFS"/{dev,proc,sys,run}
sudo -n install -d -m 0750 "$LFS/root"
sudo -n install -m 0755 "$REPO/scripts/build-lfs-chapter7-chroot.sh" \
  "$LFS/root/build-lfs-chapter7-chroot.sh"
sudo -n mount -v --bind /dev "$LFS/dev"
sudo -n mount -vt devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -vt proc proc "$LFS/proc"
sudo -n mount -vt sysfs sysfs "$LFS/sys"
sudo -n mount -vt tmpfs tmpfs "$LFS/run"
if [[ -L "$LFS/dev/shm" ]]; then
  sudo -n install -v -d -m 1777 "$LFS$(realpath /dev/shm)"
else
  sudo -n mount -vt tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
fi

printf 'ENTER isolated chapter7 chroot\n'
sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM="${TERM:-xterm}" PS1='(lfs chroot) \u:\w\$ ' \
  PATH=/usr/bin:/usr/sbin MAKEFLAGS="-j$(nproc)" TESTSUITEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-lfs-chapter7-chroot.sh

unmount_lfs
sudo -n cat "$LFS/root/minimal-rootfs-report.txt" > "$ARTIFACTS/minimal-rootfs-report.txt"
sudo -n cat "$LFS/root/minimal-rootfs-dummy.log" > "$ARTIFACTS/minimal-rootfs-dummy.log"
grep -q '^MINIMAL_ROOTFS_RESULT=ok$' "$ARTIFACTS/minimal-rootfs-report.txt"
grep -q '^CHROOT_EXEC=ok$' "$ARTIFACTS/minimal-rootfs-report.txt"
grep -q '^NATIVE_BINARY_EXEC=LFS_MINIMAL_EXEC_OK$' "$ARTIFACTS/minimal-rootfs-report.txt"
grep -q '^DYNAMIC_LINKER=/lib/ld-linux-aarch64.so.1$' "$ARTIFACTS/minimal-rootfs-report.txt"
sudo -n rm -f "$LFS/root/build-lfs-chapter7-chroot.sh" \
  "$LFS/root/minimal-rootfs-report.txt" "$LFS/root/minimal-rootfs-dummy.log"

printf 'ARCHIVE verified minimal rootfs\n'
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
sudo -n tar --numeric-owner --exclude='./sources' -C "$LFS" \
  -I 'xz -T4 -6' -cf - . > "$ARCHIVE"
tar -tJf "$ARCHIVE" > "$ARTIFACTS/rootfs-contents.txt"
grep -qx './usr/bin/bash' "$ARTIFACTS/rootfs-contents.txt"
grep -qx './usr/bin/gcc' "$ARTIFACTS/rootfs-contents.txt"
grep -qx './usr/bin/python3' "$ARTIFACTS/rootfs-contents.txt"
if grep -Eq '^\./(tools|sources)(/|$)' "$ARTIFACTS/rootfs-contents.txt"; then
  printf 'Archive unexpectedly contains tools or sources\n' >&2
  exit 1
fi
rm -f "$ARTIFACTS/rootfs-contents.txt"
(
  cd "$ARTIFACTS"
  sha256sum "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)
ARCHIVE_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
ARCHIVE_BYTES="$(stat -c %s "$ARCHIVE")"
{
  printf 'ROOTFS_ARCHIVE=%s\n' "$ARCHIVE_NAME"
  printf 'ROOTFS_ARCHIVE_SHA256=%s\n' "$ARCHIVE_SHA256"
  printf 'ROOTFS_ARCHIVE_BYTES=%s\n' "$ARCHIVE_BYTES"
  printf 'TOTAL_ELAPSED_SECONDS=%s\n' "$(( $(date +%s) - START_TS ))"
} >> "$ARTIFACTS/minimal-rootfs-report.txt"
cat "$ARTIFACTS/minimal-rootfs-report.txt"
trap - EXIT
