#!/usr/bin/env bash
set -euo pipefail

export LFS="${LFS:-/home/circleci/lfs}"
HOST_SOURCES="${HOST_SOURCES:-/home/circleci/blfs-xfce-color-deps1-sources/sources}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS="$REPO/artifacts"
[[ "$(uname -m)" == aarch64 ]]
[[ "$LFS" == /home/circleci/lfs ]]
[[ "$HOST_SOURCES" == /home/circleci/blfs-xfce-color-deps1-sources/sources ]]
[[ -x "$LFS/usr/bin/xfce4-power-manager" ]]
[[ -x "$LFS/usr/bin/meson" ]]
[[ -f "$LFS/usr/share/hwdata/usb.ids" ]]
[[ ! -e "$LFS/usr/lib/libcolord.so" ]]
for archive in lcms2-2.17.tar.gz json-glib-1.10.6.tar.xz libgusb-0.4.9.tar.xz colord-1.4.8.tar.xz; do
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
sudo -n install -m 0755 "$REPO/scripts/build-blfs-xfce-color-deps1-chroot.sh" "$LFS/root/build-blfs-xfce-color-deps1-chroot.sh"
sudo -n mount --bind "$HOST_SOURCES" "$LFS/sources"
sudo -n mount --bind /dev "$LFS/dev"
sudo -n mount -t devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
sudo -n mount -t proc proc "$LFS/proc"
sudo -n mount -t sysfs sysfs "$LFS/sys"
sudo -n mount -t tmpfs tmpfs "$LFS/run"

sudo -n chroot "$LFS" /usr/bin/env -i \
  HOME=/root TERM=xterm TMPDIR=/tmp PATH=/usr/bin:/usr/sbin \
  MAKEFLAGS="-j$(nproc)" \
  /bin/bash --login /root/build-blfs-xfce-color-deps1-chroot.sh

cleanup
for name in report progress lcms2-testlog json-glib-testlog libgusb-testlog colord-testlog; do
  sudo -n cat "$LFS/root/blfs-xfce-color-deps1-$name.txt" >"$ARTIFACTS/blfs-xfce-color-deps1-$name.txt"
done
sudo -n cat "$LFS/root/blfs-xfce-color-deps1-smoke.c" >"$ARTIFACTS/blfs-xfce-color-deps1-smoke.c"
sudo -n rm -f "$LFS/root/build-blfs-xfce-color-deps1-chroot.sh" \
  "$LFS/root/blfs-xfce-color-deps1-report.txt" \
  "$LFS/root/blfs-xfce-color-deps1-progress.txt" \
  "$LFS/root/blfs-xfce-color-deps1-lcms2-testlog.txt" \
  "$LFS/root/blfs-xfce-color-deps1-json-glib-testlog.txt" \
  "$LFS/root/blfs-xfce-color-deps1-libgusb-testlog.txt" \
  "$LFS/root/blfs-xfce-color-deps1-colord-testlog.txt" \
  "$LFS/root/blfs-xfce-color-deps1-smoke.c"
grep -q '^BLFS_XFCE_COLOR_DEPS1_RESULT=ok$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^PACKAGE_COUNT=4$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^NATIVE_BINARY_EXEC=compiled-color-stack-smoke$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^LCMS2=2.17$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^LCMS2_TEST_SUITE=make-check-passed$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^JSON_GLIB=1.10.6$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^JSON_GLIB_UNEXPECTED_FAILURES=0$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^LIBGUSB=0.4.9$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^LIBGUSB_TEST_SUITE=meson-passed$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^COLORD=1.4.8$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^COLORD_TEST_SUITE=meson-passed$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^DBUS_SYSTEM=started-for-tests-stopped$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^INTROSPECTION=Json+GUsb+Colord+Colorhug$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^NATIVE_SMOKE=lcms-2170+json-true+gusb-GUsbContext+colord-CdProfile$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^XFCE=through-power-manager+color-deps$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^KDE=attica-only$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
grep -q '^PLASMA=absent$' "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
[[ "$(grep -c '^BLFS_XFCE_COLOR_DEPS1_BUILT=' "$ARTIFACTS/blfs-xfce-color-deps1-progress.txt")" -eq 4 ]]
cat "$ARTIFACTS/blfs-xfce-color-deps1-report.txt"
trap - EXIT
