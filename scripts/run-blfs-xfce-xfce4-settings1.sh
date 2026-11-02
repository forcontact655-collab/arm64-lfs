#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-xfce4-settings1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-xfce4-settings1-sources/sources ]]
[[ -x "$LFS/usr/bin/xfce4-power-manager" ]]
[[ -x "$LFS/usr/bin/colormgr" ]]
[[ -x "$LFS/usr/libexec/colord" ]]
[[ -f "$LFS/usr/lib/pkgconfig/colord.pc" ]]
[[ -x "$LFS/usr/bin/broadwayd" ]]
[[ ! -x "$LFS/usr/bin/xfsettingsd" ]]
[[ ! -d "$LFS/usr/share/icons/nuoveXT2" ]]
for archive in lxde-icon-theme-0.5.1.tar.xz xfce4-settings-4.20.2.tar.bz2; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-xfce4-settings1-chroot.sh" "$LFS/root/build-blfs-xfce-xfce4-settings1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-xfce4-settings1-chroot.sh

cleanup
for name in report progress; do
  sudo -n cat "$LFS/root/blfs-xfce-xfce4-settings1-$name.txt" >"$ARTIFACTS/blfs-xfce-xfce4-settings1-$name.txt"
done
sudo -n cat "$LFS/root/blfs-xfce-xfce4-settings1-config.h" >"$ARTIFACTS/blfs-xfce-xfce4-settings1-config.h"
sudo -n rm -f "$LFS/root/build-blfs-xfce-xfce4-settings1-chroot.sh" \
  "$LFS/root/blfs-xfce-xfce4-settings1-report.txt" \
  "$LFS/root/blfs-xfce-xfce4-settings1-progress.txt" \
  "$LFS/root/blfs-xfce-xfce4-settings1-config.h"
grep -q '^BLFS_XFCE_XFCE4_SETTINGS1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^PACKAGE_COUNT=2$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=settings-manager+color-settings-version-via-broadway$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^LXDE_ICON_THEME=0.5.1$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^LXDE_ICON_THEME_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^ICON_THEME=nuoveXT2-cache-present$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^XFCE4_SETTINGS=4.20.2$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^XFCE4_SETTINGS_TEST_SUITE=not-provided$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^COLORD=1.4.8-required-at-configure$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^COLORD_CHAIN=HAVE_COLORD+libcolord-linked$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^SETTINGS_PROGRAMS=12-present$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^GUI_SMOKE=headless-broadway-manager+color-version-only$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^SETTINGS_MANAGER=not-started$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^XFSETTINGSD=not-started$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^SETTINGS_CHANGES=not-tested$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^DBUS_SESSION=not-started$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^COLOR_MANAGEMENT=not-tested$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^DISPLAY_SETTINGS=not-tested$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^NATIVE_SMOKE=xfce4-settings+color-settings-4.20.2$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^XFCE=through-color-deps+settings$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_XFCE4_SETTINGS1_BUILT=' "$ARTIFACTS/blfs-xfce-xfce4-settings1-progress.txt")" -eq 2 ]]
cat "$ARTIFACTS/blfs-xfce-xfce4-settings1-report.txt"
trap - EXIT
