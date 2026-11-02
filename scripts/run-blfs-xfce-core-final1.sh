#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-core-final1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-core-final1-sources/sources ]]
[[ -x "$LFS/usr/bin/xfsettingsd" ]]
[[ -x "$LFS/usr/bin/xfce4-color-settings" ]]
[[ -x "$LFS/usr/bin/broadwayd" ]]
[[ -x "$LFS/usr/bin/update-desktop-database" ]]
[[ -x "$LFS/usr/bin/update-mime-database" ]]
[[ ! -x "$LFS/usr/bin/xfdesktop" ]]
[[ ! -x "$LFS/usr/bin/xfwm4" ]]
[[ ! -x "$LFS/usr/bin/xfce4-session" ]]
for archive in xfdesktop-4.20.1.tar.bz2 xfwm4-4.20.0.tar.bz2 xfce4-session-4.20.3.tar.bz2; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-core-final1-chroot.sh" "$LFS/root/build-blfs-xfce-core-final1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-core-final1-chroot.sh

cleanup
for name in report progress versions; do
  sudo -n cat "$LFS/root/blfs-xfce-core-final1-$name.txt" >"$ARTIFACTS/blfs-xfce-core-final1-$name.txt"
done
sudo -n rm -f "$LFS/root/build-blfs-xfce-core-final1-chroot.sh" \
  "$LFS/root/blfs-xfce-core-final1-report.txt" \
  "$LFS/root/blfs-xfce-core-final1-progress.txt" \
  "$LFS/root/blfs-xfce-core-final1-versions.txt"
REPORT="$ARTIFACTS/blfs-xfce-core-final1-report.txt"
grep -q '^BLFS_XFCE_CORE_FINAL1_RESULT=ok$' "$REPORT"
grep -q '^PACKAGE_COUNT=3$' "$REPORT"
grep -q '^NATIVE_BINARY_EXEC=three-settings-version-via-broadway$' "$REPORT"
grep -q '^XFDESKTOP=4.20.1$' "$REPORT"
grep -q '^XFDESKTOP_TEST_SUITE=not-provided$' "$REPORT"
grep -q '^XFDESKTOP_PROGRAMS=2-present$' "$REPORT"
grep -q '^XFWM4=4.20.0$' "$REPORT"
grep -q '^XFWM4_TEST_SUITE=not-provided$' "$REPORT"
grep -q '^XFWM4_PROGRAMS=4-present$' "$REPORT"
grep -q '^XFCE4_SESSION=4.20.3$' "$REPORT"
grep -q '^XFCE4_SESSION_TEST_SUITE=not-provided$' "$REPORT"
grep -q '^XFCE4_SESSION_LEGACY_SM=disabled$' "$REPORT"
grep -q '^SESSION_PROGRAMS=3-elf+2-scripts$' "$REPORT"
grep -q '^CORE_PROGRAMS=9-elf+2-scripts$' "$REPORT"
grep -q '^DESKTOP_DATABASE=updated$' "$REPORT"
grep -q '^MIME_DATABASE=updated$' "$REPORT"
grep -q '^NATIVE_VERSION_SMOKES=3-passed$' "$REPORT"
grep -q '^GUI_SMOKE=headless-broadway-version-only$' "$REPORT"
grep -q '^XFDESKTOP_PROCESS=not-started$' "$REPORT"
grep -q '^XFWM4_PROCESS=not-started$' "$REPORT"
grep -q '^XFCE4_SESSION_PROCESS=not-started$' "$REPORT"
grep -q '^XFSETTINGSD=not-started$' "$REPORT"
grep -q '^DBUS_SESSION=not-started$' "$REPORT"
grep -q '^SESSION_CHANGES=not-tested$' "$REPORT"
grep -q '^XFCE_CORE=18-of-18-built-and-version-smoke-verified$' "$REPORT"
grep -q '^DESKTOP_LAUNCH=not-tested$' "$REPORT"
grep -q '^KDE=attica-only$' "$REPORT"
grep -q '^PLASMA=absent$' "$REPORT"
grep -q '^BOOTABLE=no$' "$REPORT"
[[ "$(grep -c '^BLFS_XFCE_CORE_FINAL1_BUILT=' "$ARTIFACTS/blfs-xfce-core-final1-progress.txt")" -eq 3 ]]
[[ "$(grep -c '^RESULT=ok$' "$ARTIFACTS/blfs-xfce-core-final1-versions.txt")" -eq 3 ]]
for program in xfdesktop-settings xfwm4-workspace-settings xfce4-session-settings; do
  grep -q "^PROGRAM=$program$" "$ARTIFACTS/blfs-xfce-core-final1-versions.txt"
done
cat "$REPORT"
trap - EXIT
